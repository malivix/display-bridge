# SPDX-License-Identifier: MIT
"""Daemon request handling for scaling previews. Menu is never the watchdog."""
import fcntl,json,os,time,uuid,hashlib
from contextlib import contextmanager
from scaling_preview import Preview,TERMINAL,decode_snapshot,finite
from preview_runner import Runner
from preview_hardware import ControllerHardware
from scaling_choices import candidates,paired_sizes
from scaling_proposal import build

LABELS={'larger':'Larger interface','current':'Current size','more-space':'More space'}


def unresolved(root):
    path=root/'scaling-preview.json'
    if not path.exists():return False
    record=Preview(path).read()  # Corrupt journals are errors, never treated as idle.
    return record['phase'] not in TERMINAL or record.get('recovery_queued') is not True


@contextmanager
def mutation_guard(controller):
    controller.ROOT.mkdir(parents=True,exist_ok=True)
    with (controller.ROOT/'preview-access.lock').open('a') as lock:
        controller.acquire_lock(lock,2)
        if unresolved(controller.ROOT):raise RuntimeError('Finish or revert the scaling preview before changing settings')
        yield


def enqueue(controller,action,size=None,token=None,fingerprint=None):
    if action not in ('start','keep','revert','repair'):raise ValueError('Invalid preview action')
    if action=='start' and size not in LABELS:raise ValueError('Unknown scaling option')
    if action!='start' and (not isinstance(token,str) or not token):raise ValueError('Preview token required')
    root=controller.ROOT
    with (root/'install.lock').open('a') as install,(root/'preview-request.lock').open('a') as lock:
        try:fcntl.flock(install,fcntl.LOCK_SH|fcntl.LOCK_NB)
        except BlockingIOError:raise RuntimeError('Installation in progress')
        controller.acquire_lock(lock,2)
        path=root/'preview-request.json'
        if path.exists():raise RuntimeError('A preview request is already waiting for the controller')
        request={'id':uuid.uuid4().hex,'action':action,'size':size,'token':token,'fingerprint':fingerprint,'created_at':time.time(),'created_monotonic':time.monotonic()}
        with path.open('x') as stream:
            os.chmod(path,0o600);json.dump(request,stream);stream.flush();os.fsync(stream.fileno())
    return request


def options(c):
    config=c.startup_config();hardware=ControllerHardware(c,config)
    context=hardware.context()
    public=json.loads(c.command([c.HELPER,'modes']));metadata=json.loads(c.command([c.MODE_INFO,'modes']))
    report=candidates(public,metadata,config['keys']);result=[]
    for pair in paired_sizes(report):
        files=build(config,report,pair)
        result.append({'size':next(k for k,v in LABELS.items() if v==pair['label']),
                       'label':pair['label'],'modes':pair['modes'],'fingerprint':hashlib.sha256(files['config.json']).hexdigest()})
    if hardware.context()!=context:raise RuntimeError('Inputs or orientation changed during inspection')
    return {'read_only':True,'rotation':context['rotation'],'options':result}


class Service:
    def __init__(self,controller,hardware_factory=ControllerHardware):
        self.c=controller;self.root=controller.ROOT;self.journal=Preview(self.root/'scaling-preview.json')
        self.session=uuid.uuid4().hex;self.factory=hardware_factory;self.runner=None;self.config=None
        self.journal_failed=False

    def pending(self):
        try:return self.journal_failed or unresolved(self.root) or (self.root/'preview-request.json').exists()
        except Exception:return True

    def take(self):
        path=self.root/'preview-request.json'
        with (self.root/'preview-request.lock').open('a') as lock:
            self.c.acquire_lock(lock,2)
            if not path.exists():return None
            try:
                request=json.loads(path.read_text())
                if not isinstance(request,dict) or not finite(request.get('created_at')) or not 0<=time.time()-request['created_at']<=30:
                    raise ValueError('Expired or invalid request')
                if request.get('action') not in ('start','keep','revert','repair'):raise ValueError('Unknown request')
                path.unlink();return request
            except (ValueError,TypeError):
                path.rename(path.with_name('preview-request.rejected-'+str(time.time_ns())+'.json'))
                return {'action':'invalid','token':None}

    def start(self,request):
        c=self.c
        with (self.root/'install.lock').open('a') as install:
            try:fcntl.flock(install,fcntl.LOCK_SH|fcntl.LOCK_NB)
            except BlockingIOError:raise RuntimeError('Installation in progress; preview not started')
            config=c.startup_config()
            if c.automation_paused(c.read_control()):raise RuntimeError('Resume automation before preview')
            if c.new_recovery().data['pending'] or c.JOURNAL.exists():raise RuntimeError('Finish audio/layout recovery before preview')
            c.write_health(config,'preview-preparing',preview={'state':'preparing','token':None,'remaining_seconds':0})
            original={name:(self.root/name).read_bytes() if (self.root/name).exists() else None for name in ('config.json','baseline.json','rotation-active.json')}
            hardware=self.factory(c,config);context=hardware.context()
            if not hardware.verify(original,context):raise RuntimeError('Current saved layout must verify before preview')
            public=json.loads(c.command([c.HELPER,'modes']))
            metadata=json.loads(c.command([c.MODE_INFO,'modes']))
            report=candidates(public,metadata,config['keys'])
            label=LABELS.get(request.get('size'))
            options=[p for p in paired_sizes(report) if p['label']==label]
            if len(options)!=1:raise RuntimeError('Requested size is not available with fixed 120-Hz HiDPI')
            proposed=build(config,report,options[0])
            if request.get('fingerprint') and request['fingerprint']!=hashlib.sha256(proposed['config.json']).hexdigest():
                raise RuntimeError('Size choices changed; reopen the chooser before previewing')
            if hardware.context()!=context:raise RuntimeError('Inputs or orientation changed during preview preparation')
            for name,data in original.items():
                path=self.root/name
                if (path.read_bytes() if path.exists() else None)!=data:raise RuntimeError('Settings changed during preview preparation')
            self.journal.begin(original,proposed,context,self.session,time.monotonic())
            self.config=config;self.runner=Runner(self.journal,self.root,self.session,hardware,time.monotonic)

    def publish(self,result):
        path=self.root/'preview-status.json';temporary=path.with_suffix('.tmp')
        value=dict(result,updated_at=time.time())
        with temporary.open('w') as stream:os.chmod(temporary,0o600);json.dump(value,stream)
        temporary.replace(path)

    def step(self):
        request=self.take()
        try:
            if self.journal_failed and not self.journal.path.exists():raise RuntimeError('Missing damaged preview journal; restore the original recovery record')
            record=self.journal.read();self.journal_failed=False
        except Exception as error:
            self.journal_failed=True
            self.c.write_health({'host':'?'},'state-error',error=str(error));return 'error'
        if record and record['phase'] in TERMINAL and record.get('recovery_queued') is not True:
            self.finish(record)
        if not record or record['phase'] in TERMINAL:
            if not request:return 'idle'
            if request.get('action')!='start':return 'request-rejected'
            try:self.start(request)
            except Exception as error:
                self.publish({'state':'request-rejected','error':str(error)})
                self.c.write_health({'host':'?'},'preview-error',error=str(error));return 'request-rejected'
            request=None;record=self.journal.read()
        if self.runner is None:
            self.config=json.loads(decode_snapshot(record['original'])['config.json'])
            hardware=self.factory(self.c,self.config)
            self.runner=Runner(self.journal,self.root,self.session,hardware,time.monotonic)
        # A second start must never replace a pending preview.
        if request and request.get('action')=='start':request={'token':None,'action':'invalid'}
        result=self.runner.tick(request)
        self.publish(result)
        self.c.write_health(self.config,'preview-'+result['state'],preview=result,error=result.get('error'))
        if result['state'] in ('kept','reverted'):
            self.finish(self.journal.read())
            self.runner=None
        return result['state']

    def finish(self,record):
        self.c.new_recovery().request('scaling preview completed; verify layout and audio')
        record['recovery_queued']=True
        self.journal.write(record)

    def drain(self):
        if not self.pending():return
        with (self.root/'preview-access.lock').open('a') as lock:
            self.c.acquire_lock(lock,3)
            while self.pending():
                try:self.step()
                except Exception as error:self.c.write_health({'host':'?'},'state-error',error=str(error))
                if self.pending():time.sleep(1)
