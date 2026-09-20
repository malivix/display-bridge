import json,tempfile,unittest,os
from pathlib import Path
from unittest.mock import patch
from scaling_preview import Preview,decode_snapshot,apply_files,keep_eligible


class PreviewTests(unittest.TestCase):
    def setUp(self):
        self.folder=tempfile.TemporaryDirectory();self.addCleanup(self.folder.cleanup)
        self.path=Path(self.folder.name)/'preview.json';self.p=Preview(self.path)
        self.old={'config.json':b'{"old":true}','baseline.json':b'{"mode":1}','rotation-active.json':None}
        self.new={'config.json':b'{"new":true}','baseline.json':b'{"mode":2}','rotation-active.json':b'{}'}
        self.context={'inputs':[17,19],'rotation':0,'keys':['pg','benq']}
        self.r=self.p.begin(self.old,self.new,self.context,'session',100);self.token=self.r['token']
    def viewing(self):
        self.p.applying(self.token,'session',101,self.context)
        return self.p.verified(self.token,'session',105,self.context)
    def test_longer_preview_is_persisted_bounded_and_restored_after_restart(self):
        self.path.unlink()
        record=self.p.begin(self.old,self.new,self.context,'session',100,preview_seconds=40)
        token=record['token'];self.p.applying(token,'session',101,self.context)
        shown=self.p.verified(token,'session',105,self.context)
        self.assertEqual(shown['keep_until'],145)
        reopened=Preview(self.path)
        self.assertEqual(reopened.decision('session',140,self.context),'preview')
        self.assertTrue(keep_eligible(reopened.read(),'session',140,self.context,140))
        self.assertEqual(reopened.decision('session',145,self.context),'restore')
        self.assertEqual(reopened.decision('new-session',110,self.context),'restore')
        with self.assertRaises(RuntimeError):reopened.keep(token,'session',145,self.context)
        self.assertEqual(decode_snapshot(reopened.read()['original']),self.old)

    def test_duration_cannot_extend_hard_lifetime_and_old_journals_still_work(self):
        legacy=self.p.read();legacy.pop('preview_seconds');self.p.write(legacy)
        self.assertEqual(self.viewing()['keep_until'],125)
        self.path.unlink()
        record=self.p.begin(self.old,self.new,self.context,'session',100,preview_seconds=40)
        self.p.applying(record['token'],'session',101,self.context)
        self.assertEqual(self.p.verified(record['token'],'session',210,self.context)['keep_until'],220)
        self.assertEqual(self.p.decision('session',220,self.context),'restore')

    def test_invalid_duration_preserves_existing_journal(self):
        original=self.path.read_bytes()
        for duration in (True,0,21,60,40.0,'40',None):
            with self.assertRaises(ValueError):
                self.p.begin(self.old,self.new,self.context,'session',100,preview_seconds=duration)
            self.assertEqual(self.path.read_bytes(),original)

    def test_keep_requires_verified_apply_and_complete_files(self):
        with self.assertRaises(RuntimeError):self.p.keep(self.token,'session',101,self.context)
        self.viewing();self.p.keep(self.token,'session',110,self.context)
        with self.assertRaises(RuntimeError):self.p.committed(self.token,self.old,'session',111,self.context)
        self.assertEqual(self.p.read()['phase'],'committing')
        self.p.committed(self.token,self.new,'session',111,self.context)
        self.assertEqual(self.p.decision('another',200,self.context),'idle')
    def test_timeout_begins_after_readback_with_hard_limit(self):
        r=self.viewing();self.assertEqual(r['keep_until'],125)
        self.assertEqual(self.p.decision('session',124,self.context),'preview')
        self.assertEqual(self.p.decision('session',125,self.context),'restore')
        with self.assertRaises(RuntimeError):self.p.keep(self.token,'session',125,self.context)
    def test_restart_or_context_change_always_prefers_restore(self):
        self.viewing()
        for session,now,context in [('new',106,self.context),('session',99,self.context),('session',106,{'inputs':[18,19]}),('session',221,self.context)]:
            self.assertEqual(Preview(self.path).decision(session,now,context),'restore')
    def test_restart_during_commit_cannot_mark_kept(self):
        self.viewing();self.p.keep(self.token,'session',110,self.context)
        with self.assertRaises(RuntimeError):Preview(self.path).committed(self.token,self.new,'new',111,self.context)
    def test_restoration_is_bounded_and_persistent(self):
        self.viewing()
        for _ in range(3):
            self.p.restoring(self.token);self.p.restoration_failed(self.token);self.p=Preview(self.path)
        self.assertEqual(self.p.decision('new',110,self.context),'needs-repair')
        with self.assertRaises(RuntimeError):self.p.restoring(self.token)
        self.assertEqual(decode_snapshot(self.p.read()['original']),self.old)
    def test_restore_requires_original_bytes_and_preserves_deleted_file(self):
        self.viewing();self.p.restoring(self.token)
        with self.assertRaises(RuntimeError):self.p.restored(self.token,self.new)
        self.p.restored(self.token,self.old)
        self.assertEqual(self.p.read()['phase'],'reverted')
        self.assertIsNone(decode_snapshot(self.p.read()['original'])['rotation-active.json'])
    def test_stale_token_and_overlap_rejected(self):
        with self.assertRaises(RuntimeError):self.p.applying('old','session',101,self.context)
        with self.assertRaises(RuntimeError):self.p.begin(self.old,self.new,self.context,'other',101)
    def test_corrupt_journal_is_not_replaced(self):
        r=self.p.read();r['original']['config.json']['sha256']='bad';raw=json.dumps(r);self.path.write_text(raw)
        with self.assertRaises(ValueError):self.p.read()
        with self.assertRaises(ValueError):self.p.begin(self.old,self.new,self.context,'other',101)
        self.assertEqual(self.path.read_text(),raw)
    def test_journal_private_and_snapshots_immutable(self):
        self.assertEqual(self.path.stat().st_mode&0o777,0o600)
        self.old['config.json']=b'changed';self.context['rotation']=90
        self.assertEqual(self.p.read()['context']['rotation'],0)
        self.assertEqual(decode_snapshot(self.p.read()['original'])['config.json'],b'{"old":true}')
    def test_partial_commit_can_restore_original_files(self):
        root=Path(self.folder.name)
        for name,data in self.old.items():
            if data is not None:(root/name).write_bytes(data)
        self.viewing();record=self.p.keep(self.token,'session',110,self.context)
        replace=os.replace
        def fail_second(source,destination):
            if Path(destination).name=='baseline.json':raise OSError('injected disk failure')
            return replace(source,destination)
        with patch('scaling_preview.os.replace',side_effect=fail_second):
            with self.assertRaises(OSError):apply_files(record,root)
        self.assertEqual((root/'config.json').read_bytes(),self.new['config.json'])
        self.assertEqual((root/'baseline.json').read_bytes(),self.old['baseline.json'])
        record=self.p.restoring(self.token)
        restored=apply_files(record,root,restore=True);self.p.restored(self.token,restored)
        self.assertEqual(restored,self.old)
    def test_external_edit_blocks_all_file_writes(self):
        root=Path(self.folder.name)
        for name,data in self.old.items():
            if data is not None:(root/name).write_bytes(data)
        (root/'baseline.json').write_bytes(b'manual change')
        self.viewing();record=self.p.keep(self.token,'session',110,self.context)
        with self.assertRaisesRegex(RuntimeError,'modified outside'):apply_files(record,root)
        self.assertEqual((root/'config.json').read_bytes(),self.old['config.json'])
        self.assertEqual((root/'baseline.json').read_bytes(),b'manual change')
    def test_journal_replace_failure_keeps_previous_state(self):
        before=self.path.read_bytes()
        with patch('scaling_preview.os.replace',side_effect=OSError('injected journal failure')):
            with self.assertRaises(OSError):self.p.applying(self.token,'session',101,self.context)
        self.assertEqual(self.path.read_bytes(),before)
    def test_confirmation_timestamp_cannot_bypass_safety_boundaries(self):
        record=self.viewing()  # Verified at 105; Keep deadline 125; hard deadline 220.
        self.assertTrue(keep_eligible(record,'session',126,self.context,124))
        for requested in (104,125,130,float('nan'),-1):
            self.assertFalse(keep_eligible(record,'session',126,self.context,requested))
        self.assertFalse(keep_eligible(record,'new-session',126,self.context,124))
        self.assertFalse(keep_eligible(record,'session',220,self.context,124))
        self.assertFalse(keep_eligible(record,'session',126,{'inputs':[18,19]},124))
        record['phase']='restore-failed'
        self.assertFalse(keep_eligible(record,'session',126,self.context,124))


if __name__=='__main__':unittest.main()
