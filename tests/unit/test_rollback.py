"""Exercise coordinated rollback using temporary files and fake launchctl."""

from pathlib import Path
from types import SimpleNamespace
import tempfile
import unittest
from unittest.mock import patch
from deployment import snapshot
import rollback


class CoordinatedRollbackTests(unittest.TestCase):
    def exercise(self, fail=False):
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            root = home / ".config/display-auto"
            root.mkdir(parents=True)
            app = home / "Applications/Display Auto.app"
            app.mkdir(parents=True)
            (app / "binary").write_text("old app")
            launcher = home / ".local/bin/display-auto.sh"
            launcher.parent.mkdir(parents=True)
            launcher.write_text("old controller")
            agents = home / "Library/LaunchAgents"
            agents.mkdir(parents=True)
            controller = agents / "io.github.display-bridge.plist"
            menu = agents / "io.github.display-bridge.menu.plist"
            controller.write_text("old controller agent")
            menu.write_text("old menu agent")
            snapshot(
                [launcher, app, controller, menu],
                root / "backups/original",
                root / "current",
            )
            (app / "binary").write_text("new app")
            launcher.write_text("new controller")
            controller.write_text("new controller agent")
            menu.write_text("new menu agent")
            events = []

            def run(args, **kwargs):
                if args[0] == "launchctl":
                    events.append((args[1], Path(args[-1]).name))
                    return SimpleNamespace(returncode=0)
                self.assertEqual(args, [str(launcher), "once"])
                self.assertEqual((app / "binary").read_text(), "old app")
                if fail:
                    raise RuntimeError("injected verification failure")
                return SimpleNamespace(returncode=0)

            with (
                patch.object(rollback.Path, "home", return_value=home),
                patch.object(rollback, "run", side_effect=run),
                patch("builtins.print"),
            ):
                if fail:
                    with self.assertRaisesRegex(RuntimeError, "injected"):
                        rollback.main(["original"])
                else:
                    rollback.main(["original"])
            expected = "new" if fail else "old"
            self.assertEqual((app / "binary").read_text(), expected + " app")
            self.assertEqual(launcher.read_text(), expected + " controller")
            self.assertEqual(menu.read_text(), expected + " menu agent")
            self.assertEqual(controller.read_text(), expected + " controller agent")
            self.assertEqual([event[0] for event in events].count("bootout"), 2)
            self.assertEqual([event[0] for event in events].count("bootstrap"), 2)

    def test_controller_and_menu_restore_together(self):
        self.exercise()

    def test_failed_verification_undoes_both_components(self):
        self.exercise(fail=True)

    def test_old_backup_rejected_before_stopping_any_service(self):
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            root = home / ".config/display-auto"
            root.mkdir(parents=True)
            snapshot([], root / "backups/old", root / "current")
            with (
                patch.object(rollback.Path, "home", return_value=home),
                patch.object(rollback, "run") as run,
            ):
                with self.assertRaisesRegex(RuntimeError, "predates"):
                    rollback.main(["old"])
                run.assert_not_called()

    def test_backup_for_another_installation_is_rejected_before_service_changes(self):
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            root = home / ".config/display-auto"
            root.mkdir(parents=True)
            app = home / "Applications/Display Auto.app"
            menu = home / "Library/LaunchAgents/io.github.display-bridge.menu.plist"
            snapshot([app, menu], root / "backups/foreign", root / "unrelated-current")
            with (
                patch.object(rollback.Path, "home", return_value=home),
                patch.object(rollback, "run") as run,
            ):
                with self.assertRaisesRegex(RuntimeError, "paths do not belong"):
                    rollback.main(["foreign"])
                run.assert_not_called()
