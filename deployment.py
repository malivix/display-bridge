# SPDX-License-Identifier: MIT
"""Atomic release pointers and exact file/symlink snapshots for local upgrades."""

import json, os, shutil, plistlib, hashlib
from pathlib import Path
from xml.parsers.expat import ExpatError


def require_idle_preview(root):
    """Preserve queued requests and recovery evidence before touching deployment state."""
    from preview_service import unresolved
    request=root/'preview-request.json'
    if request.exists() or request.is_symlink():
        raise RuntimeError('A size-preview request is pending. Let the controller finish it and complete any restoration before installation or rollback; preserve the request if troubleshooting is needed.')
    if unresolved(root):
        raise RuntimeError('Finish scaling preview recovery before installation or rollback')


def atomic_link(target, path):
    path = Path(path)
    temporary = path.with_name(path.name + ".new")
    if temporary.exists() or temporary.is_symlink():
        temporary.unlink()
    temporary.symlink_to(target)
    temporary.replace(path)


def payload_hash(path):
    """Detect accidental changes to stored files and bundle trees, including symlinks."""
    path = Path(path)
    if path.is_file():
        return hashlib.sha256(path.read_bytes()).hexdigest()
    digest = hashlib.sha256()
    for child in sorted(path.rglob("*")):
        relative = str(child.relative_to(path)).encode()
        if child.is_symlink():
            kind, content = b"link", os.readlink(child).encode()
        elif child.is_dir():
            kind, content = b"dir", b""
        else:
            kind, content = b"file", child.read_bytes()
        for part in (relative, kind, content):
            digest.update(len(part).to_bytes(8, "big"))
            digest.update(part)
    return digest.hexdigest()


def snapshot(files, backup, current):
    backup = Path(backup)
    backup.mkdir(mode=0o700, parents=True)
    entries = []
    for index, original in enumerate(files):
        path = Path(original)
        link = os.readlink(path) if path.is_symlink() else None
        directory = path.is_dir() and link is None
        item = {
            "path": str(path),
            "exists": path.exists() or link is not None,
            "link": link,
            "directory": directory,
            "index": index,
        }
        if directory:
            shutil.copytree(path, backup / str(index), symlinks=True)
        elif path.exists() and link is None:
            shutil.copy2(path, backup / str(index))
        if item["exists"] and link is None:
            item["sha256"] = payload_hash(backup / str(index))
        entries.append(item)
    metadata = {
        "files": entries,
        "current": str(current),
        "previous_release": os.readlink(current) if current.is_symlink() else None,
    }
    (backup / "metadata.json").write_text(json.dumps(metadata, indent=2) + "\n")
    return metadata


def validate_snapshot(backup):
    """Check all required payloads before touching the currently installed state."""
    backup = Path(backup)
    metadata = json.loads((backup / "metadata.json").read_text())
    paths = set()
    for index, item in enumerate(metadata["files"]):
        if item["index"] != index or item["path"] in paths:
            raise RuntimeError("Invalid or duplicate backup entry")
        paths.add(item["path"])
        if not item["exists"] or item["link"] is not None:
            continue
        payload = backup / str(index)
        directory = item.get("directory", False)
        if payload.is_symlink() or (
            not payload.is_dir() if directory else not payload.is_file()
        ):
            raise RuntimeError(
                "Backup content is missing or has the wrong type; nothing restored"
            )
        if item.get("sha256") and payload_hash(payload) != item["sha256"]:
            raise RuntimeError("Backup checksum mismatch; nothing restored")
    previous = metadata["previous_release"]
    if previous is not None:
        target = Path(previous)
        if not target.is_absolute():
            target = Path(metadata["current"]).parent / target
        if not target.is_dir():
            raise RuntimeError("Previous release is unavailable; nothing restored")
    return metadata


def restore(backup):
    backup = Path(backup)
    metadata = validate_snapshot(backup)
    current = Path(metadata["current"])
    if metadata["previous_release"] is not None:
        atomic_link(metadata["previous_release"], current)
    elif current.is_symlink():
        current.unlink()
    for item in metadata["files"]:
        path = Path(item["path"])
        if path.is_dir() and not path.is_symlink():
            shutil.rmtree(path)
        elif path.exists() or path.is_symlink():
            path.unlink()
        if item["exists"]:
            if item["link"] is not None:
                path.symlink_to(item["link"])
            elif item.get("directory", False):
                shutil.copytree(backup / str(item["index"]), path, symlinks=True)
            else:
                shutil.copy2(backup / str(item["index"]), path)


def require_service_namespace(home, label):
    """Reject an older controller/menu owner before installing another namespace."""
    home = Path(home)
    executables = {
        str(home / ".local/bin/display-auto.py"),
        str(home / "Applications/Display Auto.app/Contents/MacOS/display-menu"),
    }
    for path in (home / "Library/LaunchAgents").glob("*.plist"):
        try:
            data = plistlib.loads(path.read_bytes())
        except (ValueError, plistlib.InvalidFileException, ExpatError):
            continue
        if not isinstance(data, dict):
            continue
        args = data.get("ProgramArguments", [])
        if not isinstance(args, list):
            continue
        if any(isinstance(arg, str) and arg in executables for arg in args):
            if data.get("Label") not in (label, label + ".menu"):
                raise RuntimeError(
                    "Earlier Display Bridge service found. Back up settings, "
                    "stop and move the earlier controller and menu LaunchAgents "
                    "before reinstalling. See docs/install.md."
                )
