import tempfile, unittest, plistlib
import signal
import subprocess
import sys
from pathlib import Path
from unittest.mock import patch
from deployment import atomic_link, snapshot, restore, require_service_namespace


class DeploymentTests(unittest.TestCase):
    def test_regular_install_rollback_and_removed_new_file(self):
        with tempfile.TemporaryDirectory() as t:
            p = Path(t)
            old = p / "controller"
            old.write_text("old")
            new = p / "new"
            current = p / "current"
            snapshot([old, new], p / "backup", current)
            release = p / "release"
            release.mkdir()
            (release / "controller").write_text("new")
            atomic_link(release, current)
            atomic_link(current / "controller", old)
            new.write_text("new file")
            restore(p / "backup")
            self.assertEqual(old.read_text(), "old")
            self.assertFalse(old.is_symlink())
            self.assertFalse(new.exists())
            self.assertFalse(current.exists())
            self.assertEqual((release / "controller").read_text(), "new")

    def test_existing_release_restored_without_mutating_either_release(self):
        with tempfile.TemporaryDirectory() as t:
            p = Path(t)
            a = p / "a"
            b = p / "b"
            a.mkdir()
            b.mkdir()
            (a / "controller").write_text("A")
            (b / "controller").write_text("B")
            current = p / "current"
            binary = p / "controller"
            atomic_link(a, current)
            atomic_link(current / "controller", binary)
            snapshot([binary], p / "backup", current)
            atomic_link(b, current)
            self.assertEqual(binary.read_text(), "B")
            restore(p / "backup")
            self.assertTrue(binary.is_symlink())
            self.assertEqual(binary.read_text(), "A")
            self.assertEqual((b / "controller").read_text(), "B")

    def test_conflicting_namespace_rejected_without_modifying_agent(self):
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            agents = home / "Library/LaunchAgents"
            agents.mkdir(parents=True)
            for executable in (
                home / ".local/bin/display-auto.py",
                home / "Applications/Display Auto.app/Contents/MacOS/display-menu",
            ):
                path = agents / "old.plist"
                original = plistlib.dumps(
                    {"Label": "example.old", "ProgramArguments": [str(executable)]}
                )
                path.write_bytes(original)
                with self.assertRaisesRegex(RuntimeError, "Earlier"):
                    require_service_namespace(home, "io.github.display-bridge")
                self.assertEqual(path.read_bytes(), original)

    def test_current_namespace_and_unrelated_plists_allowed(self):
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            agents = home / "Library/LaunchAgents"
            agents.mkdir(parents=True)
            for index, value in enumerate(
                (
                    [],
                    {"ProgramArguments": False},
                    {
                        "Label": "io.github.display-bridge",
                        "ProgramArguments": [str(home / ".local/bin/display-auto.py")],
                    },
                    {"Label": "other", "ProgramArguments": ["unrelated"]},
                )
            ):
                (agents / f"{index}.plist").write_bytes(plistlib.dumps(value))
            require_service_namespace(home, "io.github.display-bridge")

    def test_bundle_snapshot_and_restore_preserves_original_contents(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            app = root / "Menu.app"
            app.mkdir()
            (app / "binary").write_text("original")
            snapshot([app], root / "backup", root / "current")
            (app / "binary").write_text("replacement")
            (app / "extra").write_text("new")
            restore(root / "backup")
            self.assertEqual((app / "binary").read_text(), "original")
            self.assertFalse((app / "extra").exists())

    def test_missing_backup_is_rejected_before_any_restore_mutation(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            one, two = root / "one", root / "two"
            one.write_text("one")
            two.write_text("two")
            snapshot([one, two], root / "backup", root / "current")
            one.write_text("new one")
            two.write_text("new two")
            (root / "backup/1").unlink()
            with self.assertRaises((OSError, RuntimeError)):
                restore(root / "backup")
            self.assertEqual(one.read_text(), "new one")
            self.assertEqual(two.read_text(), "new two")

    def test_changed_bundle_payload_is_rejected_before_restore(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            app = root / "Menu.app"
            app.mkdir()
            (app / "binary").write_text("original")
            snapshot([app], root / "backup", root / "current")
            (app / "binary").write_text("current")
            (root / "backup/0/binary").write_text("corrupt")
            with self.assertRaisesRegex(RuntimeError, "checksum"):
                restore(root / "backup")
            self.assertEqual((app / "binary").read_text(), "current")


if __name__ == "__main__":
    unittest.main()

class MalformedUnrelatedAgent(unittest.TestCase):
    def test_malformed_xml_does_not_block_namespace_scan(self):
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            agents = home / "Library/LaunchAgents"
            agents.mkdir(parents=True)
            path = agents / "unrelated.plist"
            content = b'<?xml version="1.0"?><plist><dict><string>bad & value</string></dict></plist>'
            path.write_bytes(content)
            require_service_namespace(home, "io.github.display-bridge")
            self.assertEqual(path.read_bytes(), content)


class DeploymentInterruptionTests(unittest.TestCase):
    def test_process_death_around_pointer_swap_preserves_retry_and_restore(self):
        # Exercise real filesystem replacement and uncatchable process termination,
        # rather than an exception that ordinary installer cleanup could handle.
        program = """
import os, signal, sys
from pathlib import Path
from deployment import atomic_link
root = Path(sys.argv[1])
stage = sys.argv[2]
replace = Path.replace
def interrupted_replace(path, target):
    if stage == 'before':
        os.kill(os.getpid(), signal.SIGKILL)
    result = replace(path, target)
    os.kill(os.getpid(), signal.SIGKILL)
    return result
Path.replace = interrupted_replace
atomic_link(root / 'new-release', root / 'current')
"""
        for stage in ("before", "after"):
            with self.subTest(stage=stage), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                old, new = root / "old-release", root / "new-release"
                for release, value in ((old, "old"), (new, "new")):
                    release.mkdir()
                    (release / "controller").write_text(value)
                current, entry = root / "current", root / "controller"
                atomic_link(old, current)
                atomic_link(current / "controller", entry)
                snapshot([entry], root / "backup", current)
                metadata_before = (root / "backup/metadata.json").read_bytes()
                child = subprocess.run(
                    [sys.executable, "-B", "-c", program, str(root), stage],
                    cwd=Path(__file__).resolve().parents[2], capture_output=True, timeout=5,
                )
                self.assertEqual(child.returncode, -signal.SIGKILL, child.stderr.decode())
                self.assertEqual(entry.read_text(), "old" if stage == "before" else "new")
                self.assertEqual((root / "current.new").is_symlink(), stage == "before")
                self.assertEqual((root / "backup/metadata.json").read_bytes(), metadata_before)
                atomic_link(new, current)
                self.assertFalse((root / "current.new").is_symlink())
                self.assertEqual(entry.read_text(), "new")
                restore(root / "backup")
                self.assertEqual(entry.read_text(), "old")
                self.assertEqual((old / "controller").read_text(), "old")
                self.assertEqual((new / "controller").read_text(), "new")

    def test_failed_restore_copy_preserves_current_file_or_bundle(self):
        for directory_payload in (False, True):
            with self.subTest(directory=directory_payload), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                destination = root / "target"
                if directory_payload:
                    destination.mkdir()
                    content = destination / "binary"
                else:
                    content = destination
                content.write_text("backup contents")
                snapshot([destination], root / "backup", root / "current")
                content.write_text("current contents")

                def failed_copy(source, target, **kwargs):
                    target = Path(target)
                    if directory_payload:
                        target.mkdir()
                        target = target / "partial"
                    target.write_text("incomplete replacement")
                    raise OSError("injected destination write failure")

                copier = "copytree" if directory_payload else "copy2"
                with patch("deployment.shutil." + copier, side_effect=failed_copy):
                    with self.assertRaisesRegex(OSError, "injected destination"):
                        restore(root / "backup")
                self.assertTrue(content.exists(), "Copy failure removed the current payload")
                self.assertEqual(content.read_text(), "current contents")
                self.assertEqual(list(root.glob(".display-bridge-restore-*")), [])
                restore(root / "backup")
                self.assertEqual(content.read_text(), "backup contents")

    def test_late_copy_failure_preserves_all_live_paths_and_release_pointer(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            old, new = root / "old-release", root / "new-release"
            old.mkdir();new.mkdir()
            current = root / "current"
            atomic_link(old, current)
            first, second, removed = (root / name for name in ("first", "second", "removed"))
            first.write_text("old first");second.write_text("old second")
            snapshot([removed, first, second], root / "backup", current)
            atomic_link(new, current)
            first.write_text("new first");second.write_text("new second")
            removed.write_text("keep until copying succeeds")
            import shutil
            copy = shutil.copy2
            def fail_second(source, target, **kwargs):
                if Path(source).name == "2":
                    Path(target).write_text("partial")
                    raise OSError("injected later copy failure")
                return copy(source, target, **kwargs)
            with patch("deployment.shutil.copy2", side_effect=fail_second):
                with self.assertRaisesRegex(OSError, "injected later"):
                    restore(root / "backup")
            self.assertEqual(current.readlink(), new)
            self.assertEqual(first.read_text(), "new first")
            self.assertEqual(second.read_text(), "new second")
            self.assertEqual(removed.read_text(), "keep until copying succeeds")
            self.assertEqual(list(root.glob(".display-bridge-restore-*")), [])
            restore(root / "backup")
            self.assertEqual(current.readlink(), old)
            self.assertEqual(first.read_text(), "old first")
            self.assertEqual(second.read_text(), "old second")
            self.assertFalse(removed.exists())
