import json
import tempfile
import unittest
from pathlib import Path
from support_summary import report


class SupportSummary(unittest.TestCase):
    def test_private_fields_and_unknown_enums_never_copied(self):
        secret='PRIVATE_CANARY_DO_NOT_EXPORT'
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory)
            (root/'health.json').write_text(json.dumps({'status':'ready','profile':'extended','updated_at':100,
                'error':secret,'inputs':{'pg':secret},'audio':{'selected':{'name':secret}},'rotation':{'enabled':True,'key':secret},secret:secret}))
            (root/'control.json').write_text(json.dumps({'paused':secret,'auto_rotate':False,'speaker_preferences':{secret:secret}}))
            (root/'recovery.json').write_text(json.dumps({'pending':True,'attempts':3,'error':secret}))
            (root/'transitions.json').write_text(json.dumps([{'profile':secret,'result':secret,'error':secret}]))
            value=report(root,101)
            self.assertNotIn(secret,json.dumps(value))
            self.assertTrue(value['controller']['heartbeat_fresh'])
            self.assertIsNone(value['preferences']['pause_requested'])
            self.assertEqual(value['recent_transition_counts'],[{'profile':'unknown','result':'unknown','count':1}])

    def test_malformed_and_oversized_files_report_unavailable_without_modifying(self):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory)
            for content in ('{broken','x'*1_048_577):
                path=root/'health.json';path.write_text(content)
                value=report(root,100)
                self.assertIn('health.json',value['unavailable_sections'])
                self.assertFalse(value['controller']['heartbeat_fresh'])
                self.assertEqual(path.read_text(),content)

    def test_bounded_counts_and_invalid_numbers(self):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory)
            (root/'transitions.json').write_text(json.dumps([{'profile':'pg','result':'ready'}]*250))
            (root/'health.json').write_text(json.dumps({'updated_at':10**1000}))
            (root/'recovery.json').write_text(json.dumps({'attempts':True}))
            value=report(root,100)
            self.assertEqual(value['recent_transition_counts'][0]['count'],200)
            self.assertIsNone(value['recovery']['attempts'])
            self.assertFalse(value['controller']['heartbeat_fresh'])
