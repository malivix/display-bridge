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

    def test_optional_shortcuts_preflight_does_not_sign_or_echo_identity(self):
        module=self.load()
        with tempfile.TemporaryDirectory() as directory,patch('platform.system',return_value='Darwin'),patch('platform.machine',return_value='arm64'),patch('platform.mac_ver',return_value=('13.0','','')):
            for identity in ['synthetic-local-identity','-','']:
                with patch.dict(module.os.environ,{'DISPLAY_BRIDGE_MENU_SIGN_IDENTITY':identity}),patch('menu_build.shortcuts_tools',return_value=()) as inspect:
                    # Ordinary tool inspection fails safely; optional inspection is separate.
                    with patch.object(module,'run',side_effect=OSError('No build tools')):
                        report=module.preflight(Path(directory),Path(directory))
                    check=next(c for c in report['checks'] if c['name']=='Native Shortcuts build')
                    self.assertEqual(check['status'],'ok' if identity=='synthetic-local-identity' else 'error')
                    self.assertEqual(inspect.call_count,int(identity=='synthetic-local-identity'))
                    self.assertNotIn('synthetic-local-identity',str(report))
                    self.assertEqual(list(Path(directory).iterdir()),[])

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
            module.require_idle_preview(root)
            self.assertEqual(list(root.iterdir()),[])
            files={'config.json':b'{}','baseline.json':b'{}'}
            preview=Preview(root/'scaling-preview.json')
            record=preview.begin(files,files,{},'test',100)
            record.update(phase='kept',recovery_queued=True)
            preview.write(record)
            before=preview.path.read_bytes()
            module.require_idle_preview(root)
            self.assertEqual(preview.path.read_bytes(),before)

    def exercise_service_failure(self, lock_error, stop_error=None):
        import subprocess
        module=self.load()
        with tempfile.TemporaryDirectory() as directory:
            home=Path(directory);root=home/'.config/display-auto';root.mkdir(parents=True)
            (root/'config.json').write_text('original configuration')
            prior=root/'releases/prior'
            if stop_error is not None:
                prior.mkdir(parents=True)
                (prior/'display-auto.py').write_text('synthetic prior controller')
                (root/'current').symlink_to(prior)
                launcher=home/'Library/LaunchAgents/io.github.display-bridge.plist'
                launcher.parent.mkdir(parents=True)
                import plistlib
                launcher.write_bytes(plistlib.dumps({'Label':'io.github.display-bridge','ProgramArguments':['python3',str(prior/'display-auto.py')]}))
                launcher_before=launcher.read_bytes()
            events=[]
            def run(args,**kwargs):
                if args[0]=='/usr/bin/xcrun':return subprocess.CompletedProcess(args,0,directory,'')
                if args[0] in ('/usr/bin/swiftc','/usr/bin/clang'):
                    Path(args[args.index('-o')+1]).write_text('synthetic helper')
                elif args[0]=='/usr/bin/make':
                    (Path(args[args.index('-C')+1])/'m1ddc').write_text('synthetic ddc')
                elif args[0]=='launchctl':
                    events.append(args[1])
                    if args[1]=='bootout' and events.count('bootout')==1 and stop_error is not None:
                        raise stop_error
                    if args[1]=='bootstrap':
                        self.assertTrue(kwargs.get('check'))
                        self.assertEqual(kwargs.get('timeout'),10)
                        if stop_error is None:raise subprocess.CalledProcessError(5,args)
                        self.assertEqual(args[-1],str(launcher))
                        self.assertEqual(launcher.read_bytes(),launcher_before)
                elif not (str(args[0]).endswith('/test-ddc') or len(args)>1 and str(args[1]).endswith('/scripts/test')):
                    self.fail('Unexpected subprocess')
                return subprocess.CompletedProcess(args,0,'','')
            original_open=Path.open
            def opened(path,*args,**kwargs):
                if lock_error and path==root/'controller.lock':raise PermissionError('injected controller lock open failure')
                return original_open(path,*args,**kwargs)
            with patch('pathlib.Path.home',return_value=home),patch('platform.system',return_value='Darwin'),patch('platform.machine',return_value='arm64'),patch.object(module,'run',side_effect=run),patch.object(Path,'open',opened),patch.object(module,'atomic_link',side_effect=RuntimeError('injected activation failure')),contextlib.redirect_stderr(io.StringIO()):
                expected=type(stop_error) if stop_error is not None else PermissionError if lock_error else subprocess.CalledProcessError
                with self.assertRaises(expected) as caught:
                    module.main(['A'])
            self.assertEqual((root/'config.json').read_text(),'original configuration')
            from install_progress import read_progress
            report=read_progress(root,'A')
            self.assertEqual(report['status'],'failed')
            self.assertEqual(report['recovery'],'not-needed' if lock_error else 'completed-unverified' if stop_error is not None else 'pending')
            if lock_error:self.assertEqual(events,[])
            else:
                if stop_error is not None:
                    self.assertIs(caught.exception,stop_error)
                    self.assertEqual((root/'current').readlink(),prior)
                    self.assertEqual((prior/'display-auto.py').read_text(),'synthetic prior controller')
                    self.assertEqual(launcher.read_bytes(),launcher_before)
                else:self.assertEqual(caught.exception.cmd[1],'bootstrap')
                self.assertEqual(events,['print','bootout','bootout','bootstrap'])

    def test_controller_lock_prepared_before_stopping_service(self):
        self.exercise_service_failure(lock_error=True)

    def test_failed_rollback_restart_is_reported(self):
        self.exercise_service_failure(lock_error=False)

    def test_failed_or_timed_out_stop_attempts_to_restart_prior_service(self):
        import subprocess
        command=['launchctl','bootout','synthetic-service']
        for error in (subprocess.CalledProcessError(5,command),subprocess.TimeoutExpired(command,10),KeyboardInterrupt()):
            with self.subTest(error=type(error).__name__):
                self.exercise_service_failure(lock_error=False,stop_error=error)

    def test_status_is_read_only_and_exit_zero_means_report_available(self):
        import json
        from install_progress import InstallProgress
        module=self.load()
        with tempfile.TemporaryDirectory() as directory:
            home=Path(directory);root=home/'.config/display-auto';root.mkdir(parents=True)
            with InstallProgress(root,'A'):pass
            path=root/'install-progress.json';before=path.read_bytes()
            with patch('pathlib.Path.home',return_value=home),patch.object(module,'run',side_effect=AssertionError('Status must not run helpers')):
                output=io.StringIO()
                with contextlib.redirect_stdout(output):module.main(['A','--status'])
                report=json.loads(output.getvalue())
                self.assertTrue(report['read_only']);self.assertEqual(report['status'],'incomplete')
                with contextlib.redirect_stdout(io.StringIO()),self.assertRaises(SystemExit) as unavailable:
                    module.main(['B','--status'])
                self.assertEqual(unavailable.exception.code,1)
                with contextlib.redirect_stderr(io.StringIO()),self.assertRaises(SystemExit) as conflict:
                    module.main(['A','--status','--capture-fixed-120'])
                self.assertEqual(conflict.exception.code,2)
            self.assertEqual(path.read_bytes(),before)
            self.assertEqual(list(root.iterdir()),[path])

    def test_recorded_interpreter_is_not_pinned_to_one_patch_release(self):
        module = self.load()
        with tempfile.TemporaryDirectory() as directory:
            cellar = Path(directory) / "Cellar/python/1.2.3/bin/python3"
            cellar.parent.mkdir(parents=True)
            cellar.write_text("#!/bin/sh\n")
            cellar.chmod(0o755)
            stable = Path(directory) / "opt/python/bin/python3"
            stable.parent.mkdir(parents=True)
            stable.symlink_to(cellar)
            with patch.object(module.sys, "executable", str(stable)):
                self.assertEqual(module.interpreter_path(), str(stable))

    def test_unusable_interpreter_is_rejected(self):
        module = self.load()
        for value in ("", "python3", "/nonexistent/python3"):
            with patch.object(module.sys, "executable", value):
                with self.assertRaises(SystemExit):
                    module.interpreter_path()
