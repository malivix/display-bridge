import importlib.util,json,tempfile,unittest,base64,hashlib
from pathlib import Path
from unittest.mock import patch
spec=importlib.util.spec_from_file_location('state_controller',(Path(__file__).resolve().parents[2]/'display-auto.py'))
c=importlib.util.module_from_spec(spec);spec.loader.exec_module(c)
import observability

class SavedStateSafety(unittest.TestCase):
    def test_startup_wait_preserves_invalid_file_and_recovers_after_repair(self):
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp);config=root/'config.json';baseline=root/'baseline.json'
            valid={'version':c.VERSION,'host':'A','poll_interval':.25,'keys':{'pg':'p','benq':'b'},'baseline':{'screens':[{'key':'p'},{'key':'b'}]}}
            baseline.write_text(json.dumps(valid['baseline']));config.write_text('{broken')
            def repair(seconds):
                self.assertEqual(config.read_text(),'{broken')
                config.write_text(json.dumps(valid))
            with patch.object(c,'CONFIG',config),patch.object(c,'BASELINE',baseline),patch.object(c,'write_health') as health,patch.object(c,'command') as hardware,patch.object(c.time,'sleep',side_effect=repair):
                self.assertEqual(c.startup_config(wait=True),valid)
                self.assertEqual(health.call_args.args,({'host':'?'},'state-error'))
                hardware.assert_not_called()

    def test_startup_missing_or_wrong_shape_fails_oneshot_without_defaults(self):
        with tempfile.TemporaryDirectory() as temp,patch.object(c,'CONFIG',Path(temp)/'config.json'),patch.object(c,'command') as hardware:
            with self.assertRaises(FileNotFoundError):c.startup_config()
            for value in ([],{'baseline':[]},{'baseline':{'screens':[1]},'keys':{}}):
                c.CONFIG.write_text(json.dumps(value))
                with self.assertRaises(RuntimeError):c.startup_config()
            hardware.assert_not_called()

    def test_diagnostic_preserves_malformed_state_evidence_with_bounded_capture(self):
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp);raw=b'{broken\xff'+b'x'*70000
            (root/'control.json').write_bytes(raw)
            path=observability.diagnostics(root,root)
            result=json.loads(path.read_text());captured=result['unreadable_files']['control.json']
            self.assertEqual(base64.b64decode(captured['bytes_base64']),raw[:65536])
            self.assertTrue(captured['truncated'])
            self.assertEqual(result['file_sha256']['control.json'],hashlib.sha256(raw).hexdigest())
            self.assertEqual((root/'control.json').read_bytes(),raw)
            self.assertEqual(path.stat().st_mode&0o777,0o600)
    def test_invalid_controls_are_rejected_without_rewriting(self):
        values=[[],{'paused':'false'},{'pause_until':float('nan')},{'audio_manual_until':-1},{'speaker_preferences':{'extended':'unknown'}},{'auto_rotate':'yes'}]
        with tempfile.TemporaryDirectory() as temp,patch.object(c,'CONTROL',Path(temp)/'control.json'):
            for value in values:
                with self.subTest(value=value):
                    data=json.dumps(value);c.CONTROL.write_text(data)
                    with self.assertRaises(RuntimeError):c.read_control()
                    self.assertEqual(c.CONTROL.read_text(),data)
    def test_bad_recovery_is_rejected_without_resetting_budget(self):
        values=[[],{'attempts':-1},{'attempts':4},{'pending':'yes'},{'retry_at':float('inf')},{'orientation':45}]
        with tempfile.TemporaryDirectory() as temp:
            path=Path(temp)/'recovery.json'
            for value in values:
                with self.subTest(value=value):
                    if isinstance(value,dict):value=dict(c.Recovery().data,**value)
                    data=json.dumps(value);path.write_text(data)
                    with self.assertRaises(RuntimeError):c.Recovery(path)
                    self.assertEqual(path.read_text(),data)
    def test_corrupt_control_stops_hardware_until_repaired_without_restart(self):
        class Finished(Exception):pass
        statuses=[]
        with tempfile.TemporaryDirectory() as temp,patch.object(c,'ROOT',Path(temp)),patch.object(c,'CONTROL',Path(temp)/'control.json'):
            c.CONTROL.write_text('{broken')
            def sleep(seconds):
                self.assertEqual(c.CONTROL.read_text(),'{broken')
                c.CONTROL.write_text('{"paused":true}')
            def health(cfg,status,*a,**kw):
                statuses.append(status)
                if status=='paused':raise Finished()
            with patch.object(c,'new_recovery',side_effect=lambda:c.Recovery()),patch.object(c,'write_health',side_effect=health),patch.object(c,'read_inputs') as inputs,patch.object(c,'apply') as apply,patch.object(c.time,'sleep',side_effect=sleep):
                with self.assertRaises(Finished):c.watch({'host':'A','poll_interval':.25})
            self.assertIn('state-error',statuses);self.assertIn('paused',statuses)
            inputs.assert_not_called();apply.assert_not_called()
    def test_corrupt_recovery_stops_hardware_and_preserves_original_file(self):
        class Finished(Exception):pass
        with tempfile.TemporaryDirectory() as temp,patch.object(c,'ROOT',Path(temp)):
            path=c.ROOT/'recovery.json';path.write_text('[]')
            with patch.object(c,'write_health') as health,patch.object(c,'read_inputs') as inputs,patch.object(c.time,'sleep',side_effect=Finished):
                with self.assertRaises(Finished):c.watch({'host':'A'})
            self.assertEqual(health.call_args.args[1],'state-error')
            inputs.assert_not_called();self.assertEqual(path.read_text(),'[]')
    def test_valid_recovery_retries_after_file_repair_preserve_exhaustion(self):
        class Finished(Exception):pass
        work=c.Recovery();work.select({'pg':17,'benq':19},'extended',0)
        for n in range(3):work.failed('existing failure',n)
        statuses=[]
        def health(cfg,status,*a,**kw):
            statuses.append(status)
            if status=='degraded':raise Finished()
        with patch.object(c,'new_recovery',side_effect=[c.StateFileError('broken'),work]),patch.object(c,'read_control',return_value={}),patch.object(c,'read_inputs',return_value={'pg':17,'benq':19}),patch.object(c,'audio_inventory',return_value=[]),patch.object(c,'apply') as apply,patch.object(c,'write_health',side_effect=health),patch.object(c.time,'sleep'):
            with self.assertRaises(Finished):c.watch({'host':'A','poll_interval':0})
        self.assertIn('state-error',statuses);self.assertEqual(work.data['attempts'],3)
        apply.assert_not_called()
    def test_deleting_damaged_recovery_does_not_create_fresh_budget(self):
        class Finished(Exception):pass
        with tempfile.TemporaryDirectory() as temp,patch.object(c,'ROOT',Path(temp)):
            path=c.ROOT/'recovery.json';path.write_text('[]');errors=[]
            def health(cfg,status,*a,**kw):
                errors.append(kw.get('error',''))
                if len(errors)==2:raise Finished()
            with patch.object(c,'write_health',side_effect=health),patch.object(c,'read_inputs') as inputs,patch.object(c.time,'sleep',side_effect=lambda _:path.unlink(missing_ok=True)):
                with self.assertRaises(Finished):c.watch({'host':'A'})
            self.assertIn('disappeared',errors[-1]);inputs.assert_not_called()
    def test_deleting_damaged_controls_does_not_resume_with_defaults(self):
        class Finished(Exception):pass
        with tempfile.TemporaryDirectory() as temp,patch.object(c,'ROOT',Path(temp)),patch.object(c,'CONTROL',Path(temp)/'control.json'):
            c.CONTROL.write_text('[]');errors=[]
            def health(cfg,status,*a,**kw):
                if status=='state-error':errors.append(kw['error'])
                if len(errors)==2:raise Finished()
            with patch.object(c,'write_health',side_effect=health),patch.object(c,'read_inputs') as inputs,patch.object(c.time,'sleep',side_effect=lambda _:c.CONTROL.unlink(missing_ok=True)):
                with self.assertRaises(Finished):c.watch({'host':'A','poll_interval':.25})
            self.assertIn('disappeared',errors[-1]);inputs.assert_not_called()
    def test_manual_rotation_leaves_input_and_audio_automation_active(self):
        cfg={'host':'A','poll_interval':0,'rotation':{'enabled':True}}
        with patch.object(c,'new_recovery',side_effect=lambda:c.Recovery()),patch.object(c,'read_control',return_value={'auto_rotate':False}),patch.object(c,'read_inputs',return_value={'pg':17,'benq':19}),patch.object(c,'read_rotation') as sensor,patch.object(c,'audio_inventory',return_value=[]),patch.object(c,'apply_rotation',return_value=False) as rotate,patch.object(c,'apply',return_value=False) as layout,patch.object(c,'confirm_inputs'),patch.object(c,'sync_audio') as audio,patch.object(c,'record'),patch.object(c,'write_health'),patch.object(c.time,'sleep'):
            c.watch(cfg,once=True)
        sensor.assert_not_called();self.assertIsNone(rotate.call_args.args[2])
        layout.assert_called_once();audio.assert_called_once()
        self.assertEqual(cfg['_rotation_status']['state'],'manual')
    def test_rotation_control_preserves_other_preferences(self):
        with tempfile.TemporaryDirectory() as temp,patch.object(c,'ROOT',Path(temp)),patch.object(c,'CONTROL',Path(temp)/'control.json'),patch('builtins.print'):
            c.CONTROL.write_text('{"speaker_preferences":{"extended":"benq"}}')
            c.control_command('rotation-manual',30)
            self.assertFalse(c.read_control()['auto_rotate'])
            c.control_command('rotation-auto',30)
            self.assertTrue(c.read_control()['auto_rotate'])
            self.assertEqual(c.read_control()['speaker_preferences'],{'extended':'benq'})

if __name__=='__main__':unittest.main()
