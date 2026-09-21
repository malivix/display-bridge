#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Build an independent setup app from a trusted checkout; installation is a separate UI action."""
import argparse
import io
from pathlib import Path, PurePosixPath
import platform
import plistlib
import subprocess
import sys
import tarfile
import tempfile

from release_manifest import SETUP_SOURCES, VERSION

ROOT = Path(__file__).resolve().parent


def unpack_source(archive, destination):
    """Extract regular source files only, preserving no links or special files."""
    with tarfile.open(fileobj=io.BytesIO(archive)) as bundle:
        members=bundle.getmembers()
        if sum(max(0,item.size) for item in members)>64*1024*1024:
            raise ValueError('Source snapshot exceeds the setup size limit')
        for item in members:
            path=PurePosixPath(item.name)
            if path.is_absolute() or '..' in path.parts or not (item.isdir() or item.isfile()):
                raise ValueError('Source snapshot contains an unsupported path or file')
        for item in members:
            path=destination.joinpath(*PurePosixPath(item.name).parts)
            if item.isdir():path.mkdir(parents=True,exist_ok=True)
            else:
                path.parent.mkdir(parents=True,exist_ok=True)
                with bundle.extractfile(item) as source:path.write_bytes(source.read())
                path.chmod(0o555 if item.mode & 0o111 else 0o444)


def build(demo=False):
    if platform.system()!='Darwin' or platform.machine()!='arm64' or sys.version_info<(3,10):
        raise RuntimeError('Setup requires Apple-silicon macOS and Python 3.10 or newer')
    revision="Working tree demo"
    if not demo:
        revision=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip()
        dirty=subprocess.check_output(['git','status','--porcelain','--untracked-files=normal'],cwd=ROOT,text=True)
        if dirty.strip():raise RuntimeError('Use a clean, trusted checkout before building a real setup app. Demo mode can inspect uncommitted UI work.')
    private=ROOT/'.local-only';private.mkdir(mode=0o700,exist_ok=True)
    directory=Path(tempfile.mkdtemp(prefix='setup-',dir=private))
    app=directory/'Display Bridge Setup.app';contents=app/'Contents'
    binary=contents/'MacOS/display-setup';binary.parent.mkdir(parents=True)
    source=ROOT
    if not demo:
        source=contents/'Resources/Source';source.mkdir(parents=True)
        archive=subprocess.check_output(['git','archive','--format=tar',revision],cwd=ROOT)
        unpack_source(archive,source)
    subprocess.run(['/usr/bin/swiftc','-target','arm64-apple-macos13.0',*[str(source/name) for name in SETUP_SOURCES],'-o',str(binary)],check=True)
    subprocess.run([str(binary),'--self-test'],check=True)
    info={'CFBundleIdentifier':'io.github.display-bridge.setup'+('.demo' if demo else ''),
          'CFBundleName':'Display Bridge Setup','CFBundleExecutable':'display-setup',
          'CFBundlePackageType':'APPL','CFBundleShortVersionString':VERSION,'LSMinimumSystemVersion':'13.0',
          'DisplayBridgeRevision':revision,'DisplayBridgeDemo':demo,'DisplayBridgePython':str(Path(sys.executable).resolve())}
    (contents/'Info.plist').write_bytes(plistlib.dumps(info))
    subprocess.run(['/usr/bin/codesign','--force','--deep','--sign','-',str(app)],check=True)
    return app


def main(argv=None):
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--demo',action='store_true',help='Use synthetic setup; never run the installer or hardware commands')
    parser.add_argument('--build-only',action='store_true',help='Build without opening the app')
    args=parser.parse_args(argv)
    app=build(args.demo)
    print(app)
    if not args.build_only:subprocess.run(['/usr/bin/open','-n',str(app)],check=True)


if __name__=='__main__':main()
