import tempfile,unittest,plistlib
from pathlib import Path
from deployment import atomic_link,snapshot,restore,require_service_namespace
class DeploymentTests(unittest.TestCase):
    def test_regular_install_rollback_and_removed_new_file(self):
        with tempfile.TemporaryDirectory() as t:
            p=Path(t);old=p/'controller';old.write_text('old');new=p/'new';current=p/'current'
            snapshot([old,new],p/'backup',current)
            release=p/'release';release.mkdir();(release/'controller').write_text('new')
            atomic_link(release,current);atomic_link(current/'controller',old);new.write_text('new file')
            restore(p/'backup')
            self.assertEqual(old.read_text(),'old');self.assertFalse(old.is_symlink());self.assertFalse(new.exists());self.assertFalse(current.exists())
            self.assertEqual((release/'controller').read_text(),'new')
    def test_existing_release_restored_without_mutating_either_release(self):
        with tempfile.TemporaryDirectory() as t:
            p=Path(t);a=p/'a';b=p/'b';a.mkdir();b.mkdir()
            (a/'controller').write_text('A');(b/'controller').write_text('B')
            current=p/'current';binary=p/'controller';atomic_link(a,current);atomic_link(current/'controller',binary)
            snapshot([binary],p/'backup',current);atomic_link(b,current)
            self.assertEqual(binary.read_text(),'B');restore(p/'backup')
            self.assertTrue(binary.is_symlink());self.assertEqual(binary.read_text(),'A');self.assertEqual((b/'controller').read_text(),'B')
    def test_conflicting_namespace_rejected_without_modifying_agent(self):
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            agents = home/'Library/LaunchAgents'
            agents.mkdir(parents=True)
            for executable in (home/'.local/bin/display-auto.py',
                               home/'Applications/Display Auto.app/Contents/MacOS/display-menu'):
                path = agents/'old.plist'
                original = plistlib.dumps({'Label':'example.old', 'ProgramArguments':[str(executable)]})
                path.write_bytes(original)
                with self.assertRaisesRegex(RuntimeError, 'Earlier'):
                    require_service_namespace(home, 'io.github.display-bridge')
                self.assertEqual(path.read_bytes(), original)

    def test_current_namespace_and_unrelated_plists_allowed(self):
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            agents = home/'Library/LaunchAgents'
            agents.mkdir(parents=True)
            for index, value in enumerate(([], {'ProgramArguments':False},
                    {'Label':'io.github.display-bridge', 'ProgramArguments':[str(home/'.local/bin/display-auto.py')]},
                    {'Label':'other', 'ProgramArguments':['unrelated']})):
                (agents/f'{index}.plist').write_bytes(plistlib.dumps(value))
            require_service_namespace(home, 'io.github.display-bridge')

if __name__=='__main__':unittest.main()
