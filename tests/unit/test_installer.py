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
