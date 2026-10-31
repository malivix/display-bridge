import importlib.util
import json
import os
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch
spec = importlib.util.spec_from_file_location('controller', (Path(__file__).resolve().parents[2]/'display-auto.py'))
c = importlib.util.module_from_spec(spec)
spec.loader.exec_module(c)

# A synthetic `display-ddc serve`: answers by command, can stall, exit or reply garbage.
FAKE = r'''
import json, os, sys, time
log = os.environ['FAKE_DDC_LOG']
with open(log, 'a') as f: f.write('start\n')
for line in sys.stdin:
    args = line.split()
    if args == ['display', 'keys']: reply = {'status': 0, 'stdout': 'p\nb\n', 'stderr': ''}
    elif args[-2:] == ['get', 'input']: reply = {'status': 0, 'stdout': '17\n', 'stderr': ''}
    elif args == ['fail']: reply = {'status': 1, 'stdout': '', 'stderr': 'No valid matching DDC reply after three attempts\n'}
    elif args == ['stall']: time.sleep(5); continue
    elif args == ['exit']: sys.exit(0)
    elif args == ['garbage']: sys.stdout.write('not json\n'); sys.stdout.flush(); continue
    else: reply = {'status': 1, 'stdout': 'Invalid command!\n', 'stderr': ''}
    sys.stdout.write(json.dumps(reply) + '\n'); sys.stdout.flush()
'''

class ReaderTests(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory(); self.addCleanup(temp.cleanup)
        self.log = Path(temp.name) / 'starts'
        script = Path(temp.name) / 'display-ddc'
        script.write_text(f'#!{sys.executable}\n' + FAKE)
        script.chmod(0o755)
        patcher = patch.dict(os.environ, FAKE_DDC_LOG=str(self.log)); patcher.start(); self.addCleanup(patcher.stop)
        self.reader = c.DDCServer(script); self.addCleanup(self.reader.close)

    def starts(self):
        return self.log.read_text().count('start') if self.log.exists() else 0

    def test_one_process_answers_many_reads(self):
        for _ in range(20):
            self.assertEqual(self.reader.run(['display', 'uuid=X', 'get', 'input'], 2), '17')
            self.assertEqual(self.reader.run(['display', 'keys'], 2).split(), ['p', 'b'])
        self.assertEqual(self.starts(), 1)

    def test_failures_report_like_the_cli_and_keep_the_reader(self):
        with self.assertRaisesRegex(RuntimeError, 'display-ddc: No valid matching DDC reply'):
            self.reader.run(['fail'], 2)
        with self.assertRaisesRegex(RuntimeError, 'display-ddc: Invalid command'):
            self.reader.run(['bogus'], 2)
        self.assertEqual(self.reader.run(['display', 'keys'], 2), 'p\nb')
        self.assertEqual(self.starts(), 1)

    def test_a_stalled_reader_is_killed_and_replaced(self):
        with self.assertRaises(c.subprocess.TimeoutExpired):
            self.reader.run(['stall'], .3)
        self.assertIsNone(self.reader.process)
        self.assertEqual(self.reader.run(['display', 'keys'], 2), 'p\nb')
        self.assertEqual(self.starts(), 2)

    def test_an_exited_or_garbled_reader_is_replaced(self):
        for request, error in ((['exit'], 'reader unavailable'), (['garbage'], 'invalid reader reply')):
            with self.subTest(request=request):
                with self.assertRaisesRegex(RuntimeError, error):
                    self.reader.run(request, 2)
                self.assertIsNone(self.reader.process)
                self.assertEqual(self.reader.run(['display', 'keys'], 2), 'p\nb')

    def test_reader_is_recycled_periodically(self):
        self.reader.run(['display', 'keys'], 2)
        self.reader.started -= c.DDCServer.RECYCLE_SECONDS
        self.reader.run(['display', 'keys'], 2)
        self.assertEqual(self.starts(), 2)

    def test_requests_cannot_smuggle_extra_arguments(self):
        for args in ([], ['display', 'uuid=X get input'], ['display', ''], ['a\nfail']):
            with self.subTest(args=args), self.assertRaises(ValueError):
                self.reader.run(args, 2)
        self.assertEqual(self.starts(), 0)

    def test_close_is_idempotent(self):
        self.reader.run(['display', 'keys'], 2)
        self.reader.close(); self.reader.close()
        self.assertIsNone(self.reader.process)

class RoutingTests(unittest.TestCase):
    def test_reads_use_the_reader_only_while_watching(self):
        config = {'m1ddc': '/x/display-ddc'}
        with patch.object(c, 'command', return_value='17') as command:
            self.assertEqual(c.ddc(config, ['display', 'u', 'get', 'input'], 3), '17')
            command.assert_called_once_with(['/x/display-ddc', 'display', 'u', 'get', 'input'], 3, None)
        class Reader:
            def run(self, args, timeout): return 'from-reader'
        with patch.object(c, 'DDC_READER', Reader()), patch.object(c, 'command') as command:
            self.assertEqual(c.ddc(config, ['display', 'keys']), 'from-reader')
            command.assert_not_called()

    def test_daemon_watch_owns_and_closes_one_reader(self):
        seen = []
        class Finished(Exception): pass
        def loop(config, once, interrupt):
            seen.append(c.DDC_READER); raise Finished
        with patch.object(c, 'watch_loop', side_effect=loop), patch.object(c.DDCServer, 'close') as close:
            with self.assertRaises(Finished): c.watch({'host': 'A', 'm1ddc': '/x/display-ddc'})
            close.assert_called_once()
        self.assertIsInstance(seen[0], c.DDCServer)
        self.assertIsNone(c.DDC_READER)
        with patch.object(c, 'watch_loop', side_effect=loop):
            with self.assertRaises(Finished): c.watch({'host': 'A', 'm1ddc': '/x'}, once=True)
        self.assertIsNone(seen[1])

class FailureHandlingTests(unittest.TestCase):
    def setUp(self):
        for name,value in [('verify_setup',lambda *a:None),('record',lambda *a:None),('new_recovery',lambda:c.Recovery()),('read_control',lambda:{}),('audio_inventory',lambda cfg:[]),('confirm_inputs',lambda *a:None),('apply_rotation',lambda *a:False)]:
            patcher=patch.object(c,name,value);patcher.start();self.addCleanup(patcher.stop)

    def test_backoff_is_bounded_below_the_wake_gap(self):
        delays=[c.ddc_failure_delay(.25,n) for n in range(1,12)]
        self.assertEqual(delays[:2],[.25,.25])
        self.assertEqual(delays,sorted(delays))
        self.assertEqual(delays[-1],c.DDC_BACKOFF_MAX)
        self.assertLess(c.DDC_BACKOFF_MAX,5)

    def run_watch(self, reads, apply_side_effect=False, polls=None):
        """Run the daemon loop over scripted reads; returns apply calls and health reports."""
        reports=[];reads=list(reads);polls=len(reads) if polls is None else polls
        count={'n':0}
        def interrupt():
            count['n']+=1;return count['n']>polls
        def read(*a):
            value=reads.pop(0)
            if isinstance(value,Exception):raise value
            return value
        with patch.object(c,'write_health',side_effect=lambda cfg,status,*a,**k:reports.append((status,k))), \
             patch.object(c,'read_inputs',side_effect=read), patch.object(c,'sync_audio',return_value={'state':'managed'}), \
             patch.object(c,'apply',side_effect=apply_side_effect) as apply, patch.object(c.time,'sleep'):
            c.watch_loop({'host':'A','poll_interval':.25},interrupt=interrupt)
        return apply,reports

    def test_one_missed_reply_does_not_reconcile_or_report_unavailable(self):
        local={'pg':17,'benq':19}
        apply,reports=self.run_watch([local,local,c.DDCReadFailed('benq: no reply'),local,local],apply_side_effect=lambda *a:False)
        self.assertEqual(apply.call_count,1)
        self.assertNotIn('waiting-for-ddc',[status for status,_ in reports])

    def test_sustained_failure_reports_unavailable_and_reverifies_after(self):
        local={'pg':17,'benq':19}
        failures=[c.DDCReadFailed('benq: no reply')]*c.TRANSIENT_DDC_FAILURES
        apply,reports=self.run_watch([local,local,*failures,local,local],apply_side_effect=lambda *a:False)
        self.assertIn('waiting-for-ddc',[status for status,_ in reports])
        self.assertEqual(apply.call_count,2)

    def test_unanswered_confirmation_does_not_spend_the_retry_budget(self):
        work=c.Recovery()
        local={'pg':17,'benq':19}
        with patch.object(c,'new_recovery',return_value=work), \
             patch.object(c,'confirm_inputs',side_effect=c.DDCReadFailed('benq: no reply')) as confirm:
            apply,reports=self.run_watch([local]*12)
        self.assertEqual(work.data.get('attempts',0),0)
        self.assertFalse(work.exhausted)
        self.assertNotIn('degraded',[status for status,_ in reports])
        self.assertGreaterEqual(confirm.call_count,3)  # Retried as settling, never given up.
        apply.assert_not_called()

    def test_sleeping_display_defers_without_retrying_every_poll(self):
        local={'pg':17,'benq':19};remote={'pg':18,'benq':19}
        work=c.Recovery()
        deferred=c.LayoutDeferred('Layout differs but a display is asleep; changes deferred until it wakes')
        with patch.object(c,'new_recovery',return_value=work):
            apply,reports=self.run_watch([local]*10,apply_side_effect=deferred)
        self.assertEqual(apply.call_count,1)
        self.assertEqual(work.data.get('attempts',0),0)
        status,details=[r for r in reports if r[1].get('layout')=='deferred-display-asleep'][-1]
        self.assertEqual(status,'waiting-for-ddc')
        # A new input state is retried at once.
        with patch.object(c,'new_recovery',return_value=c.Recovery()):
            apply,_=self.run_watch([local,local,remote,remote],apply_side_effect=deferred)
        self.assertEqual(apply.call_count,2)

    def test_helper_deferral_is_not_reported_as_success(self):
        base=[dict(key=k,width=100,height=80,pixelWidth=200,pixelHeight=160,hz=120,rotation=0,x=x,y=0) for k,x in [('p',0),('b',100)]]
        config={'keys':{'pg':'p','benq':'b'},'baseline':{'screens':base}}
        with tempfile.TemporaryDirectory() as temp,patch.object(c,'ROOT',Path(temp)), \
             patch.object(c,'layout',return_value=[]), \
             patch.object(c,'command',return_value=json.dumps({'changed':False,'deferred':'asleep'})) as command:
            with self.assertRaisesRegex(c.LayoutDeferred,'asleep'):c.apply(config,'extended')
            self.assertEqual(command.call_args.args[1],c.APPLY_TIMEOUT)
