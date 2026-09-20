import json,tempfile,time,unittest
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch
from setup_menu import activate_menu


class MenuDeployment(unittest.TestCase):
    def exercise(self,existing=True,fail=False,wrong_pid=False,orphan=False):
        with tempfile.TemporaryDirectory() as folder:
            root=Path(folder);staged=root/'stage';staged.mkdir();(staged/'marker').write_text('new')
            app=root/'app';agent=root/'agent.plist';health=root/'state.json'
            if existing:app.mkdir();(app/'marker').write_text('old');agent.write_bytes(b'old agent')
            running=[existing];boots=[]
            def run(args,**kwargs):
                if args[0]=='/bin/ps':return SimpleNamespace(returncode=0,stdout=str(app/'Contents/MacOS/display-menu') if orphan else '')
                if args[1]=='print':return SimpleNamespace(returncode=0 if running[0] else 1,stdout='pid = 123' if running[0] else '')
                if args[1]=='bootout':running[0]=False
                if args[1]=='bootstrap':
                    marker=(app/'marker').read_text();boots.append(marker)
                    if marker=='new' and fail:raise RuntimeError('injected bootstrap failure')
                    running[0]=True
                    health.write_text(json.dumps({'pid':999 if wrong_pid else 123,'app_version':'new','updated_at':time.time()+.01}))
                return SimpleNamespace(returncode=0,stdout='')
            clock=iter(range(100))
            with patch('setup_menu.time.sleep'),patch('setup_menu.time.monotonic',side_effect=lambda:next(clock)):
                if fail or wrong_pid or orphan:
                    with self.assertRaises(RuntimeError):activate_menu(staged,app,agent,'service',run,health,'new')
                    self.assertEqual(app.exists(),existing)
                    self.assertEqual(running[0],existing)
                    if existing:
                        self.assertEqual((app/'marker').read_text(),'old');self.assertEqual(agent.read_bytes(),b'old agent')
                        self.assertEqual(boots,['old'] if orphan else ['new','old'])
                    else:self.assertFalse(agent.exists())
                else:
                    activate_menu(staged,app,agent,'service',run,health,'new')
                    self.assertEqual((app/'marker').read_text(),'new');self.assertTrue(running[0])
    def test_unmanaged_instance_blocks_replacement_and_restores_service(self):self.exercise(orphan=True)
    def test_success_requires_matching_heartbeat(self):self.exercise()
    def test_bootstrap_failure_restores_existing_app_and_service(self):self.exercise(fail=True)
    def test_failed_first_install_removes_partial_app(self):self.exercise(existing=False,fail=True)
    def test_wrong_pid_times_out_and_restores_old_version(self):self.exercise(wrong_pid=True)


if __name__=='__main__':unittest.main()
