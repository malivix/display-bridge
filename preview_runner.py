# SPDX-License-Identifier: MIT
"""Controller-owned preview orchestration through a hardware adapter.

Caller must hold the normal controller lock and suspend ordinary reconciliation.
Adapter context() verifies exact topology, local inputs and orientation; apply()
rechecks those immediately before each display write; verify() checks exact
layout, fixed refresh and HDR policy through ControllerHardware.
"""
from scaling_preview import TERMINAL,apply_files,decode_snapshot,keep_eligible


class Runner:
    def __init__(self,journal,root,session,hardware,clock):
        self.journal=journal;self.root=root;self.session=session;self.hardware=hardware;self.clock=clock

    def result(self,state,error=None):
        record=self.journal.read()
        return {'state':state,'token':record['token'] if record else None,
                'keep_until':record.get('keep_until') if record and state=='preview' else None,
                'remaining_seconds':max(0,record['keep_until']-self.clock()) if record and state=='preview' and record.get('keep_until') is not None else 0,
                'error':error,'restore_attempts':record['restore_attempts'] if record else 0}

    def tick(self,request=None):
        record=self.journal.read()
        if not record or record['phase'] in TERMINAL:return self.result('idle')
        token=record['token']
        requested_at=request.get('created_monotonic',self.clock()) if request else None
        rejected=bool(request and (request.get('token')!=token or request.get('action') not in ('keep','revert','repair')))
        if request and not rejected and request['action']=='repair':
            try:record=self.journal.retry_restore(token)
            except RuntimeError as error:return self.result('request-rejected',str(error))
        try:context=self.hardware.context()
        except Exception as error:
            self.journal.request_restore(token)
            return self.result('restore-deferred',str(error))
        decision=self.journal.decision(self.session,self.clock(),context)
        if request and not rejected and request['action']=='keep' and keep_eligible(record,self.session,self.clock(),context,requested_at):
            decision='preview'
        if request and not rejected and request['action']=='revert':decision='restore'
        if decision=='needs-repair':return self.result('needs-repair','Restoration retries exhausted; journal preserved')
        if decision=='restore':return self.restore(record,context)
        if rejected:return self.result('request-rejected','Invalid or stale preview request')
        try:
            if decision=='prepared':
                self.journal.applying(token,self.session,self.clock(),context)
                proposed=decode_snapshot(record['proposed'])
                self.hardware.apply(proposed,record['context'])
                if not self.hardware.verify(proposed,record['context']):raise RuntimeError('Preview mode verification failed')
                self.journal.verified(token,self.session,self.clock(),self.hardware.context())
                return self.result('preview')
            if decision=='applying':
                # An apply intent seen on another tick is unfinished, never
                # permission to blindly issue the display command again.
                self.journal.request_restore(token)
                return self.result('restore-pending','Previous apply did not complete')
            if decision=='preview':
                proposed=decode_snapshot(record['proposed'])
                if not self.hardware.verify(proposed,record['context']):raise RuntimeError('Preview mode drifted')
                if not request:return self.result('preview')
                record=self.journal.keep(token,self.session,self.clock(),self.hardware.context(),requested_at)
                observed=apply_files(record,self.root)
                self.journal.committed(token,observed,self.session,self.clock(),self.hardware.context())
                return self.result('kept')
            # An interrupted file commit must be restored on the next tick.
            self.journal.request_restore(token)
            return self.result('restore-pending','Unfinished configuration commit')
        except Exception as error:
            self.journal.request_restore(token)
            return self.result('restore-pending',str(error))

    def restore(self,record,context):
        token=record['token']
        self.journal.request_restore(token)
        if context!=record['context']:
            return self.result('restore-deferred','Waiting for the original local inputs and orientation')
        if record['restore_attempts']>=3:return self.result('needs-repair','Restoration retries exhausted; journal preserved')
        record=self.journal.restoring(token)
        try:
            observed=apply_files(record,self.root,restore=True)
            original=decode_snapshot(record['original'])
            if not self.hardware.verify(original,record['context']):self.hardware.apply(original,record['context'])
            if self.hardware.context()!=record['context'] or not self.hardware.verify(original,record['context']):
                raise RuntimeError('Original display state not verified')
            self.journal.restored(token,observed)
            return self.result('reverted')
        except Exception as error:
            self.journal.restoration_failed(token)
            return self.result('restore-pending',str(error))
