# SPDX-License-Identifier: MIT
"""Persistent preview state machine. No display or configuration-file writes.

The controller must serialize callers and verify hardware before marking an
apply/restore complete. This module owns the journal and transition rules only.
"""
import base64
import copy
import hashlib
import json
import os
from pathlib import Path
import tempfile
import uuid
from persisted_state import number as finite

FILES={'config.json','baseline.json','rotation-active.json'}
TERMINAL={'kept','reverted'}
PHASES={'prepared','applying','preview','committing','restoring','restore-failed'}|TERMINAL


def keep_eligible(record,session,now,context,requested_at):
    until=record.get('keep_until')
    if not finite(until) or not finite(now) or not finite(requested_at):return False
    ready=record.get('verified_at',max(record['started'],until-20))
    return (record['phase']=='preview' and record['session']==session and record['context']==context
            and record['started']<=now<record['hard_deadline']
            and ready<=requested_at<=now and requested_at<until)


def snapshot(files):
    if not {'config.json','baseline.json'}.issubset(files) or not set(files).issubset(FILES):
        raise ValueError('Unexpected preview snapshot files')
    result={}
    for name,data in files.items():
        if data is None:result[name]=None;continue
        if not isinstance(data,bytes) or len(data)>1024*1024:raise ValueError('Invalid snapshot bytes')
        result[name]={'bytes':base64.b64encode(data).decode('ascii'),'sha256':hashlib.sha256(data).hexdigest()}
    return result


def decode_snapshot(value):
    if not isinstance(value,dict):raise ValueError('Invalid preview snapshot')
    files={}
    for name,item in value.items():
        if item is None:files[name]=None;continue
        raw=base64.b64decode(item['bytes'],validate=True)
        if hashlib.sha256(raw).hexdigest()!=item['sha256']:raise ValueError('Snapshot checksum mismatch')
        files[name]=raw
    if snapshot(files)!=value:raise ValueError('Invalid preview snapshot encoding')
    return files


def validate(record):
    if not isinstance(record,dict) or record.get('schema')!=1 or record.get('phase') not in PHASES:
        raise ValueError('Invalid preview journal')
    for key in ('token','session'):
        if not isinstance(record.get(key),str) or not record[key]:raise ValueError('Missing preview identity')
    for key in ('started','hard_deadline'):
        if not finite(record.get(key)):raise ValueError('Invalid preview deadline')
    if not record['started']<record['hard_deadline']<=record['started']+120:raise ValueError('Invalid preview lifetime')
    if record.get('keep_until') is not None and (not finite(record['keep_until']) or not record['started']<=record['keep_until']<=record['hard_deadline']):
        raise ValueError('Invalid confirmation deadline')
    if 'verified_at' in record and (not finite(record['verified_at']) or not record['started']<=record['verified_at']<=record['hard_deadline']):
        raise ValueError('Invalid preview verification time')
    if type(record.get('restore_attempts')) is not int or not 0<=record['restore_attempts']<=3:raise ValueError('Invalid restoration budget')
    if not isinstance(record.get('context'),dict):raise ValueError('Missing preview context')
    if set(record['original'])!=set(record['proposed']):raise ValueError('Snapshot file sets differ')
    for group in ('original','proposed'):
        if any(record[group].get(name) is None for name in ('config.json','baseline.json')):raise ValueError('Missing configuration snapshot')
    decode_snapshot(record['original']);decode_snapshot(record['proposed'])
    return record


def apply_files(record,root,restore=False):
    """Recoverable multi-file write; caller holds controller/configuration locks.

    A partial write leaves the journal pending. Only original/proposed bytes may
    be replaced, so an unrelated manual edit is reported instead of overwritten.
    Hardware restoration must be separately verified before marking completion.
    """
    validate(record)
    if record['phase']!=('restoring' if restore else 'committing'):raise RuntimeError('File write outside preview transaction')
    root=Path(root)
    original=decode_snapshot(record['original']);proposed=decode_snapshot(record['proposed'])
    target=original if restore else proposed
    current={}
    for name in target:
        path=root/name
        if path.is_symlink():raise RuntimeError('Preview configuration must not be a symlink')
        try:current[name]=path.read_bytes()
        except FileNotFoundError:current[name]=None
        if current[name] not in (original[name],proposed[name]):raise RuntimeError(f'{name} was modified outside this preview; preserved for repair')
    for name,data in target.items():
        if current[name]==data:continue
        path=root/name
        if data is None:path.unlink()
        else:
            fd,temporary=tempfile.mkstemp(prefix='.preview-setting-',dir=root)
            try:
                with os.fdopen(fd,'wb') as stream:
                    stream.write(data);stream.flush();os.fsync(stream.fileno())
                os.replace(temporary,path)
            finally:
                if os.path.exists(temporary):os.unlink(temporary)
        directory=os.open(root,os.O_RDONLY)
        try:os.fsync(directory)
        finally:os.close(directory)
    return {name:(root/name).read_bytes() if (root/name).exists() else None for name in target}


class Preview:
    def __init__(self,path):self.path=Path(path)

    def read(self):
        try:raw=self.path.read_text()
        except FileNotFoundError:return None
        # Invalid evidence is deliberately left intact and never reset to defaults.
        return validate(json.loads(raw))

    def write(self,record):
        validate(record)
        self.path.parent.mkdir(parents=True,exist_ok=True)
        fd,name=tempfile.mkstemp(prefix='.preview-',dir=self.path.parent)
        try:
            with os.fdopen(fd,'w') as stream:
                json.dump(record,stream,allow_nan=False);stream.flush();os.fsync(stream.fileno())
            os.replace(name,self.path)
            directory=os.open(self.path.parent,os.O_RDONLY)
            try:os.fsync(directory)
            finally:os.close(directory)
        finally:
            if os.path.exists(name):os.unlink(name)
        return copy.deepcopy(record)

    def begin(self,original,proposed,context,session,now):
        previous=self.read()
        if previous and previous['phase'] not in TERMINAL:raise RuntimeError('A preview still needs completion or restoration')
        if not finite(now):raise ValueError('Invalid clock')
        if original.get('config.json') is None or original.get('baseline.json') is None:raise ValueError('Original configuration is required')
        if proposed.get('config.json') is None or proposed.get('baseline.json') is None:raise ValueError('Proposed configuration is required')
        return self.write({'schema':1,'token':uuid.uuid4().hex,'session':session,'phase':'prepared',
                           'started':now,'hard_deadline':now+120,'keep_until':None,'restore_attempts':0,
                           'context':copy.deepcopy(context),'original':snapshot(original),'proposed':snapshot(proposed)})

    def require(self,token,phases):
        record=self.read()
        if not record or record['token']!=token:raise RuntimeError('Stale preview token')
        if record['phase'] not in phases:raise RuntimeError('Invalid preview transition')
        return record

    def decision(self,session,now,context):
        record=self.read()
        if not record or record['phase'] in TERMINAL:return 'idle'
        if record['restore_attempts']>=3:return 'needs-repair'
        if record['phase'] in ('restoring','restore-failed'):return 'restore'
        if record['session']!=session or not finite(now) or now<record['started'] or now>=record['hard_deadline'] or context!=record['context']:return 'restore'
        if record['phase']=='preview' and (record['keep_until'] is None or now>=record['keep_until']):return 'restore'
        return record['phase']

    def applying(self,token,session,now,context):
        record=self.require(token,{'prepared'})
        if self.decision(session,now,context)!='prepared':raise RuntimeError('Preview context expired or changed')
        record['phase']='applying';return self.write(record)

    def verified(self,token,session,now,context):
        record=self.require(token,{'applying'})
        if self.decision(session,now,context)!='applying':raise RuntimeError('Preview context expired or changed')
        record.update(phase='preview',verified_at=now,keep_until=min(now+20,record['hard_deadline']))
        return self.write(record)

    def keep(self,token,session,now,context,requested_at=None):
        record=self.require(token,{'preview'})
        requested_at=now if requested_at is None else requested_at
        if not keep_eligible(record,session,now,context,requested_at):raise RuntimeError('Preview is no longer eligible to keep')
        record.update(phase='committing',keep_requested_at=requested_at);return self.write(record)

    def committed(self,token,observed_files,session,now,context):
        record=self.require(token,{'committing'})
        if self.decision(session,now,context)!='committing':raise RuntimeError('Commit context changed; restoration required')
        if snapshot(observed_files)!=record['proposed']:raise RuntimeError('Configuration commit is incomplete')
        record['phase']='kept';return self.write(record)

    def restoring(self,token):
        record=self.require(token,PHASES-TERMINAL)
        if record['restore_attempts']>=3:raise RuntimeError('Restoration budget exhausted; preserve journal for repair')
        record['restore_attempts']+=1;record['phase']='restoring';return self.write(record)

    def request_restore(self,token):
        record=self.require(token,PHASES-TERMINAL)
        # Persist cancellation without spending a hardware retry while the setup
        # is unsafe/unavailable. Returning inputs must not resurrect Keep.
        record['phase']='restore-failed';return self.write(record)

    def retry_restore(self,token):
        record=self.require(token,{'restore-failed','restoring'})
        if record['restore_attempts']<3:raise RuntimeError('Restoration is not exhausted')
        record['restore_attempts']=0;record['phase']='restore-failed';return self.write(record)

    def restoration_failed(self,token):
        record=self.require(token,{'restoring'});record['phase']='restore-failed';return self.write(record)

    def restored(self,token,observed_files):
        record=self.require(token,{'restoring'})
        if snapshot(observed_files)!=record['original']:raise RuntimeError('Original configuration not restored')
        record['phase']='reverted';return self.write(record)
