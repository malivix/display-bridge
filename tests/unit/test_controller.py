import importlib.util
import json
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
    def test_listening_check_preserves_output_and_requires_human_confirmation(self):
        config={'host':'A','audio':{'enabled':True,'pg':'p','benq':'b','fallback':'i'}}
        for uid,category in [('p','pg'),('b','benq'),('i','fallback'),('headset','external')]:
            with patch.object(c,'audio_inventory',return_value=[{'uid':uid,'alive':True,'default':True}]),patch.object(c,'read_inputs',return_value={'pg':17,'benq':19}),patch.object(c,'command',return_value='') as run:
                result=c.listening_check(config)
                self.assertEqual(result['output'],category)
                self.assertEqual(result['audibility'],'unconfirmed')
                self.assertNotIn('uid',result)
                run.assert_called_once_with(['/usr/bin/afplay','-v','0.1','/System/Library/Sounds/Glass.aiff'],timeout=3)

    def test_listening_check_rejects_remote_or_changed_route_and_never_retries(self):
        config={'host':'A','audio':{'enabled':True,'pg':'p'}}
        selected={'uid':'p','alive':True,'default':True}
        with patch.object(c,'audio_inventory',return_value=[selected]),patch.object(c,'read_inputs',return_value={'pg':18,'benq':19}),patch.object(c,'command') as run:
            with self.assertRaisesRegex(RuntimeError,'other Mac'):c.listening_check(config)
            run.assert_not_called()
        with patch.object(c,'audio_inventory',side_effect=[[selected],[selected],[dict(selected,uid='other')]]),patch.object(c,'read_inputs',return_value={'pg':17,'benq':19}),patch.object(c,'command',return_value='') as run:
            with self.assertRaisesRegex(RuntimeError,'inconclusive'):c.listening_check(config)
            self.assertEqual(run.call_count,1)
        with patch.object(c,'audio_inventory',return_value=[selected]),patch.object(c,'read_inputs',return_value={'pg':17,'benq':19}),patch.object(c,'command',side_effect=c.subprocess.TimeoutExpired('afplay',3)) as run:
            with self.assertRaises(c.subprocess.TimeoutExpired):c.listening_check(config)
            self.assertEqual(run.call_count,1)

    def test_listening_check_rechecks_before_playback_and_marks_postcheck_failure(self):
        config={'host':'A','audio':{'enabled':True,'pg':'p'}}
        selected={'uid':'p','alive':True,'default':True}
        local={'pg':17,'benq':19};remote={'pg':18,'benq':19}
        for reads,plays in [([local,remote],0),([local,local,remote],1)]:
            with patch.object(c,'audio_inventory',return_value=[selected]),patch.object(c,'read_inputs',side_effect=reads),patch.object(c,'command',return_value='') as run:
                with self.assertRaisesRegex(RuntimeError,'no sample|inconclusive'):c.listening_check(config)
                self.assertEqual(run.call_count,plays)
        with patch.object(c,'audio_inventory',side_effect=[[selected],[selected],RuntimeError('missing output')]),patch.object(c,'read_inputs',return_value=local),patch.object(c,'command',return_value='') as run:
            with self.assertRaisesRegex(RuntimeError,'returned.*inconclusive'):c.listening_check(config)
            self.assertEqual(run.call_count,1)

    def test_listening_check_requires_live_unambiguous_output(self):
        config={'host':'A','audio':{'enabled':True,'pg':'p'}}
        selected={'uid':'p','alive':True,'default':True}
        for devices in ([],[selected,selected],[dict(selected,alive=False)],[dict(selected,default=1)],{}):
            with patch.object(c,'audio_inventory',return_value=devices),patch.object(c,'read_inputs',return_value={'pg':17,'benq':19}),patch.object(c,'command') as run:
                with self.assertRaises(RuntimeError):c.listening_check(config)
                run.assert_not_called()

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
    def test_mirror_direction_and_resolution_are_described(self):
        # The native helper compares; the controller must describe the direction and
        # keep the source's saved mode so that comparison has something to enforce.
        base=[dict(key=k,width=100,height=80,pixelWidth=200,pixelHeight=160,hz=120,rotation=0,x=x,y=0) for k,x in [('p',0),('b',100)]]
        config={'keys':{'pg':'p','benq':'b'},'baseline':{'screens':base}}
        rows={s['key']:s for s in c.derive_baseline(config,'pg')['screens']}
        self.assertEqual(rows['b']['mirrorOf'],'p')
        self.assertNotIn('mirrorOf',rows['p'])
        self.assertEqual(rows['p']['width'],100)
    def test_apply_hands_the_derived_baseline_to_the_helper(self):
        base=[dict(key=k,width=100,height=80,pixelWidth=200,pixelHeight=160,hz=120,rotation=0,x=x,y=0) for k,x in [('p',0),('b',100)]]
        config={'keys':{'pg':'p','benq':'b'},'baseline':{'screens':base}}
        calls=[]
        def helper(args,*a):
            calls.append(args);return json.dumps({'changed':args[1]=='apply' and len(calls)==1})
        with tempfile.TemporaryDirectory() as temp,patch.object(c,'ROOT',Path(temp)),patch.object(c,'command',side_effect=helper):
            self.assertTrue(c.apply(config,'benq'))
            written=json.loads((Path(temp)/'rotation-active.json').read_text())
            self.assertEqual(calls[0],[c.HELPER,'apply',Path(temp)/'rotation-active.json'])
            self.assertEqual(written,c.derive_baseline(config,'benq'))
            self.assertFalse(c.apply(config,'benq'))
            self.assertFalse(c.apply(config,'away'))
        self.assertEqual(len(calls),2)
    def test_failed_native_apply_is_not_success(self):
        config={'keys':{'pg':'p','benq':'b'},'baseline':{'screens':[]}}
        with tempfile.TemporaryDirectory() as temp,patch.object(c,'ROOT',Path(temp)),patch.object(c,'command',side_effect=RuntimeError('display-layout: Layout readback differs')):
            with self.assertRaisesRegex(RuntimeError,'readback'):c.apply(config,'extended')

class ReliabilityTests(unittest.TestCase):
    def setUp(self):
        for name,value in [('verify_setup',lambda *a:None),('record',lambda *a:None),('new_recovery',lambda:c.Recovery()),('read_control',lambda:{}),('audio_inventory',lambda cfg:[]),('confirm_inputs',lambda *a:None)]:
            patcher=patch.object(c,name,value);patcher.start();self.addCleanup(patcher.stop)

    def test_deadline_expires(self):
        with self.assertRaises(TimeoutError): c.remaining(c.time.monotonic()-1, 5)

    def test_derive_baseline_describes_mirroring_per_profile(self):
        saved = {'screens': [
            {'key': 'PG', 'width': 2048, 'height': 1152, 'x': 0, 'y': 0, 'rotation': 0,
             'pixelWidth': 4096, 'pixelHeight': 2304, 'hz': 120, 'modeID': 1, 'strictMode': True},
            {'key': 'BQ', 'width': 1280, 'height': 853, 'x': -1280, 'y': 0, 'rotation': 0,
             'pixelWidth': 2560, 'pixelHeight': 1706, 'hz': 120, 'modeID': 2, 'strictMode': True}]}
        config = {'keys': {'pg': 'PG', 'benq': 'BQ'}, 'baseline': saved}

        extended = {s['key']: s for s in c.derive_baseline(config, 'extended')['screens']}
        self.assertIsNone(extended['PG'].get('mirrorOf'))
        self.assertIsNone(extended['BQ'].get('mirrorOf'))
        self.assertEqual((extended['BQ']['x'], extended['BQ']['y']), (-1280, 0))

        pg = {s['key']: s for s in c.derive_baseline(config, 'pg')['screens']}
        self.assertEqual(pg['BQ']['mirrorOf'], 'PG')
        # The surviving source moves to the origin, as the native helper used to do itself.
        self.assertEqual((pg['PG']['x'], pg['PG']['y']), (0, 0))
        self.assertIsNone(pg['PG'].get('mirrorOf'))

        benq = {s['key']: s for s in c.derive_baseline(config, 'benq')['screens']}
        self.assertEqual(benq['PG']['mirrorOf'], 'BQ')
        self.assertEqual((benq['BQ']['x'], benq['BQ']['y']), (0, 0))

    def test_derive_baseline_leaves_a_mirrored_screen_without_a_mode(self):
        saved = {'screens': [
            {'key': 'PG', 'width': 2048, 'height': 1152, 'x': 0, 'y': 0, 'rotation': 0,
             'pixelWidth': 4096, 'pixelHeight': 2304, 'hz': 120, 'modeID': 1, 'strictMode': True},
            {'key': 'BQ', 'width': 1280, 'height': 853, 'x': -1280, 'y': 0, 'rotation': 90,
             'pixelWidth': 2560, 'pixelHeight': 1706, 'hz': 120, 'modeID': 2, 'strictMode': True}]}
        config = {'keys': {'pg': 'PG', 'benq': 'BQ'}, 'baseline': saved}
        rows = {s['key']: s for s in c.derive_baseline(config, 'pg')['screens']}
        mirrored, master = rows['BQ'], rows['PG']
        self.assertEqual(mirrored['mirrorOf'], 'PG')
        # Rows decode into a type whose geometry is required, so a mirrored row carries
        # its master's. It never carries a mode requirement of its own.
        for field in ('width', 'height', 'pixelWidth', 'pixelHeight', 'hz', 'rotation'):
            self.assertEqual(mirrored[field], master[field], field)
        self.assertNotIn('modeID', mirrored)
        self.assertNotIn('strictMode', mirrored)
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

    def test_live_phase_is_published_before_each_operation(self):
        events=[];reports=[]
        def health(config,status,*args,**details):
            reports.append(details)
            if 'transition' in details:
                events.append(details['transition']['phase'])
                self.assertEqual(status,'recovering')
                self.assertIn('recovery',details)
        with patch.object(c,'write_health',side_effect=health),patch.object(c,'read_inputs',return_value={'pg':17,'benq':19}),patch.object(c,'apply_rotation',side_effect=lambda *a:events.append('native')),patch.object(c,'apply',side_effect=lambda *a:events.append('layout')),patch.object(c,'sync_audio',side_effect=lambda *a,**k:events.append('audio-call')):
            c.watch({'host':'A','poll_interval':0},once=True)
        self.assertEqual(events,['rotation_check','native','layout_apply','layout','input_confirmation','audio','audio-call'])
        self.assertNotIn('transition',reports[-1])

    def test_failed_transitions_keep_only_completed_phase_timings(self):
        for failing,expected,completed in [('apply_rotation','rotation_check',set()),('apply','layout_apply',{'rotation_check'}),('sync_audio','audio',{'rotation_check','layout','layout_apply','input_confirmation'})]:
            with self.subTest(phase=expected), patch.object(c,'write_health'), patch.object(c,'read_inputs',return_value={'pg':17,'benq':19}), patch.object(c,'apply_rotation',return_value=False), patch.object(c,'apply',return_value=True), patch.object(c,'sync_audio',return_value='ready'), patch.object(c,'record') as record:
                with patch.object(c,failing,side_effect=RuntimeError('Synthetic phase failure')):
                    with self.assertRaises(RuntimeError):c.watch({'host':'A','poll_interval':0},once=True)
                event=record.call_args.args[1]
                self.assertEqual(event['result'],'failed')
                self.assertEqual(event['failed_phase'],expected)
                self.assertEqual(set(event['seconds']),completed|{'total','observed_to_outcome'})
                self.assertGreaterEqual(event['failed_phase_seconds'],0)
                self.assertGreaterEqual(event['seconds']['total'],event['failed_phase_seconds'])
                self.assertGreaterEqual(event['seconds']['observed_to_outcome'],event['seconds']['total'])

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

    def test_validate_config_accepts_an_optional_builtin_identity(self):
        from tempfile import TemporaryDirectory
        with TemporaryDirectory() as temp:
            path=Path(temp)/'baseline.json'
            baseline={'screens':[{'key':'PG'},{'key':'BQ'}]}
            path.write_text(json.dumps(baseline))
            def config(**extra):
                return dict({'version':c.VERSION,'host':'B','poll_interval':.25,
                             'keys':{'pg':'PG','benq':'BQ'},'baseline':baseline},**extra)
            with patch.object(c,'BASELINE',path):
                c.validate_config(config())
                c.validate_config(config(builtin='LID'))
                for bad in ('PG','BQ','',7):
                    with self.subTest(builtin=bad),self.assertRaisesRegex(RuntimeError,'built-in'):
                        c.validate_config(config(builtin=bad))

    def test_capture_identifies_benq_on_either_input_edid(self):
        # The RD280UG publishes a different EDID product code per physical input, so
        # the two hosts see different model numbers for the same panel.
        screens=[{'key':'1715:17120:example-pg','hz':120,'width':2048,'height':1152,
                  'pixelWidth':4096,'pixelHeight':2304,'rotation':0,'x':0,'y':0},
                 {'key':None,'hz':120,'width':1280,'height':853,
                  'pixelWidth':2560,'pixelHeight':1706,'rotation':0,'x':-1280,'y':0}]
        for host,benq in [('A','2513:32963:example-benq'),('B','2513:32959:example-benq')]:
            pair=[dict(screens[0]),dict(screens[1],key=benq)]
            with patch.object(c,'layout',return_value=pair),patch.object(c,'command',return_value='[]'),\
                 patch.object(c,'capture_identifiers',return_value={}),patch.object(c,'capture_audio',return_value={}),\
                 patch.object(c,'read_inputs',return_value=c.INPUTS[host]),patch('time.sleep'),\
                 patch('display_snapshot.validate_capture_modes'):
                config=c.capture_configuration(host,'/tmp/display-ddc')
            self.assertEqual(config['keys'],{'pg':'1715:17120:example-pg','benq':benq})

    def test_capture_does_not_save_the_builtin_report(self):
        pair=[{'key':'1715:17120:example-pg','hz':120,'width':2048,'height':1152,'builtin':False,
               'pixelWidth':4096,'pixelHeight':2304,'rotation':0,'x':0,'y':0},
              {'key':'2513:32959:example-benq','hz':120,'width':1280,'height':853,'builtin':False,
               'pixelWidth':2560,'pixelHeight':1706,'rotation':0,'x':-1280,'y':0}]
        with patch.object(c,'layout',return_value=pair),patch.object(c,'command',return_value='[]'),\
             patch.object(c,'capture_identifiers',return_value={}),patch.object(c,'capture_audio',return_value={}),\
             patch.object(c,'read_inputs',return_value=c.INPUTS['B']),patch('time.sleep'),\
             patch('display_snapshot.validate_capture_modes'):
            config=c.capture_configuration('B','/tmp/display-ddc')
        self.assertTrue(all('builtin' not in s and s['strictMode'] for s in config['baseline']['screens']))

    def test_capture_rejects_an_unknown_panel(self):
        pair=[{'key':'1715:17120:example-pg','hz':120,'width':2048,'height':1152,
               'pixelWidth':4096,'pixelHeight':2304,'rotation':0,'x':0,'y':0},
              {'key':'2513:1:example-unknown','hz':120,'width':1280,'height':853,
               'pixelWidth':2560,'pixelHeight':1706,'rotation':0,'x':-1280,'y':0}]
        with patch.object(c,'layout',return_value=pair),patch('display_snapshot.validate_capture_modes'):
            with self.assertRaisesRegex(RuntimeError,'Cannot uniquely identify benq'):
                c.capture_configuration('B','/tmp/display-ddc')

if __name__=='__main__': unittest.main()
