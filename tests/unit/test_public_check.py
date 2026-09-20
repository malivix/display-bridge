"""Adversarial fixtures are synthetic and never include real user data."""
import runpy
from pathlib import Path
import unittest

check = runpy.run_path(str(Path(__file__).resolve().parents[2]/'scripts/public-check'))['check_blob']


class PublicationTests(unittest.TestCase):
    def test_private_artifacts_cannot_be_force_added(self):
        for name in ('.local-only/notes.md', 'evidence/report.json', 'bundle.zip',
                     'x/.env.production', 'CLAUDE.local.md', 'config.json', 'display-layout', 'vendor/m1ddc/.objects/a.o'):
            with self.subTest(name=name):
                self.assertTrue(check(name, '100644', b'private'))

    def test_external_symlink_and_binary_rejected(self):
        self.assertTrue(check('notes.md', '120000', b'../../private'))
        self.assertTrue(check('helper', '100755', b'code\0binary'))

    def test_personal_path_and_device_identity_rejected(self):
        home = '/' + 'Users' + '/' + 'synthetic-user' + '/document'
        device = '-'.join(['12345678', '1234', '1234', '1234', '123456789abc'])
        for value in (home, device):
            self.assertTrue(check('sample.py', '100644', value.encode()))

    def test_portable_document_and_source_accepted(self):
        self.assertEqual(check('README.md', '100644', b'Use ~/.config/display-auto'), [])
        self.assertEqual(check('app.py', '100644', b'print("hello")'), [])
