"""Installer entry-point checks never build or touch user state."""

import importlib.util
import contextlib
import io
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]


class InstallerEntryTests(unittest.TestCase):
    def load(self):
        spec = importlib.util.spec_from_file_location("installer", ROOT / "install.py")
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        return module

    def test_import_has_no_installation_side_effects(self):
        with patch(
            "subprocess.run", side_effect=AssertionError("No subprocess during import")
        ):
            self.assertTrue(callable(self.load().main))

    def test_help_succeeds_without_writing_machine_state(self):
        with (
            tempfile.TemporaryDirectory() as directory,
            patch("pathlib.Path.home", return_value=Path(directory)),
        ):
            with patch(
                "subprocess.run", side_effect=AssertionError("No build during help")
            ):
                with (
                    contextlib.redirect_stdout(io.StringIO()),
                    contextlib.redirect_stderr(io.StringIO()),
                    self.assertRaises(SystemExit) as result,
                ):
                    self.load().main(["--help"])
            self.assertEqual(result.exception.code, 0)
            self.assertEqual(list(Path(directory).iterdir()), [])

    def test_unsupported_platform_rejected_before_changes(self):
        with (
            tempfile.TemporaryDirectory() as directory,
            patch("pathlib.Path.home", return_value=Path(directory)),
            patch("platform.system", return_value="Linux"),
        ):
            with (
                contextlib.redirect_stdout(io.StringIO()),
                contextlib.redirect_stderr(io.StringIO()),
                self.assertRaises(SystemExit) as result,
            ):
                self.load().main(["A"])
            self.assertEqual(result.exception.code, 2)
            self.assertEqual(list(Path(directory).iterdir()), [])

    def test_preflight_reports_without_creating_state_or_running_builds(self):
        import subprocess
        module=self.load()
        with tempfile.TemporaryDirectory() as directory:
            home=Path(directory);sdk=home/'sdk';sdk.mkdir()
            before=set(home.iterdir());calls=[]
            def run(args,**kwargs):
                calls.append(args)
                self.assertEqual(args[0],'/usr/bin/xcrun')
                self.assertEqual(kwargs['timeout'],10)
                output=str(sdk) if '--show-sdk-path' in args else '/usr/bin/true'
                return subprocess.CompletedProcess(args,0,output,'')
            with patch('pathlib.Path.home',return_value=home),patch('platform.system',return_value='Darwin'),patch('platform.machine',return_value='arm64'),patch('platform.mac_ver',return_value=('13.0','','')),patch.object(module,'run',side_effect=run),patch.object(module.os,'access',return_value=True),contextlib.redirect_stdout(io.StringIO()) as out:
                module.main(['A','--preflight'])
            import json
            report=json.loads(out.getvalue())
            self.assertEqual(report['status'],'prerequisites-ready')
            self.assertTrue(report['read_only'])
            self.assertEqual(report['host'],'A')
            self.assertEqual(len(calls),3)
            self.assertEqual(set(home.iterdir()),before)
            self.assertNotIn(str(home),out.getvalue())

    def test_preflight_failure_and_capture_conflict_do_not_install(self):
        module=self.load()
        with tempfile.TemporaryDirectory() as directory,patch('pathlib.Path.home',return_value=Path(directory)),patch('platform.system',return_value='Linux'),patch.object(module,'run',side_effect=AssertionError('No subprocess on unsupported platform')):
            for args,code in [(['B','--preflight'],1),(['A','--preflight','--capture-rotation'],2)]:
                with contextlib.redirect_stdout(io.StringIO()),contextlib.redirect_stderr(io.StringIO()),self.assertRaises(SystemExit) as result:
                    module.main(args)
                self.assertEqual(result.exception.code,code)
            self.assertEqual(list(Path(directory).iterdir()),[])

    def test_preflight_incomplete_source_and_tool_timeout_are_actionable(self):
        import subprocess
        module=self.load()
        with tempfile.TemporaryDirectory() as directory,patch('platform.system',return_value='Darwin'),patch('platform.machine',return_value='arm64'),patch('platform.mac_ver',return_value=('13.0','','')),patch.object(module,'run',side_effect=subprocess.TimeoutExpired('xcrun',10)):
            result=module.preflight(Path(directory),Path(directory))
            self.assertEqual(result['status'],'attention-required')
            errors={c['name'] for c in result['checks'] if c['status']=='error'}
            self.assertEqual(errors,{'Source files','Build tools'})
            self.assertEqual(list(Path(directory).iterdir()),[])

    def test_pending_or_damaged_preview_rejected_before_directory_changes(self):
        from scaling_preview import Preview
        module=self.load()
        for kind in ('request','broken-request-link','active-preview','damaged-preview'):
            with self.subTest(kind=kind),tempfile.TemporaryDirectory() as directory:
                home=Path(directory);root=home/'.config/display-auto';root.mkdir(parents=True)
                if kind=='request':(root/'preview-request.json').write_text('preserve even invalid data')
                elif kind=='broken-request-link':(root/'preview-request.json').symlink_to(root/'missing')
                elif kind=='damaged-preview':(root/'scaling-preview.json').write_text('{invalid')
                else:
                    files={'config.json':b'{}','baseline.json':b'{}'}
                    Preview(root/'scaling-preview.json').begin(files,files,{},'test',100)
                root.chmod(0o750)
                before={p.relative_to(home):p.read_bytes() for p in home.rglob('*') if p.is_file()}
                paths=set(home.rglob('*'))
                with patch('pathlib.Path.home',return_value=home),patch('platform.system',return_value='Darwin'),patch('platform.machine',return_value='arm64'),patch.object(module,'run',side_effect=AssertionError('No process before preview guard')):
                    with self.assertRaises((RuntimeError,ValueError)):
                        module.main(['A'])
                self.assertEqual(root.stat().st_mode&0o777,0o750)
                self.assertEqual(set(home.rglob('*')),paths)
                self.assertEqual({p.relative_to(home):p.read_bytes() for p in home.rglob('*') if p.is_file()},before)

    def test_request_arriving_before_install_lock_is_rechecked(self):
        module=self.load()
        with tempfile.TemporaryDirectory() as directory:
            home=Path(directory);root=home/'.config/display-auto';root.mkdir(parents=True)
            original=module.fcntl.flock
            def flock(handle,operation):
                original(handle,operation)
                (root/'preview-request.json').write_text('queued before lock acquisition')
            with patch('pathlib.Path.home',return_value=home),patch('platform.system',return_value='Darwin'),patch('platform.machine',return_value='arm64'),patch.object(module.fcntl,'flock',side_effect=flock),patch.object(module,'run',side_effect=AssertionError('No build with queued preview')):
                held_error=None
                try:module.main(['A'])
                except RuntimeError as error:held_error=error
                self.assertIsNotNone(held_error)
                self.assertIn('request is pending',str(held_error))
                # Keep the traceback alive: release cannot depend on garbage collection.
                with (root/'install.lock').open('a') as released:
                    original(released,module.fcntl.LOCK_EX | module.fcntl.LOCK_NB)
            self.assertEqual((root/'preview-request.json').read_text(),'queued before lock acquisition')

    def test_completed_preview_allows_installer_guard(self):
        from scaling_preview import Preview
        module=self.load()
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory)
            module.require_install_idle(root)
            self.assertEqual(list(root.iterdir()),[])
            files={'config.json':b'{}','baseline.json':b'{}'}
            preview=Preview(root/'scaling-preview.json')
            record=preview.begin(files,files,{},'test',100)
            record.update(phase='kept',recovery_queued=True)
            preview.write(record)
            before=preview.path.read_bytes()
            module.require_install_idle(root)
            self.assertEqual(preview.path.read_bytes(),before)
