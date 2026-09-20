#!/usr/bin/env python3
"""Opt-in physical fault test; pauses the controller and restores it in finally."""
import argparse,contextlib,json,os,signal,subprocess,tempfile,time
from pathlib import Path

def run(helper,*args,check=True):
    return subprocess.run([str(helper),*map(str,args)],capture_output=True,text=True,timeout=6,check=check)
def main():
    parser=argparse.ArgumentParser();parser.add_argument('--helper',type=Path,required=True);parser.add_argument('--fault-helper',type=Path,required=True);args=parser.parse_args()
    rows=json.loads(run(args.helper,'status').stdout)
    pg=next(d for d in rows if d['name']=='PG42UQ');original=pg['sampleRate']
    # Guard checks are read-only: no stale plan may change selection or rate.
    selected=next(d for d in rows if d['default'])
    alerts=next(d for d in rows if d['system'])
    assert run(args.helper,'select',selected['uid'],'both','stale-selection',alerts['uid'],check=False).returncode==75
    assert run(args.helper,'select',selected['uid'],'both',selected['uid'],'stale-selection',check=False).returncode==75
    inactive=next(d for d in rows if not d['default'] and d['name']=='BenQ RD280UG')
    with tempfile.TemporaryDirectory() as temp:
        journal=Path(temp)/'inactive.json'
        assert run(args.helper,'refresh',inactive['uid'],journal,check=False).returncode==75
        assert not journal.exists()
    assert json.loads(run(args.helper,'status').stdout)==rows
    print('PASS stale speaker/alert plans and inactive refresh rejected without changes',flush=True)
    service=f'gui/{os.getuid()}/io.github.display-bridge';plist=Path.home()/'Library/LaunchAgents/io.github.display-bridge.plist'
    running=subprocess.run(['launchctl','print',service],capture_output=True).returncode==0
    if running:subprocess.run(['launchctl','bootout',service],check=True)
    try:
        # Retain the directory on failure so a pending restoration is never deleted.
        with contextlib.nullcontext(tempfile.mkdtemp(prefix='audio-journal-test-')) as temp:
            journal=Path(temp)/'pending.json';child=None
            try:
                child=subprocess.Popen([str(args.fault_helper),'refresh',pg['uid'],str(journal)],stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True)
                deadline=time.monotonic()+5
                while time.monotonic()<deadline:
                    pid,status=os.waitpid(child.pid,os.WNOHANG|os.WUNTRACED)
                    if pid and os.WIFSTOPPED(status):break
                    if pid:raise RuntimeError('Fault helper exited before the interruption point')
                    time.sleep(.02)
                else:raise RuntimeError('Fault helper did not reach interruption point')
                record=json.loads(journal.read_text());assert record['original']==original
                os.kill(child.pid,signal.SIGKILL);child.communicate(timeout=3)
                interrupted=next(d for d in json.loads(run(args.helper,'status').stdout) if d['uid']==pg['uid'])
                assert interrupted['sampleRate']==record['alternate']
                run(args.helper,'recover',journal)
                restored=next(d for d in json.loads(run(args.helper,'status').stdout) if d['uid']==pg['uid'])
                assert restored['sampleRate']==original and not journal.exists()
                print('PASS forced termination at alternate rate; new process restores original rate',flush=True)
                journal.write_text(json.dumps(dict(uid='missing-device',original=48000,alternate=44100)))
                assert run(args.helper,'recover',journal,check=False).returncode!=0 and journal.exists()
                journal.unlink()
                journal.write_text('{}');assert run(args.helper,'recover',journal,check=False).returncode!=0
                journal.unlink();print('PASS missing device and malformed journal fail without clearing evidence',flush=True)
            finally:
                if child and child.poll() is None:child.kill();child.communicate(timeout=3)
                if journal.exists():
                    result=run(args.helper,'recover',journal,check=False)
                    if result.returncode:raise RuntimeError(f'Journal recovery still pending at {journal}: '+result.stderr)
    finally:
        if running:subprocess.run(['launchctl','bootstrap',f'gui/{os.getuid()}',str(plist)],check=True)
if __name__=='__main__':main()
