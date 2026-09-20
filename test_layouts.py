#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Opt-in live layout regression. Stop the service; both monitors should be local."""
import argparse
import json
from pathlib import Path
import subprocess
import tempfile
import time


def run_suite(helper, baseline):
    saved = json.loads(baseline.read_text())
    keys = [x['key'] for x in saved['screens']]
    def run(*args):
        return subprocess.run([str(helper), *map(str,args)], capture_output=True,text=True,timeout=10)
    def status():
        result = run('status')
        result.check_returncode()
        return sorted(json.loads(result.stdout)['screens'], key=lambda x:x['key'])
    def apply(profile):
        start = time.monotonic()
        result = run('apply',baseline,profile)
        if result.returncode: raise RuntimeError(result.stderr)
        actual = status()
        for item in actual:
            original = next(x for x in saved['screens'] if x['key']==item['key'])
            if profile=='extended' or item['key']==profile:
                assert not item.get('mirrorOf'), actual
                for field in ['width','height','pixelWidth','pixelHeight','rotation','hz']:
                    assert item[field]==original[field], (field,item,original)
                assert (item['x'],item['y']) == ((original['x'],original['y']) if profile=='extended' else (0,0))
            else: assert item.get('mirrorOf')==profile, actual
        print(f'PASS profile={profile} {time.monotonic()-start:.2f}s',flush=True)
    try:
        for profile in [keys[0],'extended',keys[1],'extended',keys[0]]: apply(profile)
        before = status()
        with tempfile.TemporaryDirectory() as temporary:
            changes = [('missing-mode',lambda b:b['screens'][0].update(width=12345)),
                       ('rotation',lambda b:b['screens'][0].update(rotation=123)),
                       ('topology',lambda b:b['screens'].pop())]
            for name,mutate in changes:
                bad=json.loads(baseline.read_text()); mutate(bad)
                path=Path(temporary)/(name+'.json'); path.write_text(json.dumps(bad))
                result=run('apply',path,keys[0]); assert result.returncode!=0,name
                assert status()==before,name+' changed the layout'
                print('PASS rejects without changing current mirror:',name,flush=True)
    finally: apply('extended')

if __name__=='__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('--helper',type=Path,required=True)
    parser.add_argument('--baseline',type=Path,required=True)
    args=parser.parse_args()
    run_suite(args.helper.resolve(),args.baseline.resolve())
