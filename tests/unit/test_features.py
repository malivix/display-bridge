import importlib.util,json,tempfile,unittest
from pathlib import Path
from unittest.mock import patch
import observability as o
from audio_policy import route,preference
spec=importlib.util.spec_from_file_location('c',(Path(__file__).resolve().parents[2]/'display-auto.py'));c=importlib.util.module_from_spec(spec);spec.loader.exec_module(c)
class Features(unittest.TestCase):
    def test_fast_sensor_confirmation_rejects_bounce_and_failure(self):
        cfg={'rotation':{'enabled':True}}
        for result in (0,None,RuntimeError('sensor offline')):
            d=c.Debounce()
            with patch.object(c,'read_rotation',side_effect=[result]),patch.object(c.time,'sleep'):
                self.assertFalse(c.stable_state(cfg,d,(17,19,90),(17,19,0),'extended'))
            self.assertEqual(d.count,0)
    def test_fast_confirmation_is_not_used_for_input_changes_or_hidden_benq(self):
        cfg={'rotation':{'enabled':True}}
        for state,last,profile in [((18,19,90),(17,19,0),'benq'),((17,15,90),(17,15,0),'pg'),((17,19,90),None,'extended')]:
            with patch.object(c,'read_rotation') as read:
                self.assertFalse(c.stable_state(cfg,c.Debounce(),state,last,profile))
                read.assert_not_called()
    def test_rotation_confirmation_does_not_wait_for_another_input_poll(self):
        class Finished(Exception):pass
        calls=[]
        def rotate(*args):
            calls.append(args[2])
            if args[2]==90:raise Finished()
            return False
        cfg={'host':'A','poll_interval':.25,'rotation':{'enabled':True}}
        with patch.object(c,'new_recovery',side_effect=lambda:c.Recovery()),patch.object(c,'read_control',return_value={}),patch.object(c,'read_inputs',return_value={'pg':17,'benq':19}) as inputs,patch.object(c,'read_rotation',side_effect=[0,0,90,90]),patch.object(c,'audio_inventory',return_value=[]),patch.object(c,'apply_rotation',side_effect=rotate),patch.object(c,'apply',return_value=False),patch.object(c,'confirm_inputs'),patch.object(c,'sync_audio'),patch.object(c,'record'),patch.object(c,'write_health'),patch.object(c.time,'sleep'):
            with self.assertRaises(Finished):c.watch(cfg)
        self.assertEqual(calls,[0,90])
        self.assertEqual(inputs.call_count,3,'rotation waited for another full input poll')
    def test_settling_clock_stops_at_confirmation_and_resets(self):
        d=c.Debounce()
        with patch.object(c.time,'monotonic',side_effect=[10,10.75,30,31,32]):
            self.assertFalse(d.observe((17,19,0)))
            self.assertTrue(d.observe((17,19,0)))
            self.assertEqual(d.confirmed_after,.75)
            self.assertTrue(d.observe((17,19,0)))
            self.assertEqual(d.confirmed_after,.75)
            self.assertFalse(d.observe((17,19,90)))
            self.assertIsNone(d.confirmed_after)
            self.assertTrue(d.observe((17,19,90)))
            self.assertEqual(d.confirmed_after,1)
        d.reset();self.assertIsNone(d.first_seen)
    def test_rotation_history_measures_actual_controller_phases(self):
        clock=[100.0];events=[]
        def spend(seconds,result):
            def call(*a,**kw):clock[0]+=seconds;return result
            return call
        with patch.object(c,'new_recovery',side_effect=lambda:c.Recovery()),patch.object(c,'read_control',return_value={}),patch.object(c,'read_inputs',return_value={'pg':17,'benq':19}),patch.object(c,'read_rotation',return_value=90),patch.object(c,'audio_inventory',return_value=[]),patch.object(c,'apply_rotation',side_effect=spend(3,True)),patch.object(c,'apply',side_effect=spend(.5,True)),patch.object(c,'confirm_inputs',side_effect=spend(.6,None)),patch.object(c,'sync_audio',side_effect=spend(1,None)),patch.object(c,'record',side_effect=lambda root,event:events.append(event)),patch.object(c,'write_health'),patch.object(c.time,'monotonic',side_effect=lambda:clock[0]),patch.object(c.time,'time',side_effect=lambda:clock[0]),patch.object(c.time,'sleep',side_effect=spend(.25,None)):
            c.watch({'host':'A','poll_interval':.25,'rotation':{'enabled':True}},once=True)
        self.assertEqual(len(events),1)
        self.assertTrue(events[0]['rotated'])
        self.assertEqual(events[0]['orientation'],90)
        self.assertEqual(events[0]['seconds'],{'rotation_check':3,'layout_apply':1.1,'layout':4.1,'input_confirmation':.6,'audio':1,'total':5.7,'settling':.25})
    def test_history_phase_counts_and_even_median(self):
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp)
            for value in (1,3,5,7):o.record(root,{'profile':'extended','result':'ready','seconds':{'total':value}})
            o.record(root,{'profile':'extended','result':'ready','seconds':{'rotation_check':2}})
            o.record(root,{'profile':'extended','result':'failed','seconds':{'total':100}})
            phases=o.summary(root)['profiles']['extended']['seconds']
            self.assertEqual(phases['total']['median'],4)
            self.assertEqual(phases['total']['count'],4)
            self.assertEqual(phases['total']['p95'],7)
            self.assertEqual(phases['rotation_check']['count'],1)
    def test_other_setup_never_reads_ddc_or_audio(self):
        cfg={'keys':{'pg':'p','benq':'b'},'m1ddc':'ddc','audio':{'enabled':True}}
        for screens in ([{'key':'other'}],[{'key':'p'},{'key':'b'},{'key':'laptop'}],[{'key':'p'},{'key':'p'}]):
            with patch.object(c,'layout',return_value=screens),patch.object(c,'command') as command:
                with self.assertRaises(c.SetupUnavailable):c.read_inputs(cfg)
                with self.assertRaises(c.SetupUnavailable):c.sync_audio(cfg,'away')
                command.assert_not_called()
    def test_exact_pair_is_accepted(self):
        with patch.object(c,'layout',return_value=[{'key':'p'},{'key':'b'}]):c.verify_setup({'keys':{'pg':'p','benq':'b'}})
    def test_equal_hertz_does_not_accept_variable_mode(self):
        base=[dict(key=k,width=100,height=80,pixelWidth=200,pixelHeight=160,hz=120,rotation=0,x=x,y=0,modeID=7,strictMode=True) for k,x in [('p',0),('b',100)]]
        cfg={'keys':{'pg':'p','benq':'b'},'baseline':{'screens':base}}
        current=[dict(x) for x in base]
        self.assertTrue(c.matches(cfg,'extended',current))
        current[1]['modeID']=6
        self.assertFalse(c.matches(cfg,'extended',current))
    def test_matching_model_with_other_uuid_is_inactive(self):
        cfg={'keys':{'pg':'p','benq':'b'},'m1ddc':'unused','ddc_identifiers':{'pg':'uuid=aaaa','benq':'uuid=bbbb'}}
        with patch.object(c,'layout',return_value=[{'key':'p'},{'key':'b'}]),patch.object(c,'command',return_value='[1] PG42UQ (aaaa)\n[2] BenQ RD280UG (cccc)'):
            with self.assertRaises(c.SetupUnavailable):c.verify_setup(cfg)
    def test_rotation_waits_for_stable_sensor(self):
        class Finished(Exception):pass
        cfg={'host':'A','poll_interval':0,'rotation':{'enabled':True}}
        with patch.object(c,'new_recovery',side_effect=lambda:c.Recovery()),patch.object(c,'read_control',return_value={}),patch.object(c,'read_inputs',return_value={'pg':17,'benq':19}),patch.object(c,'read_rotation',side_effect=[0,90,90]),patch.object(c,'audio_inventory',return_value=[]),patch.object(c,'apply_rotation',side_effect=Finished) as rotate,patch.object(c,'write_health'),patch.object(c.time,'sleep'):
            with self.assertRaises(Finished):c.watch(cfg)
        self.assertEqual(rotate.call_count,1);self.assertEqual(rotate.call_args.args[2],90)
    def rotation_config(self):
        baselines={}
        for angle in (0,90):
            rows=[dict(key=k,width=1920,height=1080,pixelWidth=3840,pixelHeight=2160,hz=120,x=0,y=0,rotation=angle if k=='b' else 0) for k in ('p','b')]
            baselines[str(angle)]={'screens':rows}
        return {'keys':{'pg':'p','benq':'b'},'rotation':{'enabled':True,'sensor_map':{'1':0,'2':90},'baselines':baselines}}
    def test_hidden_benq_does_not_rotate(self):
        cfg=self.rotation_config()
        with tempfile.TemporaryDirectory() as temp,patch.object(c,'ROOT',Path(temp)),patch.object(c,'layout',return_value=[{'key':'b','rotation':0}]),patch.object(c,'command') as command:
            self.assertFalse(c.apply_rotation(cfg,'pg',90,{'pg':17,'benq':15}))
            command.assert_not_called()
    def test_changed_inputs_cancel_rotation(self):
        cfg=self.rotation_config()
        with tempfile.TemporaryDirectory() as temp,patch.object(c,'ROOT',Path(temp)),patch.object(c,'layout',return_value=[{'key':'b','rotation':0}]),patch.object(c,'confirm_inputs',side_effect=c.InputsChanged('changed')),patch.object(c,'command') as command,patch.object(c,'apply') as apply:
            with self.assertRaises(c.InputsChanged):c.apply_rotation(cfg,'extended',90,{'pg':17,'benq':19})
            command.assert_not_called();apply.assert_not_called()
    def test_rotation_switches_to_calibrated_baseline(self):
        cfg=self.rotation_config()
        with tempfile.TemporaryDirectory() as temp,patch.object(c,'ROOT',Path(temp)),patch.object(c,'layout',side_effect=[[{'key':'b','rotation':0}],[{'key':'b','rotation':90}]]),patch.object(c,'confirm_inputs'),patch.object(c,'command') as command,patch.object(c,'apply') as apply:
            self.assertTrue(c.apply_rotation(cfg,'extended',90,{'pg':17,'benq':19}))
            self.assertEqual(cfg['baseline'],cfg['rotation']['baselines']['90'])
            command.assert_called_once();apply.assert_not_called()
    def test_preserve_and_unavailable_speaker(self):
        a={'enabled':True,'pg':'p','benq':'b','fallback':'i','preferences':{'extended':'preserve','away':'pg'}}
        devices=[{'uid':'p','default':True,'system':True,'alive':True},{'uid':'i','alive':True}]
        self.assertIsNone(route(a,'extended',devices));self.assertEqual(route(a,'away',devices),('i','both'))
    def test_preferred_benq_and_external_override(self):
        a={'enabled':True,'pg':'p','benq':'b','fallback':'i','preferences':{'extended':'benq'}}
        devices=[{'uid':'p','default':True,'system':True,'alive':True},{'uid':'b','alive':True}]
        self.assertEqual(route(a,'extended',devices),('b','both'))
        devices[0]['uid']='headset';self.assertIsNone(route(a,'extended',devices))
    def test_history_is_bounded_and_failures_excluded(self):
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp)
            for i in range(205):o.record(root,{'profile':'pg','result':'ready','seconds':{'total':2}})
            o.record(root,{'profile':'pg','result':'failed','seconds':{'total':100}})
            result=o.summary(root);self.assertEqual(result['retained_events'],200)
            self.assertEqual(result['profiles']['pg']['count'],199);self.assertEqual(result['profiles']['pg']['seconds']['total']['mean'],2)
    def test_timing_summary_retains_failures_and_phase_sample_counts(self):
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp)
            o.record(root,{'profile':'benq','result':'failed'})
            for total in [1,2,3,4]:o.record(root,{'profile':'pg','result':'ready','seconds':{'total':total}})
            o.record(root,{'profile':'pg','result':'ready','seconds':{'audio':1}})
            report=o.summary(root)['profiles']
            self.assertEqual(report['benq'],{'count':0,'failed_attempts':1,'seconds':{}})
            self.assertEqual(report['pg']['seconds']['total']['count'],4)
            self.assertEqual(report['pg']['seconds']['audio']['count'],1)
            self.assertEqual(report['pg']['seconds']['total']['p95'],4)

    def test_recent_transitions_are_bounded_ordered_and_allowlisted(self):
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp)
            for n in range(12):o.record(root,{'profile':'pg','result':'ready','seconds':{'total':n,'audio':True,'private':12},'error':'private text','inputs':{'pg':17}})
            o.record(root,{'profile':'benq','result':'failed','attempt':2,'error':'private error'})
            o.record(root,{'profile':'unknown','result':'ready'})
            recent=o.summary(root)['recent_events']
            self.assertEqual(len(recent),10)
            self.assertEqual(recent[0],{'profile':'benq','result':'failed','seconds':{},'attempt':2})
            self.assertEqual(recent[1],{'profile':'pg','result':'ready','seconds':{'total':11}})
            self.assertNotIn('private',json.dumps(recent))
            self.assertNotIn('inputs',json.dumps(recent))
            self.assertEqual(o.summary(root)['recent_events'],recent)

    def test_bad_duration_does_not_hide_other_events_or_valid_phases(self):
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp);path=root/'transitions.json'
            for invalid in (10**400,-1,True,'slow',None,float('inf'),float('nan')):
                path.write_text(json.dumps([
                    {'profile':'pg','result':'ready','seconds':{'total':2}},
                    {'profile':'pg','result':'ready','seconds':{'total':invalid,'audio':1.2}}]))
                original=path.read_bytes();report=o.summary(root)
                self.assertEqual(report['profiles']['pg']['seconds']['total']['count'],1)
                self.assertEqual(report['profiles']['pg']['seconds']['total']['median'],2)
                self.assertEqual(report['profiles']['pg']['seconds']['audio']['median'],1.2)
                self.assertEqual(report['recent_events'][0]['seconds'],{'audio':1.2})
                self.assertEqual(path.read_bytes(),original)

    def test_finite_large_samples_do_not_overflow_median(self):
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp)
            (root/'transitions.json').write_text(json.dumps([
                {'profile':'pg','result':'ready','seconds':{'total':1e308}},
                {'profile':'pg','result':'ready','seconds':{'total':1e308}}]))
            report=o.summary(root)
            self.assertEqual(report['profiles']['pg']['seconds']['total']['median'],1e308)
            json.dumps(report,allow_nan=False)

    def test_diagnostics_are_local_private_and_tolerate_missing_files(self):
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp);path=o.diagnostics(root,root)
            self.assertEqual(path.stat().st_mode&0o777,0o600)
            self.assertIn('helper_sha256',json.loads(path.read_text()))
    def test_preferences_control_validated_and_persisted(self):
        with tempfile.TemporaryDirectory() as temp,patch.object(c,'ROOT',Path(temp)),patch.object(c,'CONTROL',Path(temp)/'control.json'),patch('builtins.print'):
            c.control_command('speaker',30,'extended','benq')
            self.assertEqual(c.read_control()['speaker_preferences'],{'extended':'benq'})
            with self.assertRaises(RuntimeError):c.control_command('speaker',30,'away','invalid')
if __name__=='__main__':unittest.main()
