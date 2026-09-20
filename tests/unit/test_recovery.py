import importlib.util
import itertools
import json
from pathlib import Path
from unittest.mock import patch
import unittest

spec=importlib.util.spec_from_file_location('controller',(Path(__file__).resolve().parents[2]/'display-auto.py'))
c=importlib.util.module_from_spec(spec);spec.loader.exec_module(c)
class Finished(Exception): pass
class RegressionTests(unittest.TestCase):
    def setUp(self):
        for name,value in [('verify_setup',lambda *a:None),('record',lambda *a:None),('new_recovery',lambda:c.Recovery()),('read_control',lambda:{}),('audio_inventory',lambda cfg:[]),('confirm_inputs',lambda *a:None)]:
            patcher=patch.object(c,name,value);patcher.start();self.addCleanup(patcher.stop)

    def test_slow_success_does_not_trigger_another_refresh(self):
        clock=[100.0];reads=[0];refreshes=[]
        def read(*args):
            reads[0]+=1
            if reads[0]==5:raise Finished()
            return {'pg':17,'benq':19}
        def sync(*args,**kw):refreshes.append(kw['refresh']);clock[0]+=8
        def sleep(*args):clock[0]+=.25
        with patch.object(c,'write_health'),patch.object(c,'read_inputs',side_effect=read),patch.object(c,'apply',return_value=False),patch.object(c,'sync_audio',side_effect=sync),patch.object(c.time,'time',side_effect=lambda:clock[0]),patch.object(c.time,'monotonic',side_effect=lambda:clock[0]),patch.object(c.time,'sleep',side_effect=sleep):
            with self.assertRaises(Finished):c.watch({'host':'A','poll_interval':.25})
        self.assertEqual(refreshes,[True])
    def test_watch_retries_new_orientation_after_exhaustion(self):
        work=c.Recovery();work.select({'pg':17,'benq':19},'extended',0)
        for i in range(3):work.failed('old rotation failed',i)
        with patch.object(c,'new_recovery',return_value=work),patch.object(c,'read_inputs',return_value={'pg':17,'benq':19}),patch.object(c,'read_rotation',return_value=90),patch.object(c,'apply_rotation',return_value=True) as rotate,patch.object(c,'apply',return_value=False),patch.object(c,'sync_audio') as audio,patch.object(c,'write_health'),patch.object(c.time,'sleep'):
            c.watch({'host':'A','poll_interval':0,'rotation':{'enabled':True}},once=True)
        rotate.assert_called_once();audio.assert_called_once()
        self.assertFalse(work.pending)
    def test_failed_refresh_is_not_forgotten_when_layout_matches(self):
        config={'host':'A','poll_interval':0,'audio':{'enabled':True,'pg':'p','benq':'b','fallback':'i','refresh_on_transition':['pg','benq']}}
        devices=[dict(uid=x,name=x,alive=True,default=x=='p',system=x=='p') for x in ['p','b','i']]
        attempts=[]
        def command(args,*a,**kw):
            if 'refresh' in args:
                attempts.append(args)
                if len(attempts)==1: raise RuntimeError('injected stream failure')
                return json.dumps({'original_rate':48000})
            return json.dumps(devices)
        def health(config,status,*a,**kw):
            if status=='ready':raise Finished()
        with patch.object(c,'read_inputs',return_value={'pg':17,'benq':19}),patch.object(c,'apply',side_effect=[True,False]),patch.object(c,'command',side_effect=command),patch.object(c,'write_health',side_effect=health),patch.object(c.time,'monotonic',side_effect=itertools.count()),patch.object(c.time,'sleep'):
            with self.assertRaises(Finished):c.watch(config)
        self.assertEqual(len(attempts),2,'failed audio refresh was skipped by the next successful layout check')
    def test_three_failures_remain_degraded_without_false_ready(self):
        statuses=[]
        def health(config,status,*a,**kw):
            statuses.append(status)
            if status=='degraded':raise Finished()
        with patch.object(c,'read_inputs',return_value={'pg':17,'benq':19}),patch.object(c,'apply',return_value=False),patch.object(c,'sync_audio',side_effect=RuntimeError('broken')) as sync,patch.object(c,'write_health',side_effect=health),patch.object(c.time,'monotonic',side_effect=itertools.count()),patch.object(c.time,'sleep'):
            with self.assertRaises(Finished):c.watch({'host':'A','poll_interval':0})
        self.assertEqual(sync.call_count,3);self.assertNotIn('ready',statuses)
    def test_pause_does_not_read_or_change_hardware(self):
        with patch.object(c,'read_control',return_value={'paused':True}),patch.object(c,'write_health'),patch.object(c,'read_inputs') as read,patch.object(c,'apply') as apply:
            with self.assertRaisesRegex(RuntimeError,'paused'):c.watch({'host':'A'},once=True)
        read.assert_not_called();apply.assert_not_called()
    def test_manual_audio_override_preserves_selection(self):
        with patch.object(c,'read_control',return_value={'audio_manual_until':c.time.time()+60}),patch.object(c,'write_health'),patch.object(c,'read_inputs',return_value={'pg':17,'benq':19}),patch.object(c,'apply',return_value=True),patch.object(c,'sync_audio') as sync:
            c.watch({'host':'A','poll_interval':0},once=True)
        sync.assert_not_called()
    def test_obsolete_input_transition_does_not_route_audio(self):
        with patch.object(c,'write_health'),patch.object(c,'read_inputs',return_value={'pg':17,'benq':19}),patch.object(c,'apply',return_value=False) as apply,patch.object(c,'confirm_inputs',side_effect=[c.InputsChanged(),None,None]),patch.object(c,'sync_audio',side_effect=Finished) as sync:
            with self.assertRaises(Finished):c.watch({'host':'A','poll_interval':0})
        self.assertEqual(apply.call_count,1);self.assertEqual(sync.call_count,1)

    def test_slow_failures_do_not_reset_the_retry_budget(self):
        attempts=[]
        def health(config,status,*a,**kw):
            if status in ('recovering','degraded') and 'audio_journal_pending' not in kw and kw.get('recovery',{}).get('error'):
                attempt=kw['recovery']['attempts']
                if not attempts or len(attempts)<3:
                    attempts.append(attempt)
                if len(attempts)==3:raise Finished()
        with patch.object(c,'read_inputs',return_value={'pg':17,'benq':19}),patch.object(c,'apply',return_value=False),patch.object(c,'sync_audio',side_effect=RuntimeError('slow failure')),patch.object(c,'write_health',side_effect=health),patch.object(c.time,'monotonic',side_effect=itertools.count(0,10)),patch.object(c.time,'time',side_effect=[0,0,1,8,9,16,17,24,25]),patch.object(c.time,'sleep'):
            with self.assertRaises(Finished):c.watch({'host':'A','poll_interval':0})
        self.assertEqual(attempts,[1,2,3])

    def test_ddc_recovery_rearms_exhausted_pending_work(self):
        work=c.Recovery();work.select({'pg':17,'benq':19},'extended')
        for i in range(3):work.failed('offline',i)
        with patch.object(c,'new_recovery',return_value=work),patch.object(c,'write_health'),patch.object(c,'read_inputs',side_effect=[RuntimeError('DDC offline'),{'pg':17,'benq':19},{'pg':17,'benq':19}]),patch.object(c,'apply',return_value=False),patch.object(c,'sync_audio',side_effect=Finished):
            with self.assertRaises(Finished):c.watch({'host':'A','poll_interval':0})
        self.assertFalse(work.exhausted)

class StateTests(unittest.TestCase):
    def test_new_orientation_rearms_exhausted_recovery_but_missing_sensor_does_not(self):
        r=c.Recovery();inputs={'pg':17,'benq':19}
        r.select(inputs,'extended',0)
        for i in range(3):r.failed('rotation unavailable',i)
        self.assertTrue(r.exhausted)
        self.assertFalse(r.select(inputs,'extended',None))
        self.assertFalse(r.select(inputs,'extended',0))
        self.assertTrue(r.exhausted)
        self.assertTrue(r.select(inputs,'extended',90))
        self.assertFalse(r.exhausted)
        self.assertEqual(r.data['reason'],'orientation changed')
    def test_pending_survives_restart_and_attempts_are_bounded(self):
        import tempfile
        with tempfile.TemporaryDirectory() as temp:
            path=Path(temp)/'work.json';r=c.Recovery(path)
            r.select({'pg':17,'benq':19},'extended');r.failed('offline',10)
            r=c.Recovery(path);self.assertTrue(r.pending)
            r.failed('offline',20);r.failed('offline',30)
            self.assertTrue(r.exhausted);self.assertFalse(r.eligible(1000))
            r.request('device returned');self.assertTrue(r.eligible(1000))
            r.complete();self.assertFalse(c.Recovery(path).pending)
    def test_new_inputs_supersede_old_pending_work(self):
        r=c.Recovery();r.select({'pg':17,'benq':19},'extended');r.failed('old target',0)
        r.select({'pg':18,'benq':19},'benq')
        self.assertEqual(r.data['profile'],'benq');self.assertEqual(r.data['attempts'],0)
    def test_unknown_input_cancels_old_transition(self):
        r=c.Recovery();r.select({'pg':17,'benq':19},'extended')
        r.select({'pg':0,'benq':19},'unknown');self.assertFalse(r.pending)

class WakeTests(unittest.TestCase):
    def test_unchanged_layout_after_gap_still_refreshes_audio(self):
        from types import SimpleNamespace

        clock = [100.0]
        sleeps = [0]
        refreshes = []

        def sync(*args, **kwargs):
            refreshes.append(kwargs['refresh'])
            if len(refreshes) == 2:
                raise Finished()

        def sleep(_):
            sleeps[0] += 1
            if sleeps[0] > 6:
                self.fail('Audio was not refreshed after the polling gap')
            # First establish a stable profile, then simulate a suspended poller.
            clock[0] += 10 if sleeps[0] == 2 else 1

        fake_time = SimpleNamespace(
            time=lambda: clock[0], monotonic=lambda: clock[0], sleep=sleep
        )
        with (
            patch.object(c, 'record'),
            patch.object(c, 'confirm_inputs'),
            patch.object(c, 'new_recovery', side_effect=lambda: c.Recovery()),
            patch.object(c, 'read_control', return_value={}),
            patch.object(c, 'audio_inventory', return_value=[]),
            patch.object(c, 'write_health'),
            patch.object(c, 'read_inputs', return_value={'pg': 17, 'benq': 19}),
            patch.object(c, 'apply', return_value=False),
            patch.object(c, 'sync_audio', side_effect=sync),
            patch.object(c, 'time', fake_time),
        ):
            with self.assertRaises(Finished):
                c.watch({'host': 'A', 'poll_interval': 1})
        self.assertEqual(refreshes, [True, True])

class ControlTests(unittest.TestCase):
    def test_controls_are_persistent_and_reversible(self):
        import tempfile
        with tempfile.TemporaryDirectory() as temp,patch.object(c,'ROOT',Path(temp)),patch.object(c,'CONTROL',Path(temp)/'control.json'),patch('builtins.print'):
            c.control_command('pause',30);self.assertTrue(c.read_control()['paused'])
            c.control_command('audio-manual',30);self.assertGreater(c.read_control()['audio_manual_until'],c.time.time())
            with self.assertRaises(RuntimeError):c.control_command('repair-audio',30)
            c.control_command('resume',30)
            with self.assertRaises(RuntimeError):c.control_command('repair-audio',30)
            c.control_command('audio-auto',30)
            c.control_command('repair-audio',30);first=c.read_control()['repair_token']
            c.control_command('repair-audio',30);self.assertNotEqual(first,c.read_control()['repair_token'])
            c.control_command('resume',30);self.assertFalse(c.read_control()['paused'])
            c.control_command('audio-auto',30);self.assertEqual(c.read_control()['audio_manual_until'],0)

if __name__=='__main__':unittest.main()
