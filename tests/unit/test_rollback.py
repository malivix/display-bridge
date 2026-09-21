"""Exercise coordinated rollback using temporary files and fake launchctl."""

from pathlib import Path
from types import SimpleNamespace
import tempfile
import subprocess
import unittest
from unittest.mock import patch
from deployment import snapshot
import rollback


class CoordinatedRollbackTests(unittest.TestCase):
    def exercise(self, fail=False, restart_failures=()):
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
                    if args[1] == "bootstrap" and Path(args[-1]).stem in restart_failures:
                        raise subprocess.CalledProcessError(5, args)
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
                if restart_failures:
                    with self.assertRaises(RuntimeError) as caught:
                        rollback.main(["original"])
                    for name in restart_failures:
                        self.assertIn(name, str(caught.exception))
                    if fail:
                        self.assertIn("injected verification failure", str(caught.exception.__cause__))
                    else:
                        self.assertIsInstance(caught.exception.__cause__, subprocess.CalledProcessError)
                elif fail:
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

    def test_restart_failure_does_not_skip_other_service(self):
        controller = "io.github.display-bridge"
        menu = controller + ".menu"
        for failures in ((controller,), (menu,), (controller, menu)):
            for verification_failed in (False, True):
                with self.subTest(failures=failures, verification_failed=verification_failed):
                    self.exercise(fail=verification_failed, restart_failures=failures)

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

    def test_queued_preview_blocks_rollback_before_services_or_restore(self):
        for linked in (False,True):
            with self.subTest(linked=linked),tempfile.TemporaryDirectory() as directory:
                home=Path(directory);root=home/'.config/display-auto';root.mkdir(parents=True)
                app=home/'Applications/Display Auto.app';app.mkdir(parents=True)
                binary=app/'binary';binary.write_text('backup app')
                agent=home/'Library/LaunchAgents/io.github.display-bridge.menu.plist'
                agent.parent.mkdir(parents=True);agent.write_text('backup agent')
                snapshot([app,agent],root/'backups/original',root/'current')
                binary.write_text('current app');agent.write_text('current agent')
                request=root/'preview-request.json'
                if linked:request.symlink_to(root/'missing-request')
                else:request.write_text('preserve malformed pending request')
                with patch.object(rollback.Path,'home',return_value=home),patch.object(rollback,'run',side_effect=AssertionError('No service command with a queued preview')),patch.object(rollback,'restore',side_effect=AssertionError('No restore with a queued preview')):
                    with self.assertRaisesRegex(RuntimeError,'request is pending'):
                        rollback.main(['original'])
                self.assertEqual(binary.read_text(),'current app')
                self.assertEqual(agent.read_text(),'current agent')
                if linked:self.assertTrue(request.is_symlink())
                else:self.assertEqual(request.read_text(),'preserve malformed pending request')
                self.assertEqual([p.name for p in (root/'backups').iterdir()],['original'])

    def test_stop_error_after_service_exit_restarts_attempted_services(self):
        for failed_stop in (1, 2):
            for error_type in (subprocess.CalledProcessError, subprocess.TimeoutExpired, KeyboardInterrupt):
                with self.subTest(stop=failed_stop, error=error_type.__name__), tempfile.TemporaryDirectory() as directory:
                    home = Path(directory)
                    root = home / ".config/display-auto"
                    root.mkdir(parents=True)
                    app = home / "Applications/Display Auto.app"
                    app.mkdir(parents=True)
                    (app / "binary").write_text("current app")
                    agents = home / "Library/LaunchAgents"
                    agents.mkdir(parents=True)
                    paths = [agents / (name + ".plist") for name in
                             ("io.github.display-bridge", "io.github.display-bridge.menu")]
                    for path in paths:
                        path.write_text("current agent")
                    snapshot([app, *paths], root / "backups/original", root / "current")
                    services = {path.stem: True for path in paths}
                    stop_count = 0
                    restarted = []
                    command = ["launchctl", "bootout", "synthetic-service"]
                    failure = (error_type(5, command) if error_type is subprocess.CalledProcessError else
                               error_type(command, 10) if error_type is subprocess.TimeoutExpired else error_type())

                    def run(args, **kwargs):
                        nonlocal stop_count
                        self.assertEqual(args[0], "launchctl")
                        verb = args[1]
                        name = Path(args[-1]).stem if verb == "bootstrap" else args[-1].split("/")[-1]
                        if verb == "print":
                            return SimpleNamespace(returncode=0 if services[name] else 1)
                        if verb == "bootout":
                            services[name] = False  # Side effect occurred before observation failed.
                            stop_count += 1
                            if stop_count == failed_stop:
                                raise failure
                        elif verb == "bootstrap":
                            self.assertEqual((app / "binary").read_text(), "current app")
                            self.assertEqual(Path(args[-1]).read_text(), "current agent")
                            services[name] = True
                            restarted.append(name)
                        else:
                            self.fail("Unexpected service command")
                        return SimpleNamespace(returncode=0)

                    with patch.object(rollback.Path, "home", return_value=home), patch.object(rollback, "run", side_effect=run), patch.object(rollback, "restore", side_effect=AssertionError("No file restoration before stops complete")):
                        with self.assertRaises(error_type) as caught:
                            rollback.main(["original"])
                    self.assertIs(caught.exception, failure)
                    self.assertTrue(all(services.values()), "A service remained stopped after failed rollback")
                    self.assertEqual(len(restarted), failed_stop)
                    self.assertEqual(list((root / "backups").iterdir()), [root / "backups/original"])
