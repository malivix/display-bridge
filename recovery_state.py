# SPDX-License-Identifier: MIT
"""Durable unfinished work, independent of the current display readback."""
import json
from pathlib import Path
from persisted_state import read_state,validate_recovery

class Recovery:
    def __init__(self, path=None):
        self.path=Path(path) if path else None
        self.data={'state':None,'profile':None,'pending':False,'reason':None,
                   'attempts':0,'retry_at':0,'error':None}
        if self.path:
            saved=read_state(self.path,validate_recovery)
            if saved is not None:self.data.update(saved)
        # Monotonic deadlines cannot be reused across processes/boots.
        self.data['retry_at']=0
    def save(self):
        if self.path:
            self.path.parent.mkdir(parents=True,exist_ok=True)
            temporary=self.path.with_suffix('.tmp')
            temporary.write_text(json.dumps(self.data)+'\n');temporary.replace(self.path)
    def select(self, inputs, profile, orientation=None):
        state=[inputs['pg'],inputs['benq']]
        changed=False
        if state != self.data['state']:
            self.data.update(state=state,profile=profile,orientation=None)
            self.request('input transition')
            if profile=='unknown':self.complete()
            changed=True
        if profile in ('extended','benq') and orientation in (0,90):
            previous=self.data.get('orientation')
            self.data['orientation']=orientation
            if not changed and previous in (0,90) and previous!=orientation:
                self.request('orientation changed')
                changed=True
            elif previous!=orientation:self.save()
        return changed
    def request(self, reason):
        self.data.update(pending=True,reason=reason,attempts=0,retry_at=0,error=None)
        self.save()
    def failed(self, error, now):
        attempts=self.data['attempts']+1
        self.data.update(pending=True,attempts=attempts,retry_at=now+min(30,2**attempts),error=str(error))
        self.save()
    def complete(self):
        self.data.update(pending=False,attempts=0,retry_at=0,error=None,reason=None)
        self.save()
    def eligible(self, now):
        return self.data['attempts']<3 and now>=self.data['retry_at']
    @property
    def pending(self):return self.data['pending']
    @property
    def exhausted(self):return self.data['attempts']>=3
