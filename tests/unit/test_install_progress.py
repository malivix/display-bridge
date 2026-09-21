import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

from install_progress import InstallProgress, read_progress


class InstallProgressTests(unittest.TestCase):
    def test_completed_attempt_and_permissions(self):
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp)
            with InstallProgress(root,'A') as progress:
                progress.phase('building')
                running=read_progress(root,'A')
                self.assertEqual(running['status'],'running')
                self.assertEqual(running['process_observation'],'present')
                progress.succeed()
            report=read_progress(root,'A')
            self.assertEqual(report['status'],'completed')
            self.assertEqual(report['phase'],'finished')
            self.assertNotIn('process_observation',report)
            self.assertEqual(progress.path.stat().st_mode & 0o777,0o600)
            self.assertEqual(list(root.iterdir()),[progress.path])
            self.assertNotIn(str(root),json.dumps(report))

    def test_failure_and_recovery_are_not_reported_as_success(self):
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp)
            error=subprocess.TimeoutExpired('private command',10)
            with self.assertRaises(subprocess.TimeoutExpired):
                with InstallProgress(root,'B') as progress:
                    progress.phase('recovering',recovery='pending')
                    progress.phase('recovery-finished',recovery='completed-unverified')
                    raise error
            report=read_progress(root,'B')
            self.assertEqual(report['status'],'failed')
            self.assertEqual(report['recovery'],'completed-unverified')
            self.assertEqual(report['reason'],'command-timeout')
            self.assertNotIn('private command',json.dumps(report))
            with InstallProgress(root,'B'):pass
            self.assertEqual(read_progress(root,'B')['status'],'incomplete')

    def test_write_failure_cannot_mask_original_recovery_error(self):
        class ClosedErrorStream:
            def write(self,value):raise ValueError('closed')
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp);failure=RuntimeError('original recovery failure')
            create=tempfile.NamedTemporaryFile;calls=[]
            def storage(*args,**kwargs):
                calls.append(True)
                if len(calls)>1:raise OSError('disk full')
                return create(*args,**kwargs)
            with patch('install_progress.tempfile.NamedTemporaryFile',side_effect=storage),patch('install_progress.sys.stderr',new=ClosedErrorStream()):
                with self.assertRaises(RuntimeError) as caught:
                    with InstallProgress(root,'A') as progress:
                        progress.phase('recovering',recovery='pending')
                        raise failure
            self.assertIs(caught.exception,failure)
            self.assertEqual(progress.data['status'],'failed')
            # Failed writes leave the old observation; they cannot fabricate a final outcome.
            self.assertEqual(read_progress(root,'A')['status'],'running')
            self.assertEqual(list(root.iterdir()),[progress.path])

    def test_initial_failure_and_symlink_do_not_replace_target(self):
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp);target=root/'original';target.write_text('preserve')
            (root/'install-progress.json').symlink_to(target)
            with self.assertRaises(OSError):
                with InstallProgress(root,'A'):self.fail('Must not enter installation')
            self.assertEqual(target.read_text(),'preserve')
            self.assertFalse(read_progress(root,'A')['available'])

    def test_reader_rejects_bad_data_and_does_not_mutate(self):
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp)
            self.assertFalse(read_progress(root,'A')['available'])
            self.assertEqual(list(root.iterdir()),[])
            with InstallProgress(root,'A') as progress:progress.succeed()
            original=json.loads(progress.path.read_text())
            for key,value in [('pid',True),('pid',10**400),('updated_at',float('nan')),('updated_at',10**400),('updated_at',True),('host','B'),('phase','unknown'),('phase','building'),('status','unknown'),('attempt','invalid')]:
                data=dict(original);data[key]=value;raw=json.dumps(data);progress.path.write_text(raw)
                with self.subTest(key=key,value=str(value)[:20]):
                    self.assertFalse(read_progress(root,'A')['available'])
                    self.assertEqual(progress.path.read_text(),raw)
            progress.path.write_text('['*2000+']'*2000)
            self.assertFalse(read_progress(root,'A')['available'])
            original['unexpected']='private value';progress.path.write_text(json.dumps(original))
            self.assertNotIn('unexpected',read_progress(root,'A'))

    def test_missing_process_does_not_invent_terminal_outcome(self):
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp)
            progress=InstallProgress(root,'A');progress.__enter__()
            with patch('install_progress.os.kill',side_effect=ProcessLookupError):
                report=read_progress(root,'A')
            self.assertEqual(report['status'],'running')
            self.assertEqual(report['process_observation'],'not-found')
