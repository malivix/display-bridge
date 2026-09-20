# SPDX-License-Identifier: MIT
"""Atomic release pointers and exact file/symlink snapshots for local upgrades."""
import json,os,shutil,plistlib
from pathlib import Path

def atomic_link(target, path):
    path=Path(path);temporary=path.with_name(path.name+'.new')
    if temporary.exists() or temporary.is_symlink():temporary.unlink()
    temporary.symlink_to(target);temporary.replace(path)

def snapshot(files, backup, current):
    backup=Path(backup);backup.mkdir(parents=True)
    entries=[]
    for index,path in enumerate(files):
        path=Path(path)
        item={'path':str(path),'exists':path.exists() or path.is_symlink(),'link':os.readlink(path) if path.is_symlink() else None,'index':index}
        if path.exists():shutil.copy2(path,backup/str(index))
        entries.append(item)
    metadata={'files':entries,'current':str(current),'previous_release':os.readlink(current) if current.is_symlink() else None}
    (backup/'metadata.json').write_text(json.dumps(metadata,indent=2)+'\n')
    (backup/'paths.json').write_text(json.dumps({str(i):str(p) for i,p in enumerate(files)},indent=2)+'\n')
    return metadata

def restore(backup):
    backup=Path(backup);metadata=json.loads((backup/'metadata.json').read_text());current=Path(metadata['current'])
    if metadata['previous_release'] is not None:atomic_link(metadata['previous_release'],current)
    elif current.is_symlink():current.unlink()
    for item in metadata['files']:
        path=Path(item['path'])
        if path.exists() or path.is_symlink():path.unlink()
        if item['exists']:
            if item['link'] is not None:path.symlink_to(item['link'])
            else:shutil.copy2(backup/str(item['index']),path)


def require_service_namespace(home, label):
    """Reject an older controller/menu owner before installing another namespace."""
    home = Path(home)
    executables = {str(home/'.local/bin/display-auto.py'),
                   str(home/'Applications/Display Auto.app/Contents/MacOS/display-menu')}
    for path in (home/'Library/LaunchAgents').glob('*.plist'):
        try:
            data = plistlib.loads(path.read_bytes())
        except (ValueError, plistlib.InvalidFileException):
            continue
        if not isinstance(data, dict):
            continue
        args = data.get('ProgramArguments', [])
        if not isinstance(args, list):
            continue
        if any(isinstance(arg, str) and arg in executables for arg in args):
            if data.get('Label') not in (label, label+'.menu'):
                raise RuntimeError('Earlier Display Bridge service found. Back up settings, '
                                   'stop and move the earlier controller and menu LaunchAgents '
                                   'before reinstalling. See docs/development.md.')
