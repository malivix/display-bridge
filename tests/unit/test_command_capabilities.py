import contextlib
import importlib.util
import io
import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch


class CommandCapabilities(unittest.TestCase):
    def test_report_requires_no_enrollment_or_hardware(self):
        spec = importlib.util.spec_from_file_location(
            'capability_controller', Path(__file__).resolve().parents[2] / 'display-auto.py')
        controller = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(controller)
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp) / 'absent'
            output = io.StringIO()
            with patch.object(controller, 'ROOT', root), patch.object(controller, 'startup_config', side_effect=AssertionError('config accessed')), patch.object(controller, 'command', side_effect=AssertionError('hardware accessed')), patch.object(controller.sys, 'argv', ['display-auto.py', 'capabilities']), contextlib.redirect_stdout(output):
                controller.main()
            report = json.loads(output.getvalue())
            self.assertEqual(report['protocol'], 1)
            self.assertIs(report['read_only'], True)
            self.assertIn('brightness-apply', report['commands'])
            self.assertIn('preview-revert', report['commands'])
            self.assertEqual(len(report['commands']), len(set(report['commands'])))
            self.assertFalse(root.exists())
