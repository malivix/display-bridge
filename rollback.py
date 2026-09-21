#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Restore a coordinated controller/menu snapshot and verify current physical inputs."""

import datetime
import fcntl
import os
from pathlib import Path
import subprocess
import sys
import time
from deployment import snapshot, restore, validate_snapshot, require_idle_preview
from release_manifest import INSTALLED_FILES


def lock_bounded(file):
    deadline = time.monotonic() + 8
    while True:
        try:
            fcntl.flock(file, fcntl.LOCK_EX | fcntl.LOCK_NB)
            return
        except BlockingIOError:
            if time.monotonic() >= deadline:
                raise RuntimeError("Controller has not stopped; rollback not applied")
            time.sleep(0.05)


def run(args, **kwargs):
    return subprocess.run(args, timeout=25, **kwargs)


def main(argv=None):
    args = sys.argv[1:] if argv is None else argv
    if len(args) != 1:
        raise RuntimeError("Usage: python3 rollback.py BACKUP_TIMESTAMP")
    home = Path.home()
    root = home / ".config/display-auto"
    backup = (root / "backups" / args[0]).resolve()
    if backup.parent != (root / "backups").resolve():
        raise RuntimeError("Use a timestamp from the local backups directory")
    metadata = validate_snapshot(backup)
    menu_agent = home / "Library/LaunchAgents/io.github.display-bridge.menu.plist"
    menu_app = home / "Applications/Display Auto.app"
    if not {str(menu_agent), str(menu_app)}.issubset(
        item["path"] for item in metadata["files"]
    ):
        raise RuntimeError(
            "Backup predates coordinated menu rollback; use a compatible installer instead"
        )
    agents = [home / "Library/LaunchAgents/io.github.display-bridge.plist", menu_agent]
    allowed = {
        home / ".local/bin" / name for name in (*INSTALLED_FILES, "display-auto.sh")
    }
    allowed.update(
        root / name for name in ("config.json", "baseline.json", "manifest.json")
    )
    allowed.update([menu_app, *agents])
    if Path(metadata["current"]) != root / "current" or any(
        Path(item["path"]) not in allowed for item in metadata["files"]
    ):
        raise RuntimeError(
            "Backup paths do not belong to this installation; nothing restored"
        )
    previous = metadata["previous_release"]
    if previous is not None:
        previous_path = Path(previous)
        if not previous_path.is_absolute():
            previous_path = root / previous_path
        if previous_path.resolve().parent != (root / "releases").resolve():
            raise RuntimeError(
                "Backup release is outside this installation; nothing restored"
            )
    services = [(f"gui/{os.getuid()}/{path.stem}", path) for path in agents]
    with (
        (root / "install.lock").open("a") as install,
        (root / "maintenance.lock").open("a") as maintenance,
        (root / "controller.lock").open("a") as controller,
    ):
        fcntl.flock(install, fcntl.LOCK_EX | fcntl.LOCK_NB)
        require_idle_preview(root)
        running = [
            (service, path)
            for service, path in services
            if run(["launchctl", "print", service], capture_output=True).returncode == 0
        ]
        stopped = []
        undo = None
        try:
            for service, path in reversed(running):
                # The stop may take effect even when launchctl fails or times out.
                # Recovery must include the attempted service in that case too.
                stopped.insert(0, (service, path))
                run(["launchctl", "bootout", service], check=True)
            lock_bounded(maintenance)
            lock_bounded(controller)
            journal = root / "audio-refresh.json"
            if journal.exists():
                run(
                    [str(home / ".local/bin/display-audio"), "recover", str(journal)],
                    check=True,
                )
            candidate = (
                root
                / "backups"
                / (
                    "before-rollback-"
                    + datetime.datetime.now().strftime("%Y%m%d-%H%M%S-%f")
                )
            )
            snapshot(
                [Path(item["path"]) for item in metadata["files"]],
                candidate,
                root / "current",
            )
            undo = candidate
            restore(backup)
            fcntl.flock(controller, fcntl.LOCK_UN)
            launcher = home / ".local/bin/display-auto.sh"
            if launcher.exists():
                run(
                    [str(launcher), "once"],
                    env=dict(os.environ, DISPLAY_AUTO_INSTALLER_PID=str(os.getpid())),
                    check=True,
                )
        except BaseException:
            if undo is not None:
                lock_bounded(controller)
                restore(undo)
            raise
        finally:
            original_error = sys.exc_info()[1]
            fcntl.flock(controller, fcntl.LOCK_UN)
            fcntl.flock(maintenance, fcntl.LOCK_UN)
            restart_errors = []
            for service, path in stopped:
                if path.exists():
                    try:
                        run(
                            ["launchctl", "bootstrap", f"gui/{os.getuid()}", str(path)],
                            check=True,
                        )
                    except (OSError, subprocess.SubprocessError) as error:
                        restart_errors.append((path.stem, error))
            if restart_errors:
                failed = ", ".join(f"{name} ({type(error).__name__})" for name, error in restart_errors)
                raise RuntimeError(
                    f"Rollback service restart failed: {failed}. Inspect service status before retrying."
                ) from (original_error if original_error is not None else restart_errors[0][1])
    print(
        f"Restored {backup.name}; controller and menu restored together. Undo snapshot: {undo}"
    )


if __name__ == "__main__":
    main()
