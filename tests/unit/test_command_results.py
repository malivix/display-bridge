import tempfile
import unittest
from pathlib import Path
from command_results import outcome, publish, validate_request


def request(index=1, action='resume'):
    return {'id': f'{index:032x}', 'action': action, 'created_at': 100}


class CommandResults(unittest.TestCase):
    def test_supersession_restart_and_terminal_stability(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'results.json'
            publish(path, request(), 'applying', 'pending')
            publish(path, request(2), 'deferred', 'away')
            self.assertEqual(publish(path, request(), 'verified', 'late')['state'], 'superseded')
            publish(path, request(2), 'verified', 'done')
            self.assertEqual(publish(path, request(2), 'applying', 'restart')['state'], 'verified')
            self.assertEqual(path.stat().st_mode & 0o777, 0o600)

    def test_corrupt_history_is_preserved(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'results.json'
            for content in ('{bad', '{}', '[{}]'):
                path.write_text(content)
                with self.assertRaises(ValueError):
                    publish(path, request(), 'accepted', 'seen')
                self.assertEqual(path.read_text(), content)

    def test_bounded_retention_and_metadata_reuse_rejected(self):
        import json
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'results.json'
            for index in range(25):
                publish(path, request(index), 'policy-applied', 'saved')
            self.assertEqual(len(json.loads(path.read_text())), 20)
            with self.assertRaises(ValueError):
                publish(path, request(24, 'pause'), 'accepted', 'reused')

    def test_no_success_for_unknown_or_inactive_setup(self):
        for status, profile in [('ready', 'unknown'), ('paused', 'extended'), ('inactive-setup', None), ('waiting-for-ddc', 'extended')]:
            self.assertEqual(outcome(request(), status, profile, {}, 101)[0], 'deferred')
        self.assertEqual(outcome(request(action='rotation-auto'), 'ready', 'pg', {}, 101)[0], 'deferred')
        self.assertEqual(outcome(request(), 'degraded', 'extended', {}, 101)[0], 'failed')
        self.assertEqual(outcome(request(), 'ready', 'extended', {}, 101)[0], 'verified')
        self.assertEqual(outcome(request(action='speaker'), 'ready', 'away', {}, 101)[0], 'policy-applied')
        self.assertEqual(outcome(request(action='pause'), 'paused', 'extended', {}, 101)[0], 'policy-applied')
        self.assertEqual(outcome(request(action='pause-for'), 'ready', 'extended', {}, 101)[0], 'deferred')
        self.assertEqual(outcome(request(), 'ready', 'extended', {'audio_manual_until':102}, 101)[0], 'deferred')
        self.assertEqual(outcome(request(), 'ready', 'extended', {'audio_manual_until':100}, 101)[0], 'verified')

    def test_bad_request_metadata(self):
        for invalid in ({}, dict(request(), created_at=10**1000), dict(request(), action='disconnect'), dict(request(), id='bad')):
            with self.assertRaises(ValueError):
                validate_request(invalid)

class ControllerResults(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        import importlib.util
        spec = importlib.util.spec_from_file_location('result_controller', Path(__file__).resolve().parents[2] / 'display-auto.py')
        cls.controller = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(cls.controller)

    def test_watch_only_reports_verified_after_reconciliation(self):
        import json
        from unittest.mock import patch
        from contextlib import ExitStack
        c = self.controller
        class Finished(Exception): pass
        with tempfile.TemporaryDirectory() as directory, ExitStack() as stack:
            root = Path(directory)
            for key, value in [('ROOT', root), ('HEALTH', root/'health.json'), ('CONTROL', root/'control.json'), ('JOURNAL', root/'audio-refresh.json')]:
                stack.enter_context(patch.object(c, key, value))
            c.CONTROL.write_text(json.dumps({'command_request': request()}))
            for key, value in [('read_inputs', {'pg':17,'benq':19}), ('audio_inventory', []), ('apply_rotation', False), ('apply', False), ('sync_audio', 'verified')]:
                stack.enter_context(patch.object(c, key, return_value=value))
            def stable(config, debounce, *args):
                debounce.confirmed_after = .25
                return True
            stack.enter_context(patch.object(c, "stable_state", side_effect=stable))
            real_health = c.write_health
            observed = []
            def health(config, status, *args, **kwargs):
                real_health(config, status, *args, **kwargs)
                observed.append(json.loads(c.HEALTH.read_text()))
                if status == 'ready': raise Finished()
            stack.enter_context(patch.object(c, 'write_health', side_effect=health))
            with self.assertRaises(Finished):
                c.watch({'host':'A','poll_interval':.25})
            self.assertNotIn('command_result', observed[0])
            self.assertEqual(observed[-1]['command_result']['state'], 'verified')
            c.sync_audio.assert_called_once()

    def test_tracking_corruption_does_not_reset_or_overwrite(self):
        import json
        from unittest.mock import patch
        c = self.controller
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            history = root/'command-results.json'
            history.write_text('{broken')
            with patch.object(c, 'ROOT', root), patch.object(c, 'HEALTH', root/'health.json'):
                c.write_health({'host':'A','_command_request':request()}, 'ready', 'extended')
            health = json.loads((root/'health.json').read_text())
            self.assertIn('command_tracking_error', health)
            self.assertNotIn('command_result', health)
            self.assertEqual(history.read_text(), '{broken')
