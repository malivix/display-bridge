import fcntl,json,tempfile,time,unittest
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch
from preview_service import Service,enqueue,unresolved,mutation_guard
import test_preview_hardware as fixtures
import test_controller as controller_fixture


class ServiceTests(unittest.TestCase):
    def setUp(self):
        fixture=fixtures.AdapterTests();fixture.setUp();self.fixture=fixture;self.c=fixture.c
        self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup)
        self.root=Path(self.temp.name);self.c.ROOT=self.root;self.c.JOURNAL=self.root/'audio-refresh.json'
        for name,data in fixture.files.items():(self.root/name).write_bytes(data)
        self.events=[];self.health=[]
        self.c.acquire_lock=lambda f,t:fcntl.flock(f,fcntl.LOCK_EX|fcntl.LOCK_NB)
        self.c.startup_config=lambda:fixture.config
        self.c.automation_paused=lambda control:False;self.c.read_control=lambda:{}
        self.recovery=SimpleNamespace(data={'pending':False},request=self.events.append)
        self.c.new_recovery=lambda:self.recovery
        self.c.write_health=lambda cfg,status,**kw:self.health.append((status,kw))
        self.service=Service(self.c)
    def start(self):
        enqueue(self.c,'start','current')
        self.assertEqual(self.service.step(),'preview', self.health)
        return self.service.journal.read()['token']
    def check_physical_match_preview(self, reference_role, percent=100):
        from preview_service import options
        target=0 if reference_role=='benq' else 1
        display=self.fixture.public[target]
        reference=max(self.fixture.public[1-target]['current'][f] for f in ('width','height'))
        width=round(reference*1.54*100/percent/16)*16 if target==0 else round(reference/1.54*100/percent/3)*3
        height=width*9//16 if target==0 else width*2//3
        display['modes'].append(dict(display['modes'][0],modeID=3,width=width,height=height,pixelWidth=2*width,pixelHeight=2*height))
        self.fixture.metadata['displays'][target]['modes'].append({'modeID':3,'variableRefresh':False,'proMotion':False})
        original_command=self.c.command
        def applied_readback(args,*extra):
            result=original_command(args,*extra)
            if args[1]=='apply':
                self.fixture.screens=json.loads(Path(args[2]).read_text())['screens']
                for index,screen in enumerate(self.fixture.screens):
                    self.fixture.public[index]['current']=screen
                    self.fixture.metadata['displays'][index].update(screen)
            return result
        self.c.command=applied_readback
        key='match-'+reference_role+('' if percent==100 else '-larger' if percent>100 else '-smaller')
        option=next(row for row in options(self.c)['options'] if row['size']==key)
        ratio=option['physical_size_percent'] if reference_role=='benq' else 10000/option['physical_size_percent']
        self.assertLess(abs(ratio-percent),5)
        enqueue(self.c,'start',key,fingerprint=option['fingerprint'])
        self.assertEqual(self.service.step(),'preview',self.health)
        self.assertEqual(Service(self.c).step(),'reverted')

    def test_physical_match_uses_fingerprint_and_existing_rollback(self):
        self.check_physical_match_preview('benq')

    def test_reverse_match_uses_existing_preview_and_rollback(self):
        self.check_physical_match_preview('pg')

    def test_larger_pg_relative_preview_reverts_after_restart(self):
        self.check_physical_match_preview('benq',110)

    def test_smaller_benq_relative_preview_reverts_after_restart(self):
        self.check_physical_match_preview('pg',90)

    def test_duration_options_reach_journal_and_restart_restores(self):
        from preview_service import options
        self.assertEqual(options(self.c)['preview_seconds'],[20,40])
        enqueue(self.c,'start','current',preview_seconds=40)
        self.assertEqual(self.service.step(),'preview',self.health)
        record=self.service.journal.read()
        self.assertEqual(record['preview_seconds'],40)
        self.assertAlmostEqual(record['keep_until']-record['verified_at'],40)
        self.assertEqual(Service(self.c).step(),'reverted')

    def test_invalid_duration_is_rejected_before_request_or_hardware(self):
        for duration in (True,60,'40',None):
            with self.assertRaises(ValueError):enqueue(self.c,'start','current',preview_seconds=duration)
            self.assertFalse((self.root/'preview-request.json').exists())
            with patch.object(self.c,'startup_config',side_effect=AssertionError('No hardware preparation')):
                with self.assertRaises(ValueError):self.service.start({'preview_seconds':duration})
        with self.assertRaises(ValueError):enqueue(self.c,'keep',token='example',preview_seconds=40)

    def test_named_preset_uses_existing_preview_and_restart_rollback(self):
        from preview_service import save_preset,options
        saved=save_preset(self.c,'Reading')
        self.assertTrue(saved['saved'])
        choice=options(self.c)['presets'][0]
        self.assertTrue(choice['available'])
        enqueue(self.c,'start',preset='Reading',fingerprint=choice['fingerprint'])
        self.assertEqual(self.service.step(),'preview',self.health)
        self.assertEqual(Service(self.c).step(),'reverted')
        self.assertTrue((self.root/'size-presets.json').exists())

    def test_damaged_presets_do_not_block_relative_preview(self):
        from preview_service import options
        path=self.root/'size-presets.json'
        for content in (b'{broken',b'\xff\xfe',b'{}'):
            path.write_bytes(content)
            report=options(self.c)
            self.assertTrue(report['options'])
            self.assertEqual(report['presets'],[])
            self.assertIn('preserved',report['preset_error'])
            self.assertEqual(path.read_bytes(),content)
        enqueue(self.c,'start','current')
        self.assertEqual(self.service.step(),'preview')

    def test_unreadable_store_does_not_hide_hardware_inspection_failure(self):
        from preview_service import options
        with patch('size_presets.read',side_effect=PermissionError('denied')):
            self.assertIn('preset_error',options(self.c))
        self.fixture.inputs={'pg':18,'benq':19}
        with self.assertRaisesRegex(RuntimeError,'both monitors'):options(self.c)

    def test_removal_respects_preview_guard_and_never_calls_hardware(self):
        from preview_service import save_preset,remove_preset,options
        save_preset(self.c,'Reading');revision=options(self.c)['presets'][0]['revision']
        self.start()
        with self.assertRaisesRegex(RuntimeError,'Finish or revert'):remove_preset(self.c,'Reading',0,revision)
        self.assertEqual(Service(self.c).step(),'reverted')
        self.c.command=lambda *args:(_ for _ in ()).throw(AssertionError('Removal must not call hardware'))
        result=remove_preset(self.c,'Reading',0,revision)
        self.assertTrue(result['removed'])
        self.assertEqual(json.loads((self.root/'size-presets.json').read_text())['presets'],[])

    def test_preset_writer_lock_prevents_concurrent_save(self):
        from preview_service import save_preset
        with (self.root/'size-presets.lock').open('a') as lock:
            fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
            with self.assertRaises(BlockingIOError):save_preset(self.c,'Reading')
        self.assertFalse((self.root/'size-presets.json').exists())

    def test_preset_stale_fingerprint_rejects_before_hardware_write(self):
        from preview_service import save_preset
        save_preset(self.c,'Reading')
        enqueue(self.c,'start',preset='Reading',fingerprint='stale')
        self.assertEqual(self.service.step(),'request-rejected')
        self.assertEqual(self.fixture.writes,[])

    def test_preset_save_is_blocked_during_preview_and_conflicting_request_rejected(self):
        from preview_service import save_preset
        with self.assertRaisesRegex(ValueError,'not both'):enqueue(self.c,'start',size='current',preset='Reading')
        self.start()
        with self.assertRaisesRegex(RuntimeError,'Finish or revert'):save_preset(self.c,'Reading')
        self.assertFalse((self.root/'size-presets.json').exists())

    def test_preview_lifetime_accepts_fractional_clock_across_float_boundary(self):
        with patch('preview_service.time.monotonic', return_value=200.1):
            self.start()

    def test_queue_to_apply_keep_and_audio_recheck(self):
        token=self.start();self.assertTrue(unresolved(self.root))
        enqueue(self.c,'keep',token=token)
        self.assertEqual(self.service.step(),'kept')
        self.assertFalse(unresolved(self.root));self.assertEqual(len(self.events),1)
        self.assertTrue(self.service.journal.read()['recovery_queued'])
    def test_startup_pending_preview_restores_before_config_loader(self):
        self.start();self.c.startup_config=lambda:(_ for _ in ()).throw(AssertionError('Do not read partially committed config'))
        restarted=Service(self.c)
        self.assertEqual(restarted.step(),'reverted')
        self.assertFalse(unresolved(self.root))
    def test_malformed_request_does_not_block_timeout(self):
        self.start();(self.root/'preview-request.json').write_text('{broken')
        self.service.runner.clock=lambda:time.monotonic()+30
        self.assertEqual(self.service.step(),'reverted')
        self.assertEqual(len(list(self.root.glob('preview-request.rejected-*.json'))),1)
    def test_huge_request_timestamp_cannot_block_preview_restoration(self):
        self.start()
        (self.root/'preview-request.json').write_text(json.dumps({'action':'keep','created_at':10**1000}))
        self.service.runner.clock=lambda:time.monotonic()+30
        self.assertEqual(self.service.step(),'reverted')
        self.assertFalse(unresolved(self.root))

    def test_install_lock_rejects_requests(self):
        with (self.root/'install.lock').open('a') as lock:
            fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
            with self.assertRaisesRegex(RuntimeError,'Installation'):enqueue(self.c,'start','current')
    def test_pending_preview_blocks_other_mutations(self):
        self.start()
        with self.assertRaisesRegex(RuntimeError,'Finish or revert'):
            with mutation_guard(self.c):self.fail('Mutation allowed')
    def test_invalid_journal_preserved_and_deletion_does_not_clear_error(self):
        self.service.journal.path.write_text('{broken')
        self.assertEqual(self.service.step(),'error')
        self.assertEqual(self.service.journal.path.read_text(),'{broken')
        self.service.journal.path.unlink()
        self.assertTrue(self.service.pending());self.assertEqual(self.service.step(),'error')
        self.assertEqual(self.fixture.writes,[])
    def test_completion_requeues_audio_after_interruption(self):
        token=self.start();record=self.service.journal.read();record['phase']='reverted';record['recovery_queued']=False;self.service.journal.write(record)
        self.assertTrue(Service(self.c).pending())
        self.assertEqual(Service(self.c).step(),'idle')
        self.assertEqual(len(self.events),1);self.assertFalse(unresolved(self.root))
    def test_normal_watch_yields_before_any_hardware_work(self):
        c=controller_fixture.c
        with patch.object(c,'new_recovery',return_value=c.Recovery()),patch.object(c,'write_health'),patch.object(c,'read_inputs') as inputs,patch.object(c,'apply') as apply:
            c.watch({'host':'A','poll_interval':.25},interrupt=lambda:True)
            inputs.assert_not_called();apply.assert_not_called()
    def test_changed_chooser_fingerprint_does_not_apply(self):
        enqueue(self.c,'start','current',fingerprint='outdated')
        self.assertEqual(self.service.step(),'request-rejected')
        self.assertEqual(self.fixture.writes,[])
        self.assertIn('choices changed',json.loads((self.root/'preview-status.json').read_text())['error'])


if __name__=='__main__':unittest.main()
