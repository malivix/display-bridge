import fcntl
import json
from pathlib import Path
import plistlib
import signal
import subprocess
import sys
import tempfile
import time
import unittest


class InstallerInterrupt(unittest.TestCase):
    def test_sigint_after_activation_restores_coordinated_snapshot(self):
        package = Path(__file__).resolve().parents[2]
        with tempfile.TemporaryDirectory() as folder:
            home = Path(folder)
            root = home / '.config/display-auto'
            prior = root / 'releases/prior'
            prior.mkdir(parents=True)
            (prior / 'display-auto.py').write_text('prior controller')
            current = root / 'current'
            current.symlink_to(prior)
            bin_dir = home / '.local/bin'
            bin_dir.mkdir(parents=True)
            entry = bin_dir / 'display-auto.py'
            entry.symlink_to(current / 'display-auto.py')
            wrapper = bin_dir / 'display-auto.sh'
            wrapper.write_text('original launcher')
            config = root / 'config.json'
            config.write_text('original configuration')
            agent = home / 'Library/LaunchAgents/io.github.display-bridge.plist'
            agent.parent.mkdir(parents=True)
            agent.write_bytes(plistlib.dumps({'Label':'io.github.display-bridge',
                'ProgramArguments':['python3',str(prior / 'display-auto.py')]}))
            menu = home / 'Applications/Display Auto.app/Contents/marker'
            menu.parent.mkdir(parents=True)
            menu.write_text('prior companion')
            original = {path:path.read_bytes() for path in (wrapper,config,agent,menu)}
            ready = home / 'ready'
            with (home / 'output.log').open('w+') as output:
                process = subprocess.Popen([sys.executable,str(package / 'tests/fixtures/installer_interrupt.py'),
                                            str(home),str(ready)],stdout=output,stderr=output)
                try:
                    deadline = time.monotonic() + 15
                    while not ready.exists() and process.poll() is None and time.monotonic() < deadline:
                        time.sleep(.02)
                    self.assertTrue(ready.exists(), 'Installer did not reach the disposable activation barrier')
                    self.assertNotEqual(current.readlink(),prior)
                    self.assertNotEqual(wrapper.read_bytes(),original[wrapper])
                    self.assertEqual(entry.readlink(),current / 'display-auto.py')
                    process.send_signal(signal.SIGINT)
                    self.assertEqual(process.wait(timeout=10),130)
                finally:
                    if process.poll() is None:
                        process.kill()
                        process.wait(timeout=5)
            self.assertEqual(current.readlink(),prior)
            self.assertEqual(entry.read_text(),'prior controller')
            for path, before in original.items():
                self.assertEqual(path.read_bytes(),before)
            self.assertEqual({path.name for path in bin_dir.iterdir()}, {'display-auto.py','display-auto.sh'})
            events=[json.loads(row) for row in (home / 'service-events.jsonl').read_text().splitlines()]
            self.assertEqual(events,['print','bootout','bootout','bootstrap'])
            progress=json.loads((root / 'install-progress.json').read_text())
            self.assertEqual(progress['status'],'failed')
            self.assertEqual(progress['reason'],'interrupted')
            self.assertEqual(progress['recovery'],'completed-unverified')
            for name in ('install.lock','maintenance.lock','controller.lock'):
                with (root / name).open('a') as lock:
                    fcntl.flock(lock,fcntl.LOCK_EX | fcntl.LOCK_NB)
