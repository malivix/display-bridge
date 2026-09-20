import tempfile,unittest
from pathlib import Path
from scaling_preview import Preview
from preview_runner import Runner


class Hardware:
    def __init__(self,files,context):
        self.files=files;self.observed=context;self.calls=[];self.fail=False;self.missing=False
    def context(self):
        if self.missing:raise RuntimeError('monitor absent')
        return self.observed
    def apply(self,files,context):
        if self.context()!=context:raise RuntimeError('input changed')
        self.calls.append(files)
        if self.fail:raise RuntimeError('injected hardware error')
        self.files=files
    def verify(self,files,context):return self.files==files and self.context()==context


class RunnerTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup)
        self.root=Path(self.temp.name);self.p=Preview(self.root/'preview.json')
        self.old={'config.json':b'old config','baseline.json':b'old baseline'}
        self.new={'config.json':b'new config','baseline.json':b'new baseline'}
        for name,data in self.old.items():(self.root/name).write_bytes(data)
        self.context={'inputs':[17,19],'rotation':0};self.now=100
        self.token=self.p.begin(self.old,self.new,self.context,'one',self.now)['token']
        self.hardware=Hardware(self.old,self.context)
        self.runner=Runner(self.p,self.root,'one',self.hardware,lambda:self.now)
    def test_apply_then_keep_checks_files_and_hardware(self):
        self.assertEqual(self.runner.tick()['state'],'preview')
        self.assertEqual((self.root/'config.json').read_bytes(),self.old['config.json'])
        self.assertEqual(self.runner.tick({'token':self.token,'action':'keep'})['state'],'kept')
        self.assertEqual((self.root/'config.json').read_bytes(),self.new['config.json'])
    def test_timeout_restores_without_menu_request(self):
        self.runner.tick();self.now=121
        self.assertEqual(self.runner.tick()['state'],'reverted')
        self.assertEqual(self.hardware.files,self.old)
    def test_stale_request_cannot_suppress_timeout(self):
        self.runner.tick();self.now=121
        self.assertEqual(self.runner.tick({'token':'stale','action':'keep'})['state'],'reverted')
    def test_switch_away_defers_and_return_cannot_resurrect_keep(self):
        self.runner.tick();self.hardware.observed={'inputs':[18,19],'rotation':0}
        self.assertEqual(self.runner.tick()['state'],'restore-deferred')
        self.assertEqual(len(self.hardware.calls),1)
        self.hardware.observed=self.context
        self.assertEqual(self.runner.tick({'token':self.token,'action':'keep'})['state'],'reverted')
    def test_missing_monitor_does_not_spend_restoration_budget(self):
        self.runner.tick();self.hardware.missing=True
        for _ in range(5):self.assertEqual(self.runner.tick()['state'],'restore-deferred')
        self.assertEqual(self.p.read()['restore_attempts'],0)
        self.hardware.missing=False
        self.assertEqual(self.runner.tick()['state'],'reverted')
    def test_restart_restores_preview(self):
        self.runner.tick();restarted=Runner(Preview(self.p.path),self.root,'two',self.hardware,lambda:101)
        self.assertEqual(restarted.tick()['state'],'reverted')
    def test_failed_restoration_exhausts_without_erasing_evidence(self):
        self.runner.tick();self.hardware.fail=True;self.now=121
        for _ in range(3):self.assertEqual(self.runner.tick()['state'],'restore-pending')
        self.assertEqual(self.runner.tick()['state'],'needs-repair')
        self.assertEqual(len(self.hardware.calls),4)
        self.assertEqual(self.p.read()['restore_attempts'],3)
        self.hardware.fail=False
        self.assertEqual(self.runner.tick({'token':self.token,'action':'repair'})['state'],'reverted')
    def test_external_file_edit_preserved_without_hardware_restore(self):
        self.runner.tick();(self.root/'config.json').write_bytes(b'manual');self.now=121
        self.assertEqual(self.runner.tick()['state'],'restore-pending')
        self.assertEqual(len(self.hardware.calls),1)
        self.assertEqual((self.root/'config.json').read_bytes(),b'manual')
    def test_unfinished_apply_not_repeated(self):
        self.p.applying(self.token,'one',100,self.context)
        self.assertEqual(self.runner.tick()['state'],'restore-pending')
        self.assertEqual(self.runner.tick()['state'],'reverted')
        self.assertEqual(self.hardware.calls,[])
    def test_keep_sent_in_time_survives_slow_final_verification(self):
        self.runner.tick();self.now=119
        verify=self.hardware.verify
        def slow_verify(files,context):
            self.now=122
            return verify(files,context)
        self.hardware.verify=slow_verify
        result=self.runner.tick({'token':self.token,'action':'keep','created_monotonic':119})
        self.assertEqual(result['state'],'kept')
    def test_keep_queued_before_expiry_is_valid_after_queue_delay(self):
        self.runner.tick();self.now=122
        self.assertEqual(self.runner.tick({'token':self.token,'action':'keep','created_monotonic':119})['state'],'kept')
    def test_slow_verification_cannot_cross_hard_deadline(self):
        self.runner.tick();self.now=119
        verify=self.hardware.verify
        def slow_verify(files,context):
            self.now=221
            return verify(files,context)
        self.hardware.verify=slow_verify
        self.assertEqual(self.runner.tick({'token':self.token,'action':'keep','created_monotonic':119})['state'],'restore-pending')
        self.assertEqual((self.root/'config.json').read_bytes(),self.old['config.json'])


if __name__=='__main__':unittest.main()
