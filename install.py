#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Install the same local controller on either Mac; captures machine-local modes."""

from pathlib import Path
import datetime
import hashlib
import json
import os
import plistlib
import shutil
import subprocess
import sys
import tempfile
import time
import fcntl
from contextlib import ExitStack
from deployment import atomic_link, snapshot, restore, require_service_namespace, require_idle_preview
from release_manifest import (
    RUNTIME_MODULES,
    MENU_SOURCES,
    INSTALLED_FILES,
    HELPER_HASH_FIELDS,
    VERSION,
)


def run(args, **kwargs):
    kwargs.setdefault("timeout", 120)
    kwargs.setdefault("env", dict(os.environ, MACOSX_DEPLOYMENT_TARGET="13.0"))
    return subprocess.run(args, **kwargs)


def preflight(package, home):
    """Software prerequisites only; never build, create state or contact monitor helpers."""
    import platform
    checks=[]
    def add(name, ok, detail):
        checks.append({'name':name,'status':'ok' if ok else 'error','detail':detail})
    compatible=platform.system()=='Darwin' and platform.machine()=='arm64'
    add('Platform',compatible,'Apple-silicon macOS is required.')
    try:
        major=int(platform.mac_ver()[0].split('.')[0])
    except (ValueError,IndexError):
        major=0
    add('macOS version',compatible and major>=13,'macOS 13 or newer is required.')
    add('Python',sys.version_info>=(3,10),'Python 3.10 or newer is required.')
    sources=(*RUNTIME_MODULES,'install_progress.py','setup_menu.py','scripts/test','native/display-layout.swift',
             'native/display-audio.m','native/display-rotate.m','native/display-mode-info.m',
             *MENU_SOURCES,'vendor/m1ddc/Makefile','tests/native/test_ddc.m')
    missing=[name for name in sources if not (package/name).is_file()]
    add('Source files',not missing,'Required source entry points are present.' if not missing else 'Incomplete checkout; missing: '+', '.join(missing))
    toolchain=False
    if compatible:
        try:
            sdk=run(['/usr/bin/xcrun','--sdk','macosx','--show-sdk-path'],capture_output=True,text=True,timeout=10,check=True).stdout.strip()
            toolchain=bool(sdk) and Path(sdk).is_dir()
            for tool in ('clang','swiftc'):
                found=run(['/usr/bin/xcrun','--find',tool],capture_output=True,text=True,timeout=10,check=True).stdout.strip()
                toolchain=toolchain and bool(found) and os.access(found,os.X_OK)
            toolchain=toolchain and os.access('/usr/bin/make',os.X_OK)
        except (OSError,subprocess.SubprocessError):
            toolchain=False
    add('Build tools',toolchain,'SDK, Swift, Clang and make are available.' if toolchain else 'Install or select Xcode Command Line Tools, then rerun preflight on the supported Mac.')
    try:
        require_service_namespace(home,'io.github.display-bridge')
        add('Service namespace',True,'No conflicting known Display Bridge service namespace found.')
    except (OSError,RuntimeError):
        add('Service namespace',False,'Cannot verify service ownership. Review older LaunchAgents using docs/install.md before installation.')
    return {'read_only':True,'status':'prerequisites-ready' if all(c['status']=='ok' for c in checks) else 'attention-required',
            'checks':checks,'limits':'Software prerequisites only. No build, monitor read, service change or installation was performed. Display ownership, saved configuration, pending recovery, permissions and hardware behavior are not qualified. The installer rechecks its live requirements.'}


def main(argv=None):
    with ExitStack() as resources:
        return run_install(argv, resources)


def run_install(argv, resources):
    import argparse
    import platform

    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("host", choices=("A", "B"))
    inspection = parser.add_mutually_exclusive_group()
    inspection.add_argument("--preflight", action="store_true", help="Report software prerequisites without installing or accessing monitors")
    inspection.add_argument("--status", action="store_true", help="Read the latest local installer outcome without installing")
    capture = parser.add_mutually_exclusive_group()
    capture.add_argument("--capture-fixed-120", action="store_true")
    capture.add_argument("--capture-rotation", action="store_true")
    args = parser.parse_args(argv)
    if args.status:
        if args.capture_fixed_120 or args.capture_rotation:
            parser.error("--status cannot be combined with capture options")
        from install_progress import read_progress
        result=read_progress(Path.home()/'.config/display-auto',args.host)
        print(json.dumps(result,indent=2))
        if not result['available']:raise SystemExit(1)
        return
    if args.preflight:
        if args.capture_fixed_120 or args.capture_rotation:
            parser.error("--preflight cannot be combined with capture options")
        result=preflight(Path(__file__).resolve().parent,Path.home())
        print(json.dumps(dict(result,host=args.host),indent=2))
        if result['status']!='prerequisites-ready':raise SystemExit(1)
        return
    if platform.system() != "Darwin" or platform.machine() != "arm64":
        parser.error("Installation requires an Apple-silicon Mac")
    role = args.host
    package = Path(__file__).resolve().parent
    home = Path.home()
    python = str(Path(sys.executable).resolve())
    label = "io.github.display-bridge"
    service = f"gui/{os.getuid()}/{label}"
    plist = home / "Library/LaunchAgents" / (label + ".plist")
    root = home / ".config/display-auto"
    bin_dir = home / ".local/bin"
    require_service_namespace(home, label)
    require_idle_preview(root)
    root.mkdir(mode=0o700, parents=True, exist_ok=True)
    root.chmod(0o700)
    bin_dir.mkdir(parents=True, exist_ok=True)
    plist.parent.mkdir(parents=True, exist_ok=True)
    (home / "Library/Logs").mkdir(parents=True, exist_ok=True)
    install_lock = resources.enter_context((root / "install.lock").open("a"))
    try:
        fcntl.flock(install_lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        sys.exit("Another installation is already running")
    # Enqueue also takes install.lock. Recheck after exclusive acquisition so a
    # request arriving between the preliminary check and lock cannot be missed.
    require_idle_preview(root)
    from install_progress import InstallProgress
    progress = resources.enter_context(InstallProgress(root, role))
    progress.phase('building')
    sdk = run(
        ["/usr/bin/xcrun", "--sdk", "macosx", "--show-sdk-path"],
        capture_output=True,
        text=True,
        check=True,
    ).stdout.strip()
    build_env = dict(os.environ, SDKROOT=sdk, MACOSX_DEPLOYMENT_TARGET="13.0")
    m1ddc = bin_dir / "display-ddc"
    run([python, str(package / "scripts/test")], check=True)
    with tempfile.TemporaryDirectory(prefix="display-auto-build-") as temp:
        built = Path(temp) / "display-layout"
        run(
            [
                "/usr/bin/swiftc",
                "-sdk",
                sdk,
                "-target",
                "arm64-apple-macos13.0",
                "-O",
                str(package / "native/display-layout.swift"),
                "-o",
                str(built),
            ],
            check=True,
        )
        audio_built = Path(temp) / "display-audio"
        run(
            [
                "/usr/bin/clang",
                "-isysroot",
                sdk,
                "-fobjc-arc",
                "-Wall",
                "-Wextra",
                "-framework",
                "Foundation",
                "-framework",
                "CoreAudio",
                str(package / "native/display-audio.m"),
                "-o",
                str(audio_built),
            ],
            check=True,
        )
        rotate_built = Path(temp) / "display-rotate"
        run(
            [
                "/usr/bin/clang",
                "-isysroot",
                sdk,
                "-target",
                "arm64-apple-macos13.0",
                "-fobjc-arc",
                "-Wall",
                "-Wextra",
                "-Werror",
                "-framework",
                "Foundation",
                "-framework",
                "CoreGraphics",
                str(package / "native/display-rotate.m"),
                "-o",
                str(rotate_built),
            ],
            check=True,
        )
        mode_info_built = Path(temp) / "display-mode-info"
        run(
            [
                "/usr/bin/clang",
                "-isysroot",
                sdk,
                "-target",
                "arm64-apple-macos13.0",
                "-fobjc-arc",
                "-Wall",
                "-Wextra",
                "-Werror",
                "-framework",
                "Foundation",
                "-framework",
                "CoreGraphics",
                str(package / "native/display-mode-info.m"),
                "-o",
                str(mode_info_built),
            ],
            check=True,
        )
        ddc_source = Path(temp) / "m1ddc"
        shutil.copytree(
            package / "vendor/m1ddc",
            ddc_source,
            ignore=shutil.ignore_patterns(".objects", "m1ddc", "library", ".git"),
        )
        run(
            ["/usr/bin/make", "-C", str(ddc_source), "binary", "CC=/usr/bin/clang"],
            check=True,
            env=build_env,
        )
        test_ddc = Path(temp) / "test-ddc"
        run(
            [
                "/usr/bin/clang",
                "-isysroot",
                sdk,
                "-fmodules",
                "-I",
                str(ddc_source / "headers"),
                str(package / "tests/native/test_ddc.m"),
                str(ddc_source / "sources/i2c.m"),
                "-framework",
                "Foundation",
                "-framework",
                "CoreDisplay",
                "-o",
                str(test_ddc),
            ],
            check=True,
        )
        run([str(test_ddc)], check=True)
        stamp = datetime.datetime.now().strftime("%Y%m%d-%H%M%S-%f")
        backup = root / "backups" / stamp
        files = [bin_dir / name for name in (*INSTALLED_FILES, "display-auto.sh")]
        files += [
            root / name for name in ("config.json", "baseline.json", "manifest.json")
        ]
        files += [
            plist,
            home / "Applications/Display Auto.app",
            home / "Library/LaunchAgents/io.github.display-bridge.menu.plist",
        ]
        current = root / "current"
        progress.phase('backing-up')
        snapshot(files, backup, current)
        release = root / "releases" / (VERSION + "-" + stamp)
        release.mkdir(parents=True)
        for name in RUNTIME_MODULES:
            shutil.copy2(package / name, release / name)
        shutil.copy2(built, release / "display-layout")
        shutil.copy2(audio_built, release / "display-audio")
        shutil.copy2(rotate_built, release / "display-rotate")
        shutil.copy2(mode_info_built, release / "display-mode-info")
        shutil.copy2(ddc_source / "m1ddc", release / "display-ddc")
        for runtime_file in release.iterdir():
            runtime_file.chmod(0o555 if os.access(runtime_file, os.X_OK) else 0o444)
        child_env = dict(os.environ, DISPLAY_AUTO_INSTALLER_PID=str(os.getpid()))
        maintenance = resources.enter_context((root / "maintenance.lock").open("a"))
        controller_lock = resources.enter_context((root / "controller.lock").open("a"))
        running = (
            run(["launchctl", "print", service], capture_output=True).returncode == 0
        )
        activated = False
        try:
            # A failed/timed-out stop may already have taken effect. Keep it
            # inside recovery so the prior service is restarted on this path.
            progress.phase('stopping-controller', recovery='pending')
            if running:
                run(["launchctl", "bootout", service], check=True)
            stop_deadline = time.monotonic() + 8
            while True:
                try:
                    fcntl.flock(maintenance, fcntl.LOCK_EX | fcntl.LOCK_NB)
                    fcntl.flock(controller_lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
                    break
                except BlockingIOError:
                    if time.monotonic() >= stop_deadline:
                        raise RuntimeError(
                            "Previous controller has not stopped; no new files installed"
                        )
                    time.sleep(0.05)
            progress.phase('activating')
            activated = True
            atomic_link(release, current)
            for name in INSTALLED_FILES:
                atomic_link(current / name, bin_dir / name)
            # A simple wrapper preserves the familiar entry point without shell eval.
            import shlex

            (bin_dir / "display-auto.sh").write_text(
                "#!/bin/zsh\nif (( $# == 0 )); then set -- run; fi\nexec "
                + shlex.quote(python)
                + ' "$HOME/.local/bin/display-auto.py" "$@"\n'
            )
            (bin_dir / "display-auto.sh").chmod(0o755)
            fcntl.flock(controller_lock, fcntl.LOCK_UN)
            progress.phase('checking-configuration')
            previous = (
                json.loads((root / "config.json").read_text())
                if (root / "config.json").exists()
                else None
            )
            if (
                previous
                and previous.get("host") == role
                and previous.get("version", "").startswith("2.")
            ):
                previous["version"] = VERSION
                previous["m1ddc"] = str(m1ddc)
                if "ddc_identifiers" not in previous:
                    import importlib.util

                    identity_spec = importlib.util.spec_from_file_location(
                        "identity_controller", package / "display-auto.py"
                    )
                    identity_controller = importlib.util.module_from_spec(identity_spec)
                    identity_spec.loader.exec_module(identity_controller)
                    previous["ddc_identifiers"] = (
                        identity_controller.capture_identifiers(m1ddc)
                    )
                if args.capture_fixed_120 or args.capture_rotation:
                    screens = json.loads(
                        run(
                            [str(bin_dir / "display-layout"), "status"],
                            capture_output=True,
                            text=True,
                            check=True,
                        ).stdout
                    )["screens"]
                    if (
                        len(screens) != 2
                        or set(x["key"] for x in screens)
                        != set(previous["keys"].values())
                        or any(
                            x.get("mirrorOf") or abs(x["hz"] - 120) > 0.2
                            for x in screens
                        )
                    ):
                        raise RuntimeError(
                            "Select fixed 120 Hz on both local extended displays before capture"
                        )
                    from display_snapshot import validate_capture_modes
                    metadata=json.loads(run([str(bin_dir / "display-mode-info"),"status"],capture_output=True,text=True,check=True,timeout=10).stdout)
                    validate_capture_modes(screens,metadata,previous["keys"])
                    previous["baseline"] = {
                        "screens": [dict(x, strictMode=True) for x in screens]
                    }
                    angle = next(
                        s["rotation"]
                        for s in screens
                        if s["key"] == previous["keys"]["benq"]
                    )
                    if previous.get("rotation") or args.capture_rotation:
                        value = run(
                            [
                                str(m1ddc),
                                "display",
                                previous["ddc_identifiers"]["benq"],
                                "get",
                                "orientation",
                            ],
                            check=True,
                            capture_output=True,
                            text=True,
                        ).stdout.strip()
                        if {"1": 0, "2": 90}.get(value) != angle:
                            raise RuntimeError(
                                "Physical sensor and macOS rotation must agree at 0 or 90 degrees"
                            )
                        rotation = previous.setdefault(
                            "rotation",
                            {"sensor_map": {"1": 0, "2": 90}, "baselines": {}},
                        )
                        rotation["baselines"][str(int(angle))] = previous["baseline"]
                        rotation["enabled"] = set(rotation["baselines"]) == {"0", "90"}
                if "audio" not in previous:
                    import importlib.util

                    sys.path.insert(0, str(package))
                    module_spec = importlib.util.spec_from_file_location(
                        "display_controller", package / "display-auto.py"
                    )
                    controller = importlib.util.module_from_spec(module_spec)
                    module_spec.loader.exec_module(controller)
                    previous["audio"] = controller.capture_audio()
                if "refresh_on_transition" not in previous["audio"]:
                    enabled = previous["audio"].pop("refresh_pg_on_transition", True)
                    previous["audio"]["refresh_on_transition"] = (
                        ["pg", "benq"] if enabled else []
                    )
                (root / "config.json").write_text(json.dumps(previous, indent=2) + "\n")
                (root / "baseline.json").write_text(
                    json.dumps(previous["baseline"], indent=2) + "\n"
                )
                print("Preserved existing display baseline; checking current profile.")
                run(
                    [python, str(bin_dir / "display-auto.py"), "once"],
                    check=True,
                    timeout=20,
                    env=child_env,
                )
            else:
                run(
                    [
                        python,
                        str(bin_dir / "display-auto.py"),
                        "capture",
                        "--host",
                        role,
                        "--m1ddc",
                        str(m1ddc),
                    ],
                    check=True,
                    env=child_env,
                )
                run(
                    [python, str(bin_dir / "display-auto.py"), "test-layouts"],
                    check=True,
                    env=child_env,
                )
            spec = {
                "Label": label,
                "ProgramArguments": [python, str(bin_dir / "display-auto.py"), "run"],
                "RunAtLoad": True,
                "KeepAlive": True,
                "ThrottleInterval": 10,
                "ProcessType": "Background",
                "StandardOutPath": str(
                    home / "Library/Logs/display-auto-v2-launch.log"
                ),
                "StandardErrorPath": str(
                    home / "Library/Logs/display-auto-v2-launch-error.log"
                ),
            }
            plist.write_bytes(plistlib.dumps(spec))
            source_files = list(package.glob("*.py"))
            source_files += [
                p
                for directory in ("native", "tests")
                for p in (package / directory).rglob("*")
                if p.suffix in (".py", ".swift", ".m")
            ]
            source_files.append(package / "scripts/test")
            source_files += [
                p
                for p in (package / "vendor/m1ddc").rglob("*")
                if p.is_file()
                and (
                    p.suffix in (".m", ".h")
                    or p.name in ("Makefile", "LICENSE", "LOCAL-CHANGES.md")
                )
            ]
            hashes = {
                str(p.relative_to(package)): hashlib.sha256(p.read_bytes()).hexdigest()
                for p in sorted(source_files)
            }
            from release_manifest import source_fingerprint
            manifest = {
                "source_fingerprint": source_fingerprint(package),
                "version": VERSION,
                "host": role,
                "source_sha256": hashes,
                "python": python,
                "ddc_version": "m1ddc-04d9497+read-fix2",
            }
            manifest.update(
                {
                    field: hashlib.sha256((bin_dir / name).read_bytes()).hexdigest()
                    for name, field in HELPER_HASH_FIELDS.items()
                }
            )
            (root / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
            shutil.copy2(root / "manifest.json", release / "manifest.json")
            fcntl.flock(maintenance, fcntl.LOCK_UN)
            progress.phase('starting-controller')
            launched_at = time.time()
            run(
                ["launchctl", "bootstrap", f"gui/{os.getuid()}", str(plist)],
                check=True,
                timeout=10,
            )
            deadline = time.monotonic() + 20
            while True:
                try:
                    health = json.loads((root / "health.json").read_text())
                    service_state = run(
                        ["launchctl", "print", service],
                        capture_output=True,
                        text=True,
                        timeout=5,
                    )
                    import re

                    pid = re.search(r"\bpid = (\d+)", service_state.stdout)
                    if (
                        health["updated_at"] >= launched_at
                        and health["version"] == VERSION
                        and health["host"] == role
                        and health["status"] == "ready"
                        and pid
                        and int(pid.group(1)) == health["pid"]
                    ):
                        break
                except (OSError, ValueError, KeyError):
                    pass
                if time.monotonic() >= deadline:
                    raise RuntimeError("Service did not become ready within 20 seconds")
                time.sleep(0.25)
            # Keep companion failures inside the controller rollback boundary.
            from setup_menu import install_menu

            progress.phase('installing-menu')
            install_menu(package)
        except BaseException:
            progress.phase('recovering')
            fcntl.flock(controller_lock, fcntl.LOCK_UN)
            run(["launchctl", "bootout", service], capture_output=True)
            if activated:
                from rollback import lock_bounded

                lock_bounded(maintenance)
                lock_bounded(controller_lock)
                journal = root / "audio-refresh.json"
                if journal.exists():
                    run(
                        [str(release / "display-audio"), "recover", str(journal)],
                        check=True,
                        timeout=6,
                    )
                restore(backup)
                fcntl.flock(controller_lock, fcntl.LOCK_UN)
            fcntl.flock(maintenance, fcntl.LOCK_UN)
            if running:
                run(["launchctl", "bootstrap", f"gui/{os.getuid()}", str(plist)], check=True, timeout=10)
            progress.phase('recovery-finished', recovery='completed-unverified')
            print(
                (f"Installation failed; prior files restored from {backup}" if activated else
                 "Installation failed before activation; the active release was not changed."),
                file=sys.stderr,
            )
            raise
    print(f"Installed Display Bridge v{VERSION} for Mac {role}. Backup: {backup}")
    print(f"Check: {python} {bin_dir}/display-auto.py check")
    progress.succeed()


if __name__ == "__main__":
    main()
