#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Restore an installer snapshot, then converge against current physical inputs."""
import datetime,fcntl,json,os,subprocess,sys,time
from pathlib import Path
from deployment import snapshot,restore

def lock_bounded(file):
    deadline=time.monotonic()+8
    while True:
        try:fcntl.flock(file,fcntl.LOCK_EX|fcntl.LOCK_NB);return
        except BlockingIOError:
            if time.monotonic()>=deadline:raise RuntimeError('Controller has not stopped; rollback not applied')
            time.sleep(.05)
def run(args,**kwargs):return subprocess.run(args,timeout=25,**kwargs)
def main():
    root=Path.home()/'.config/display-auto'
    if len(sys.argv)!=2:raise RuntimeError('Usage: python3 rollback.py BACKUP_TIMESTAMP')
    backup=(root/'backups'/sys.argv[1]).resolve()
    if backup.parent!=(root/'backups').resolve():raise RuntimeError('Use a timestamp from the local backups directory')
    metadata=json.loads((backup/'metadata.json').read_text())
    service=f'gui/{os.getuid()}/io.github.display-bridge';plist=Path.home()/'Library/LaunchAgents/io.github.display-bridge.plist'
    with (root/'install.lock').open('a') as install,(root/'maintenance.lock').open('a') as maintenance,(root/'controller.lock').open('a') as controller:
        fcntl.flock(install,fcntl.LOCK_EX|fcntl.LOCK_NB)
        from preview_service import unresolved
        if unresolved(root):raise RuntimeError('Finish scaling preview recovery before rollback')
        running=run(['launchctl','print',service],capture_output=True).returncode==0
        if running:run(['launchctl','bootout',service],check=True)
        undo=None
        try:
            lock_bounded(maintenance);lock_bounded(controller)
            journal=root/'audio-refresh.json'
            if journal.exists():run([str(Path.home()/'.local/bin/display-audio'),'recover',str(journal)],check=True)
            undo=root/'backups'/('before-rollback-'+datetime.datetime.now().strftime('%Y%m%d-%H%M%S-%f'))
            snapshot([Path(x['path']) for x in metadata['files']],undo,root/'current')
            restore(backup)
            fcntl.flock(controller,fcntl.LOCK_UN)
            env=dict(os.environ,DISPLAY_AUTO_INSTALLER_PID=str(os.getpid()))
            run([str(Path.home()/'.local/bin/display-auto.sh'),'once'],env=env,check=True)
        except BaseException:
            if undo:restore(undo)
            raise
        finally:
            fcntl.flock(controller,fcntl.LOCK_UN);fcntl.flock(maintenance,fcntl.LOCK_UN)
            if running:run(['launchctl','bootstrap',f'gui/{os.getuid()}',str(plist)],check=True)
    print(f'Restored {backup.name}; current physical inputs were verified. Undo snapshot: {undo}')
if __name__=='__main__':main()
