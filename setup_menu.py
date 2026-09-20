# SPDX-License-Identifier: MIT
"""Build and install the per-user menu app. No administrator access needed."""

import os, plistlib, shutil, subprocess, tempfile, time, json, re
from pathlib import Path
from deployment import require_service_namespace
from release_manifest import VERSION, MENU_BUILD


def activate_menu(staged, app, agent, service, run, health_path, version):
    """Restore the old app and launch state on activation/readiness failure."""
    backup = staged.parent / "previous.app"
    previous_agent = agent.read_bytes() if agent.exists() else None
    running = run(["launchctl", "print", service], capture_output=True).returncode == 0
    moved = False
    activated = False
    try:
        if running:
            run(["launchctl", "bootout", service], check=True)
        until = time.monotonic() + 10
        executable = str(app / "Contents/MacOS/display-menu")
        while True:
            registered = run(["launchctl", "print", service], capture_output=True).returncode == 0
            processes = run(["/bin/ps", "-axo", "comm="], capture_output=True, text=True, check=True)
            if not isinstance(processes.stdout, str):
                raise RuntimeError("Could not inspect existing menu processes")
            active = executable in {line.strip() for line in processes.stdout.splitlines()}
            if not registered and not active:
                break
            if time.monotonic() > until:
                raise RuntimeError("Existing menu is still running. Quit its menu-bar app before upgrading; no replacement was made.")
            time.sleep(0.1)
        if app.exists():
            app.rename(backup)
            moved = True
        staged.rename(app)
        activated = True
        agent.write_bytes(
            plistlib.dumps(
                {
                    "Label": "io.github.display-bridge.menu",
                    "ProgramArguments": [str(app / "Contents/MacOS/display-menu")],
                    "RunAtLoad": True,
                    "ProcessType": "Interactive",
                    "StandardErrorPath": str(
                        health_path.parents[2] / "Library/Logs/display-auto-menu.log"
                    ),
                }
            )
        )
        started = time.time()
        run(["launchctl", "bootstrap", f"gui/{os.getuid()}", str(agent)], check=True)
        deadline = time.monotonic() + 10
        while True:
            state = run(["launchctl", "print", service], capture_output=True, text=True)
            pid = re.search(r"\bpid = (\d+)", state.stdout or "")
            try:
                health = json.loads(health_path.read_text())
            except (OSError, ValueError):
                health = {}
            if (
                state.returncode == 0
                and pid
                and health.get("pid") == int(pid.group(1))
                and health.get("app_version") == version
                and health.get("updated_at", 0) >= started
            ):
                break
            if time.monotonic() >= deadline:
                raise RuntimeError(
                    "Menu did not publish fresh matching status within 10 seconds"
                )
            time.sleep(0.1)
    except BaseException:
        run(["launchctl", "bootout", service], capture_output=True)
        if activated and app.exists():
            shutil.rmtree(app)
        if moved:
            backup.rename(app)
        if previous_agent is not None:
            agent.write_bytes(previous_agent)
        else:
            agent.unlink(missing_ok=True)
        if running and previous_agent is not None:
            run(
                ["launchctl", "bootstrap", f"gui/{os.getuid()}", str(agent)], check=True
            )
        raise


def install_menu(package):
    home = Path.home()
    require_service_namespace(home, "io.github.display-bridge")
    apps = home / "Applications"
    apps.mkdir(exist_ok=True)
    app = apps / "Display Auto.app"
    agent = home / "Library/LaunchAgents/io.github.display-bridge.menu.plist"
    service = f"gui/{os.getuid()}/io.github.display-bridge.menu"

    def run(args, **kw):
        return subprocess.run(args, timeout=90, **kw)

    sdk = run(
        ["xcrun", "--sdk", "macosx", "--show-sdk-path"],
        check=True,
        capture_output=True,
        text=True,
    ).stdout.strip()
    with tempfile.TemporaryDirectory(dir=apps, prefix=".display-menu-") as temp:
        staged = Path(temp) / app.name
        contents = staged / "Contents"
        binary = contents / "MacOS/display-menu"
        binary.parent.mkdir(parents=True)
        run(
            [
                "swiftc",
                "-sdk",
                sdk,
                "-target",
                "arm64-apple-macos13.0",
                "-O",
                str(package / "native/display-menu.swift"),
                "-o",
                str(binary),
            ],
            check=True,
        )
        run([str(binary), "--self-test"], check=True)
        info = {
            "CFBundleIdentifier": "io.github.display-bridge.menu",
            "CFBundleName": "Display Auto",
            "CFBundleExecutable": "display-menu",
            "CFBundlePackageType": "APPL",
            "CFBundleShortVersionString": VERSION,
            "CFBundleVersion": MENU_BUILD,
            "LSMinimumSystemVersion": "13.0",
            "LSUIElement": True,
            "NSHighResolutionCapable": True,
        }
        (contents / "Info.plist").write_bytes(plistlib.dumps(info))
        run(["codesign", "--force", "--sign", "-", str(staged)], check=True)
        activate_menu(
            staged,
            app,
            agent,
            service,
            run,
            home / ".config/display-auto/menu-health.json",
            info["CFBundleShortVersionString"],
        )
    print("Installed menu app:", app)


if __name__ == "__main__":
    install_menu(Path(__file__).resolve().parent)
