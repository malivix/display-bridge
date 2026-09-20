import importlib.util
from pathlib import Path
import unittest
import tempfile
from unittest.mock import patch
spec = importlib.util.spec_from_file_location('controller', (Path(__file__).resolve().parents[2]/'display-auto.py'))
c = importlib.util.module_from_spec(spec)
spec.loader.exec_module(c)

class ControllerTests(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        for name, value in [('ROOT', Path(temp.name)), ('verify_setup', lambda *args: None)]:
            patcher = patch.object(c, name, value)
            patcher.start()
            self.addCleanup(patcher.stop)
    def test_roles_are_opposites(self):
        cases = [(17,19,'extended','away'), (17,15,'pg','benq'),
                 (18,19,'benq','pg'), (18,15,'away','extended')]
        for pg, benq, a, b in cases:
            self.assertEqual(c.desired('A', {'pg':pg,'benq':benq}), a)
            self.assertEqual(c.desired('B', {'pg':pg,'benq':benq}), b)
    def test_invalid_states_do_not_write(self):
        for profile in ['away','unknown']:
            with patch.object(c, 'command') as command, patch.object(c, 'layout') as layout:
                c.apply({},profile)
                command.assert_not_called()
                layout.assert_not_called()
        self.assertEqual(c.desired('A',{'pg':17,'benq':99}),'unknown')
    def test_debounce_resets_after_failed_read(self):
        d=c.Debounce()
        self.assertFalse(d.observe((17,15)))
        d.reset()
        self.assertFalse(d.observe((17,15)))
        self.assertTrue(d.observe((17,15)))
        self.assertFalse(d.observe((18,15)))
    def test_ddc_rejects_error_text_even_on_zero_exit(self):
        config={'m1ddc':'unused','keys':{'pg':'p','benq':'b'}}
        with patch.object(c,'command',return_value='DDC read failed 17'):
            with self.assertRaises(RuntimeError): c.read_inputs(config)
    def test_mirror_direction_and_resolution_are_checked(self):
        base=[dict(key=k,width=100,height=80,pixelWidth=200,pixelHeight=160,hz=120,rotation=0,x=x,y=0) for k,x in [('p',0),('b',100)]]
        config={'keys':{'pg':'p','benq':'b'},'baseline':{'screens':base}}
        actual=[dict(base[0]),dict(base[1],mirrorOf='p',x=0)]
        self.assertTrue(c.matches(config,'pg',actual))
        wrong=[dict(base[0],mirrorOf='b'),dict(base[1],x=0)]
        self.assertFalse(c.matches(config,'pg',wrong))
        actual[0]['width']=80
        self.assertFalse(c.matches(config,'pg',actual))
    def test_topology_change_is_rejected(self):
        self.assertFalse(c.matches({'baseline':{'screens':[]},'keys':{}},'extended',[]))

class ReliabilityTests(unittest.TestCase):
    def setUp(self):
        for name,value in [('verify_setup',lambda *a:None),('record',lambda *a:None),('new_recovery',lambda:c.Recovery()),('read_control',lambda:{}),('audio_inventory',lambda cfg:[]),('confirm_inputs',lambda *a:None)]:
            patcher=patch.object(c,name,value);patcher.start();self.addCleanup(patcher.stop)

    def test_deadline_expires(self):
        with self.assertRaises(TimeoutError): c.remaining(c.time.monotonic()-1, 5)

    def test_busy_reader_lock_is_bounded(self):
        with patch.object(c.fcntl,'flock',side_effect=BlockingIOError):
            with self.assertRaises(TimeoutError): c.acquire_lock(None,0)

    def test_unknown_once_is_not_success(self):
        config={'host':'A','poll_interval':0}
        with patch.object(c,'write_health'), patch.object(c,'read_inputs',return_value={'pg':99,'benq':19}), patch.object(c,'command') as command:
            with self.assertRaisesRegex(RuntimeError,'Unknown'): c.watch(config,once=True)
            command.assert_not_called()

    def test_oscillating_inputs_cannot_hang_once(self):
        import itertools
        config={'host':'A','poll_interval':.001}
        with patch.object(c,'write_health'), patch.object(c,'ONCE_TIMEOUT',.03), patch.object(c,'read_inputs',side_effect=itertools.cycle([{'pg':17,'benq':19},{'pg':18,'benq':19}])), patch.object(c,'apply') as apply:
            with self.assertRaises(TimeoutError): c.watch(config,once=True)
            apply.assert_not_called()

    def test_failed_read_never_changes_layout(self):
        with patch.object(c,'write_health'), patch.object(c,'read_inputs',side_effect=RuntimeError('unavailable')), patch.object(c,'apply') as apply:
            with self.assertRaises(RuntimeError): c.watch({'host':'A'},once=True)
            apply.assert_not_called()

    def test_audio_selection_follows_successful_layout(self):
        events=[]
        with patch.object(c,'write_health'), patch.object(c,'read_inputs',return_value={'pg':18,'benq':19}), patch.object(c,'apply',side_effect=lambda *a:events.append('layout')), patch.object(c,'sync_audio',side_effect=lambda *a,**k:events.append('audio')):
            c.watch({'host':'A','poll_interval':0},once=True)
        self.assertEqual(events,['layout','audio'])

    def test_input_change_during_rotation_preflight_prevents_layout_write(self):
        class Finished(Exception):
            pass
        with patch.object(c, 'write_health'), patch.object(c, 'read_inputs', return_value={'pg':17,'benq':19}), \
             patch.object(c, 'apply_rotation', return_value=False), \
             patch.object(c, 'confirm_inputs', side_effect=Finished), patch.object(c, 'apply') as apply:
            with self.assertRaises(Finished):
                c.watch({'host':'A','poll_interval':0}, once=True)
            apply.assert_not_called()

    def test_failed_transitions_keep_only_completed_phase_timings(self):
        for failing,expected,completed in [('apply_rotation','rotation_check',set()),('apply','layout_apply',{'rotation_check'}),('sync_audio','audio',{'rotation_check','layout','layout_apply','input_confirmation'})]:
            with self.subTest(phase=expected), patch.object(c,'write_health'), patch.object(c,'read_inputs',return_value={'pg':17,'benq':19}), patch.object(c,'apply_rotation',return_value=False), patch.object(c,'apply',return_value=True), patch.object(c,'sync_audio',return_value='ready'), patch.object(c,'record') as record:
                with patch.object(c,failing,side_effect=RuntimeError('Synthetic phase failure')):
                    with self.assertRaises(RuntimeError):c.watch({'host':'A','poll_interval':0},once=True)
                event=record.call_args.args[1]
                self.assertEqual(event['result'],'failed')
                self.assertEqual(event['failed_phase'],expected)
                self.assertEqual(set(event['seconds']),completed|{'total'})
                self.assertGreaterEqual(event['failed_phase_seconds'],0)
                self.assertGreaterEqual(event['seconds']['total'],event['failed_phase_seconds'])

    def test_audio_is_not_rerouted_after_failed_layout(self):
        with patch.object(c,'write_health'), patch.object(c,'read_inputs',return_value={'pg':18,'benq':19}), patch.object(c,'apply',side_effect=RuntimeError('layout failed')), patch.object(c,'sync_audio') as audio:
            with self.assertRaises(RuntimeError): c.watch({'host':'A','poll_interval':0},once=True)
            audio.assert_not_called()

    def test_pg_refresh_is_transition_only_and_preserves_external_audio(self):
        import json
        audio={'enabled':True,'pg':'p','benq':'b','fallback':'i','refresh_on_transition':['pg','benq']}
        devices=[dict(uid=k,name=k,alive=True,default=k=='p',system=k=='p') for k in ['p','b','i','headset']]
        with patch.object(c,'command',side_effect=lambda args,**kw:json.dumps({'original_rate':48000} if 'refresh' in args else devices)) as command:
            c.sync_audio({'audio':audio},'extended',refresh=False)
            self.assertFalse(any('refresh' in call.args[0] for call in command.call_args_list))
        with patch.object(c,'command',side_effect=lambda args,**kw:json.dumps({'original_rate':48000} if 'refresh' in args else devices)) as command:
            c.sync_audio({'audio':audio},'extended',refresh=True)
            self.assertEqual(sum('refresh' in call.args[0] for call in command.call_args_list),1)
        devices[0]['default']=False;devices[0]['system']=False
        devices[1]['default']=True;devices[1]['system']=True
        with patch.object(c,'command',side_effect=lambda args,**kw:json.dumps({'original_rate':48000} if 'refresh' in args else devices)) as command:
            c.sync_audio({'audio':audio},'benq',refresh=True)
            self.assertTrue(any(call.args[0] == [c.AUDIO,'refresh','b',c.JOURNAL] for call in command.call_args_list))
        devices[1]['default']=False;devices[3]['default']=True
        with patch.object(c,'command',side_effect=lambda args,**kw:json.dumps({'original_rate':48000} if 'refresh' in args else devices)) as command:
            c.sync_audio({'audio':audio},'extended',refresh=True)
            self.assertFalse(any('refresh' in call.args[0] or 'select' in call.args[0] for call in command.call_args_list))

    def test_concurrent_audio_selection_is_preserved(self):
        import json
        devices=[dict(uid=k,name=k,alive=True,default=k=='b',system=k=='b') for k in ['p','b','i','headset']]
        def command(args,**kw):
            if 'select' in args:
                self.assertEqual(args[-2:],['b','b'])
                devices[1]['default']=False;devices[3]['default']=True
                raise c.AudioSelectionChanged('changed')
            return json.dumps(devices)
        with patch.object(c,'command',side_effect=command):
            result=c.sync_audio({'audio':{'enabled':True,'pg':'p','benq':'b','fallback':'i'}},'extended',refresh=True)
        self.assertEqual(result['state'],'concurrent-selection-preserved')
        self.assertEqual(result['selected']['uid'],'headset')
        self.assertFalse(result['refreshed'])

    def test_wake_gap_requires_two_new_samples(self):
        class Finished(Exception): pass
        with patch.object(c,'write_health'), patch.object(c.time,'time',side_effect=[0,0,1,10,11]), patch.object(c,'read_inputs',return_value={'pg':17,'benq':19}) as reads, patch.object(c,'apply',side_effect=[None,Finished]) as apply:
            with self.assertRaises(Finished): c.watch({'host':'A','poll_interval':0})
            self.assertEqual(reads.call_count,4)
            self.assertEqual(apply.call_count,2)

    def test_recovery_requires_two_new_samples(self):
        class Finished(Exception): pass
        valid={'pg':17,'benq':19}
        with patch.object(c,'write_health'), patch.object(c,'read_inputs',side_effect=[valid,RuntimeError('offline'),valid,valid]) as reads, patch.object(c,'apply',side_effect=Finished):
            with self.assertRaises(Finished): c.watch({'host':'A','poll_interval':0})
            self.assertEqual(reads.call_count,4)

    def test_mismatched_baseline_is_rejected(self):
        from tempfile import TemporaryDirectory
        with TemporaryDirectory() as temp:
            path=Path(temp)/'baseline.json'; path.write_text('{}')
            config={'version':c.VERSION,'host':'A','poll_interval':.25,'keys':{'pg':'p','benq':'b'},'baseline':{'screens':[{'key':'p'},{'key':'b'}]}}
            with patch.object(c,'BASELINE',path):
                with self.assertRaisesRegex(RuntimeError,'differs'): c.validate_config(config)

if __name__=='__main__': unittest.main()
