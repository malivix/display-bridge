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
