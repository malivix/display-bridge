import tempfile
import unittest
from pathlib import Path
from release_manifest import MENU_SOURCES, RUNTIME_MODULES, source_fingerprint


class SourceFingerprintTests(unittest.TestCase):
    def test_portable_sensitive_to_both_components_and_excludes_runtime_state(self):
        with tempfile.TemporaryDirectory() as directory:
            first=Path(directory)/'first';second=Path(directory)/'second'
            for root in (first,second):
                for name in set(MENU_SOURCES+RUNTIME_MODULES):
                    path=root/name;path.parent.mkdir(parents=True,exist_ok=True);path.write_text(name)
            original=source_fingerprint(first)
            self.assertEqual(original,source_fingerprint(second))
            (second/'config.json').write_text('{"private":"example"}')
            self.assertEqual(original,source_fingerprint(second))
            for name in ('display-auto.py',MENU_SOURCES[0]):
                path=second/name;path.write_text('changed')
                self.assertNotEqual(original,source_fingerprint(second))
                path.write_text(name)
            (second/MENU_SOURCES[0]).unlink()
            with self.assertRaises(FileNotFoundError):source_fingerprint(second)
