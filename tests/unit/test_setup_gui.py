import io
from pathlib import Path
import tarfile
import tempfile
import unittest
from setup_gui import unpack_source

class SetupBundleTests(unittest.TestCase):
    def archive(self, name, kind=tarfile.REGTYPE):
        output=io.BytesIO()
        with tarfile.open(fileobj=output,mode='w') as archive:
            item=tarfile.TarInfo(name);item.type=kind
            if kind==tarfile.REGTYPE:item.size=4;item.mode=0o755
            archive.addfile(item,io.BytesIO(b'test') if kind==tarfile.REGTYPE else None)
        return output.getvalue()
    def test_snapshot_rejects_traversal_links_and_special_files_before_writing(self):
        for name,kind in [('../escape',tarfile.REGTYPE),('/absolute',tarfile.REGTYPE),('link',tarfile.SYMTYPE),('hard',tarfile.LNKTYPE),('pipe',tarfile.FIFOTYPE)]:
            with self.subTest(name=name),tempfile.TemporaryDirectory() as temp:
                root=Path(temp)
                with self.assertRaises(ValueError):unpack_source(self.archive(name,kind),root)
                self.assertEqual(list(root.iterdir()),[])
    def test_regular_source_is_read_only_and_executable_flag_is_preserved(self):
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp);unpack_source(self.archive('scripts/test'),root)
            self.assertEqual((root/'scripts/test').read_bytes(),b'test')
            self.assertEqual((root/'scripts/test').stat().st_mode & 0o777,0o555)

    def test_real_builder_rejects_dirty_checkout_before_creating_an_app(self):
        from unittest.mock import patch
        import setup_gui
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp)
            with patch.object(setup_gui,'ROOT',root),patch('setup_gui.platform.system',return_value='Darwin'),patch('setup_gui.platform.machine',return_value='arm64'),patch('setup_gui.subprocess.check_output',return_value=' M install.py\n'),patch('setup_gui.subprocess.run',side_effect=AssertionError('No compiler or app launch')):
                with self.assertRaisesRegex(RuntimeError,'clean, trusted'):setup_gui.build(False)
            self.assertEqual(list(root.iterdir()),[])
