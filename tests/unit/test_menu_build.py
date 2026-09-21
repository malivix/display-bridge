import json
import plistlib
import subprocess
import tempfile
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch

from menu_build import build_menu


class MenuBuild(unittest.TestCase):
    def exercise(self, identity=None, metadata_ok=True, team=True, fail_sign=False, race=False):
        with tempfile.TemporaryDirectory() as folder:
            root=Path(folder);staged=root/'menu.app';calls=[]
            tools=(Path('/toolchain/usr/bin/swiftc'),'/toolchain/usr/bin/metadata',Path('/toolchain'),['AppIntent'],'TEST')
            def run(args,**kwargs):
                calls.append(args)
                if args[0]=='xcrun':return SimpleNamespace(stdout='/sdk',stderr='',returncode=0)
                if args[0].endswith('metadata'):
                    path=Path(args[args.index('--output')+1])/'Metadata.appintents'
                    path.mkdir()
                    fields=['freshness','controller','arrangement','pauseRequest','recovery','ageSeconds']
                    data={'actions':{'GetDisplayBridgeStatus':{}},'entities':{'DisplayBridgeStatusResult':{'properties':[{'identifier':v} for v in fields]}},'autoShortcuts':[{}]}
                    if not metadata_ok:data['actions']={}
                    (path/'extract.actionsdata').write_text(json.dumps(data))
                if args[0]=='codesign' and '--sign' in args and fail_sign:
                    raise subprocess.CalledProcessError(1,args)
                return SimpleNamespace(stdout='',stderr='TeamIdentifier=TESTTEAM01\n' if team else 'TeamIdentifier=not set\n',returncode=0)
            values=['stable','changed'] if race else ['stable','stable']
            with patch('menu_build.shortcuts_tools',return_value=tools) as inspect,patch('menu_build.source_fingerprint',side_effect=values):
                if not metadata_ok or not team or fail_sign or race:
                    with self.assertRaises(RuntimeError) as failure:build_menu(root,staged,run,identity)
                    if fail_sign:self.assertNotIn(identity,str(failure.exception))
                    if not metadata_ok or race:self.assertFalse(any(a[0]=='codesign' for a in calls))
                else:
                    info=build_menu(root,staged,run,identity)
                    self.assertEqual(info['DisplayBridgeShortcutsPackaged'],identity is not None)
                    self.assertEqual(plistlib.loads((staged/'Contents/Info.plist').read_bytes()),info)
                    self.assertEqual(inspect.call_count,int(identity is not None))
                    sign=next(i for i,a in enumerate(calls) if '--sign' in a)
                    self.assertTrue(any('--verify' in a for a in calls[sign+1:]))
                    if identity:
                        metadata=next(i for i,a in enumerate(calls) if a[0].endswith('metadata'))
                        self.assertLess(metadata,sign)
                    else:self.assertFalse(any('--output' in a for a in calls))
    def test_default_build_needs_no_metadata_tools(self):self.exercise()
    def test_signed_build_packages_metadata_before_signing(self):self.exercise(identity='synthetic-development-identity')
    def test_missing_metadata_blocks_signing(self):self.exercise(identity='synthetic-development-identity',metadata_ok=False)
    def test_missing_team_blocks_completed_build(self):self.exercise(identity='synthetic-development-identity',team=False)
    def test_signing_error_does_not_echo_identity(self):self.exercise(identity='synthetic-development-identity',fail_sign=True)
    def test_source_change_blocks_signing(self):self.exercise(race=True)
    def test_explicit_invalid_identity_does_not_run_tools(self):
        for identity in ['', ' ', '-', 42]:
            calls=[]
            with self.assertRaises(RuntimeError):build_menu(Path('.'),Path('unused'),lambda *a,**k:calls.append(a),identity)
            self.assertEqual(calls,[])


if __name__=='__main__':unittest.main()
