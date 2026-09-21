"""Disposable installer subprocess probe. Every external command is stubbed."""
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import time
from unittest.mock import patch


def main():
    home, ready = map(Path, sys.argv[1:])
    package = Path(__file__).resolve().parents[2]
    sys.path.insert(0, str(package))
    spec = importlib.util.spec_from_file_location('isolated_installer', package / 'install.py')
    installer = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(installer)
    from install_progress import InstallProgress
    original_phase = InstallProgress.phase
    events = home / 'service-events.jsonl'

    def phase(progress, name, **kwargs):
        original_phase(progress, name, **kwargs)
        if name == 'checking-configuration':
            ready.write_text('activated')
            while True:
                time.sleep(.05)

    def run(args, **kwargs):
        if args[0] == '/usr/bin/xcrun':
            return subprocess.CompletedProcess(args, 0, str(home), '')
        if args[0] in ('/usr/bin/swiftc', '/usr/bin/clang'):
            Path(args[args.index('-o') + 1]).write_text('synthetic helper')
        elif args[0] == '/usr/bin/make':
            (Path(args[args.index('-C') + 1]) / 'm1ddc').write_text('synthetic ddc')
        elif args[0] == 'launchctl':
            if args[1] not in ('print', 'bootout', 'bootstrap'):
                raise AssertionError('Unexpected service action')
            if args[1] == 'bootstrap':
                root = home / '.config/display-auto'
                if ((root / 'current').readlink() != root / 'releases/prior' or
                    (home / '.local/bin/display-auto.py').read_text() != 'prior controller' or
                    (home / '.local/bin/display-auto.sh').read_text() != 'original launcher' or
                    args[-1] != str(home / 'Library/LaunchAgents/io.github.display-bridge.plist')):
                    raise AssertionError('Restart attempted before prior release and launcher restoration')
            with events.open('a') as stream:
                stream.write(json.dumps(args[1]) + '\n')
        elif not (str(args[0]).endswith('/test-ddc') or
                  len(args) > 1 and str(args[1]).endswith('/scripts/test')):
            raise AssertionError('Unexpected external command; nothing was executed')
        return subprocess.CompletedProcess(args, 0, '', '')

    with patch('pathlib.Path.home', return_value=home), \
         patch('platform.system', return_value='Darwin'), \
         patch('platform.machine', return_value='arm64'), \
         patch.object(installer, 'run', side_effect=run), \
         patch.object(InstallProgress, 'phase', phase):
        try:
            installer.main(['A'])
        except KeyboardInterrupt:
            return 130
    raise AssertionError('Probe should be interrupted before configuration inspection')


if __name__ == '__main__':
    sys.exit(main())
