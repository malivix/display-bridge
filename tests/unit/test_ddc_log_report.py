import unittest
from ddc_log_report import summarize


class LogReport(unittest.TestCase):
    def test_interruption_duration_and_transition(self):
        report = summarize('''2026-09-20 17:29:16,491 WARNING DDC unavailable; no changes: benq: No valid matching DDC reply
2026-09-20 17:29:17,594 INFO DDC recovered
2026-09-20 17:29:19,704 INFO PG=18 BenQ=15 profile=away checked in 1.05s
2026-09-20 17:29:25,269 INFO PG=17 BenQ=15 profile=pg checked in 3.66s''')
        self.assertEqual(report['longest_recorded_seconds'], 1.103)
        self.assertEqual(report['by_monitor'], {'benq': 1})
        self.assertEqual(len(report['transitions']), 2)
        self.assertEqual(report['without_recorded_recovery'], 0)

    def test_restart_does_not_prove_recovery(self):
        report = summarize('''2026-09-20 17:00:00,000 WARNING DDC unavailable; no changes: pg: absent
2026-09-20 17:00:01,000 INFO Started v2.8.1
2026-09-20 17:00:02,000 INFO DDC recovered''')
        self.assertEqual(report['without_recorded_recovery'], 1)
        self.assertEqual(report['unmatched_recovery_messages'], 1)
        self.assertIsNone(report['longest_recorded_seconds'])

    def test_deduplicated_warning_and_failed_recovery(self):
        report = summarize('''2026-09-20 17:00:00,000 WARNING DDC unavailable; no changes: benq: bad reply
2026-09-20 17:00:01,000 WARNING DDC unavailable; no changes: benq: bad reply
2026-09-20 17:00:02,000 ERROR Recovery failed: benq: bad reply''')
        self.assertEqual(report['ddc_interruptions'], 1)
        self.assertEqual(len(report['recovery_failures']), 1)
        self.assertEqual(report['without_recorded_recovery'], 1)

    def test_bad_lines_and_clock_reversal(self):
        report = summarize('''partial line
2026-99-20 17:00:00,000 INFO DDC recovered
2026-09-20 17:00:02,000 WARNING DDC unavailable; no changes: unknown error
2026-09-20 17:00:01,000 INFO DDC recovered''')
        self.assertIsNone(report['longest_recorded_seconds'])
        self.assertEqual(report['by_monitor'], {'unknown': 1})
        self.assertEqual(summarize('')['ddc_interruptions'], 0)


if __name__ == '__main__':
    unittest.main()
