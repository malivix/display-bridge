# SPDX-License-Identifier: MIT
"""Build a companion bundle without activating it or touching controller state."""
import json
import plistlib
import re
import subprocess
import tempfile
from pathlib import Path

from release_manifest import VERSION, MENU_BUILD, MENU_SOURCES, source_fingerprint


def shortcuts_tools(run):
    """Inspect optional Xcode tools. Does not select or access a signing identity."""
    def output(args):
        return run(args, check=True, capture_output=True, text=True, timeout=10).stdout.strip()
    swift = Path(output(["xcrun", "--find", "swiftc"]))
    processor = output(["xcrun", "--find", "appintentsmetadataprocessor"])
    toolchain = swift.parents[2]
    protocols = json.loads((toolchain / "usr/share/swift/SwiftConstantValues/AppIntents.json").read_text())
    values = protocols.get("constValueProtocols") if isinstance(protocols, dict) else None
    if not isinstance(values, list) or not values or not all(isinstance(v, str) for v in values):
        raise RuntimeError("Unsupported Xcode App Intents protocol manifest")
    version = output(["xcodebuild", "-version"])
    match = re.search(r"^Build version (\S+)$", version, re.MULTILINE)
    if not processor or not match:
        raise RuntimeError("Full Xcode with App Intents metadata tools is required")
    return swift, processor, toolchain, values, match.group(1)


def build_menu(package, staged, run, shortcuts_identity=None):
    """Return bundle info only after build, metadata and signing checks succeed."""
    if shortcuts_identity is not None and (not isinstance(shortcuts_identity, str)
                                           or not shortcuts_identity.strip() or shortcuts_identity.strip() == "-"):
        raise RuntimeError("Native Shortcuts requires an explicit non-ad-hoc signing identity")
    identity = shortcuts_identity.strip() if shortcuts_identity is not None else "-"
    tools = shortcuts_tools(run) if shortcuts_identity is not None else None
    fingerprint = source_fingerprint(package)
    sdk = run(["xcrun", "--sdk", "macosx", "--show-sdk-path"], check=True,
              capture_output=True, text=True, timeout=10).stdout.strip()
    contents = staged / "Contents"
    binary = contents / "MacOS/display-menu"
    binary.parent.mkdir(parents=True)
    sources = [str(package / source) for source in MENU_SOURCES]
    with tempfile.TemporaryDirectory(prefix="display-bridge-metadata-") as folder:
        temporary = Path(folder)
        flags = []
        compiler = "swiftc"
        if tools:
            swift, processor, toolchain, protocols, xcode_version = tools
            compiler = str(swift)
            constants = temporary / "menu.swiftconstvalues"
            protocol_file = temporary / "protocols.json"
            protocol_file.write_text(json.dumps(protocols))
            output_map = temporary / "outputs.json"
            output_map.write_text(json.dumps({"": {"const-values": str(constants)}}))
            flags = ["-whole-module-optimization", "-emit-const-values", "-output-file-map", str(output_map),
                     "-Xfrontend", "-const-gather-protocols-file", "-Xfrontend", str(protocol_file)]
        run([compiler, "-sdk", sdk, "-target", "arm64-apple-macos13.0", "-O",
             "-module-name", "DisplayBridgeMenu", *flags, *sources, "-o", str(binary)], check=True)
        run([str(binary), "--self-test"], check=True)
        if tools:
            resources = contents / "Resources"
            resources.mkdir()
            (temporary / "sources.txt").write_text("\n".join(sources) + "\n")
            (temporary / "values.txt").write_text(str(constants) + "\n")
            run([processor, "--output", str(resources), "--toolchain-dir", str(toolchain),
                 "--module-name", "DisplayBridgeMenu", "--sdk-root", sdk,
                 "--xcode-version", xcode_version, "--platform-family", "macOS", "--deployment-target", "13.0",
                 "--target-triple", "arm64-apple-macos13.0", "--source-file-list", str(temporary / "sources.txt"),
                 "--swift-const-vals-list", str(temporary / "values.txt")], check=True)
            metadata = json.loads((resources / "Metadata.appintents/extract.actionsdata").read_text())
            entity = metadata.get("entities", {}).get("DisplayBridgeStatusResult", {})
            fields = {p.get("identifier") for p in entity.get("properties", []) if isinstance(p, dict)}
            expected = {"freshness", "controller", "arrangement", "pauseRequest", "recovery", "ageSeconds"}
            if (not {"GetDisplayBridgeStatus", "PauseDisplayBridge", "ResumeDisplayBridge"}.issubset(metadata.get("actions", {})) or fields != expected
                    or not metadata.get("autoShortcuts")):
                raise RuntimeError("Native Shortcuts metadata is incomplete; bundle was not signed")
    if source_fingerprint(package) != fingerprint:
        raise RuntimeError("Sources changed during menu compilation; retry from a stable checkout")
    info = {
        "DisplayBridgeSourceFingerprint": fingerprint,
        "DisplayBridgeShortcutsPackaged": tools is not None,
        "CFBundleIdentifier": "io.github.display-bridge.menu", "CFBundleName": "Display Auto",
        "CFBundleExecutable": "display-menu", "CFBundlePackageType": "APPL",
        "CFBundleShortVersionString": VERSION, "CFBundleVersion": MENU_BUILD,
        "LSMinimumSystemVersion": "13.0", "LSUIElement": True, "NSHighResolutionCapable": True,
    }
    (contents / "Info.plist").write_bytes(plistlib.dumps(info))
    try:
        run(["codesign", "--force", "--sign", identity, str(staged)], check=True, capture_output=True)
    except (subprocess.CalledProcessError, subprocess.TimeoutExpired):
        raise RuntimeError("Menu signing failed; check the selected local identity") from None
    run(["codesign", "--verify", "--deep", "--strict", str(staged)], check=True)
    if tools:
        signature = run(["codesign", "--display", "--verbose=4", str(staged)], check=True,
                        capture_output=True, text=True)
        if not re.search(r"^TeamIdentifier=[A-Z0-9]{10}$", signature.stderr or "", re.MULTILINE):
            raise RuntimeError("Native Shortcuts signature has no team identity; bundle was not activated")
    return info
