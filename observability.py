# SPDX-License-Identifier: MIT
"""Bounded local history and diagnostics; never contacts a server."""
import hashlib,json,os,platform,time,math,statistics,base64,stat,tempfile
from pathlib import Path

STATE_READ_LIMIT=1024*1024

def read_json(path, default=None, max_bytes=STATE_READ_LIMIT):
    try:
        descriptor=os.open(path,os.O_RDONLY|os.O_NONBLOCK|os.O_NOFOLLOW)
        with os.fdopen(descriptor,'rb') as stream:
            info=os.fstat(stream.fileno())
            if not stat.S_ISREG(info.st_mode) or info.st_size>max_bytes:return default
            raw=stream.read(max_bytes+1)
        return json.loads(raw) if len(raw)<=max_bytes else default
    except (OSError,ValueError):return default

def record(root, event):
    path=root/'transitions.json'
    rows=read_json(path)
    if rows is None and not path.exists() and not path.is_symlink():rows=[]
    if not isinstance(rows,list):raise ValueError('Existing transition history is unreadable; original preserved')
    rows=(rows+[dict(event,at=time.time())])[-200:]
    payload=(json.dumps(rows,indent=2,allow_nan=False)+'\n').encode()
    if len(payload)>STATE_READ_LIMIT:raise ValueError('Transition history exceeds the write limit; original preserved')
    temporary=None
    try:
        with tempfile.NamedTemporaryFile(mode='wb',dir=root,prefix='.transitions-',delete=False) as stream:
            temporary=Path(stream.name);stream.write(payload)
        temporary.replace(path)
    finally:
        if temporary is not None:temporary.unlink(missing_ok=True)


def valid_duration(value):
    if type(value) not in (int,float):return False
    try:return math.isfinite(value) and value>=0
    except OverflowError:return False


def recent_events(rows):
    """A small presentation projection; raw errors and machine identifiers stay private."""
    events=[]
    for row in reversed(rows):
        if row.get('profile') not in ('pg','benq','extended','away') or row.get('result') not in ('ready','failed'):continue
        timings=row.get('seconds')
        seconds={}
        if isinstance(timings,dict):
            for phase in ('settling','rotation_check','layout_apply','layout','input_confirmation','audio','total'):
                value=timings.get(phase)
                if valid_duration(value):seconds[phase]=value
        event={'profile':row['profile'],'result':row['result'],'seconds':seconds}
        if row['result']=='failed' and row.get('failed_phase') in ('rotation_check','layout_apply','input_confirmation','audio') and valid_duration(row.get('failed_phase_seconds')):
            event.update(failed_phase=row['failed_phase'],failed_phase_seconds=row['failed_phase_seconds'])
        attempt=row.get('attempt')
        if type(attempt) is int and 1<=attempt<=3:event['attempt']=attempt
        events.append(event)
        if len(events)==10:break
    return events


def summary(root):
    source=read_json(root/'transitions.json',None,STATE_READ_LIMIT)
    rows=source or []
    rows=[r for r in rows if isinstance(r,dict)] if isinstance(rows,list) else []
    result={}
    for profile in ('pg','benq','extended','away'):
        samples=[r for r in rows if r.get('profile')==profile and r.get('result')=='ready']
        failed=sum(r.get('profile')==profile and r.get('result')=='failed' for r in rows)
        if not samples and not failed:continue
        phases={}
        for phase in ('settling','rotation_check','layout_apply','layout','input_confirmation','audio','total'):
            values=sorted(v for r in samples if isinstance(r.get('seconds'),dict) for v in [r['seconds'].get(phase)] if valid_duration(v))
            if values:
                middle=len(values)//2
                # Avoid overflow from adding two individually finite positive floats.
                median=values[middle] if len(values)%2 else values[middle-1]+(values[middle]-values[middle-1])/2
                phases[phase]={'count':len(values),'mean':round(statistics.mean(values),3),'max':round(max(values),3),'median':round(median,3),'p95':round(values[math.ceil(.95*len(values))-1],3)}
        result[profile]={'count':len(samples),'failed_attempts':failed,'seconds':phases}
    return {'recent_events':recent_events(rows),'history_available':isinstance(source,list),'retained_events':len(rows),'profiles':result,'note':'Total is application time only. Settling measures first valid candidate to its second matching read; physical switching and time before the first valid read are unmeasured. Rotation check includes preflight and any rotation; Layout application includes its fresh input preflight; layout includes rotation check plus layout application. Each phase has its own sample count; p95 uses nearest rank. Software readback does not prove sound.'}

def diagnostics(root, bin_dir):
    report={'created_at':time.time(),'os':platform.platform(),'files':{},'file_sha256':{},'unreadable_files':{},'helper_sha256':{},'timings':summary(root)}
    for name in ('size-presets.json','brightness-presets.json','command-results.json','config.json','baseline.json','manifest.json','health.json','recovery.json','control.json','audio-refresh.json','transitions.json','menu-health.json','rotation-active.json','scaling-preview.json','preview-status.json','preview-request.json'):
        report['files'][name]=None
        try:
            with (root/name).open('rb') as stream:
                observed_size=os.fstat(stream.fileno()).st_size
                raw=stream.read(STATE_READ_LIMIT+1)
            if len(raw)>STATE_READ_LIMIT:
                captured=raw[:65536]
                report['unreadable_files'][name]={'error':'State file exceeds the diagnostic read limit',
                    'byte_count_at_open':observed_size,'captured_bytes':len(captured),'truncated':True,
                    'captured_sha256':hashlib.sha256(captured).hexdigest(),'bytes_base64':base64.b64encode(captured).decode('ascii')}
                continue
            report['file_sha256'][name]=hashlib.sha256(raw).hexdigest()
            try:report['files'][name]=json.loads(raw)
            except (ValueError,UnicodeError) as error:
                captured=raw[:65536]
                report['unreadable_files'][name]={'error':str(error),'byte_count':len(raw),'captured_bytes':len(captured),'truncated':len(captured)!=len(raw),'bytes_base64':base64.b64encode(captured).decode('ascii')}
        except FileNotFoundError:pass
        except OSError as error:report['unreadable_files'][name]={'error':str(error)}
    for name in ('display-layout','display-audio','display-ddc','display-rotate','display-mode-info'):
        try:report['helper_sha256'][name]=hashlib.sha256((bin_dir/name).read_bytes()).hexdigest()
        except OSError as error:report['helper_sha256'][name]=str(error)
    log=Path.home()/'Library/Logs/display-auto-v2.log'
    try:
        with log.open('rb') as stream:
            stream.seek(max(0,log.stat().st_size-65536));report['recent_log']=stream.read().decode(errors='replace')
    except OSError:report['recent_log']='unavailable'
    folder=root/'diagnostics';folder.mkdir(mode=0o700,exist_ok=True)
    path=folder/(time.strftime('%Y%m%d-%H%M%S')+'-'+str(time.time_ns())+'.json')
    # This remains a private report: identities and encoded raw bytes are retained.
    # Home replacement is cosmetic, not a publication sanitizer.
    data=json.dumps(report,indent=2).replace(str(Path.home()),'~')+'\n'
    with path.open('x') as stream:os.chmod(path,0o600);stream.write(data)
    return path
