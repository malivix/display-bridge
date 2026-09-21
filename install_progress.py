# SPDX-License-Identifier: MIT
"""Installer-owned observations, not an execution or recovery journal."""
import json
import math
import os
from pathlib import Path
import secrets
import subprocess
import sys
import tempfile
import time

PHASES = ('preparing', 'building', 'backing-up', 'stopping-controller', 'activating',
          'checking-configuration', 'starting-controller', 'installing-menu',
          'recovering', 'recovery-finished', 'finished')
LIMITS = ('Stored installer observations only. Process presence does not establish process '
          'identity or progress. Recovery completion does not verify physical behavior. '
          'This report never resumes or retries installation.')


class InstallProgress:
    """Use under install.lock; progress-write failures must not interrupt recovery."""
    def __init__(self, root, host):
        self.path = Path(root) / 'install-progress.json'
        self.data = dict(schema=1, attempt=secrets.token_hex(16), host=host, pid=os.getpid(),
                         started_at=time.time(), status='running', phase='preparing',
                         recovery='not-needed')
        self.warned = False

    def write(self, strict=False):
        temporary = None
        self.data['updated_at'] = time.time()
        try:
            if self.path.is_symlink():
                raise OSError('Progress destination is a symlink')
            with tempfile.NamedTemporaryFile(mode='w', dir=self.path.parent,
                                             prefix='.install-progress-', delete=False) as stream:
                temporary = Path(stream.name)
                json.dump(self.data, stream, allow_nan=False)
                stream.write('\n')
                stream.flush()
                os.fsync(stream.fileno())
            temporary.replace(self.path)
        except OSError:
            if strict:
                raise
            if not self.warned:
                self.warned = True
                try:
                    print('Installer progress could not be saved; inspect the command result and private logs.', file=sys.stderr)
                except (OSError, ValueError):
                    pass
        finally:
            if temporary is not None:
                try:
                    temporary.unlink(missing_ok=True)
                except OSError:
                    pass

    def __enter__(self):
        self.write(strict=True)
        return self

    def phase(self, phase, recovery=None):
        if phase not in PHASES:
            raise ValueError('Unrecognized installation phase')
        self.data['phase'] = phase
        if recovery is not None:
            if recovery not in ('not-needed', 'pending', 'completed-unverified'):
                raise ValueError('Unrecognized installation recovery state')
            self.data['recovery'] = recovery
        self.write()

    def succeed(self):
        self.data.update(status='completed', phase='finished', recovery='not-needed')
        self.write()

    def __exit__(self, kind, error, traceback):
        if kind is not None or self.data['status'] != 'completed':
            reason = ('interrupted' if isinstance(error, KeyboardInterrupt) else
                      'command-timeout' if isinstance(error, subprocess.TimeoutExpired) else
                      'installer-error' if error is not None else 'outcome-unavailable')
            self.data.update(status='failed' if error is not None else 'incomplete', reason=reason)
            self.write()
        return False


def read_progress(root, host=None):
    from observability import read_json
    try:
        data = read_json(Path(root) / 'install-progress.json')
    except RecursionError:
        data = None
    unavailable = dict(read_only=True, available=False, limits=LIMITS)
    if host not in (None, 'A', 'B') or not isinstance(data, dict):
        return unavailable
    def stamp(value):
        return type(value) in (int, float) and 0 <= value <= time.time() and math.isfinite(value)
    if (type(data.get('schema')) is not int or data['schema'] != 1 or data.get('host') not in ('A','B') or
        (host is not None and data.get('host') != host) or
        type(data.get('pid')) is not int or not 0 < data['pid'] <= 2**31-1 or
        data.get('status') not in ('running', 'completed', 'failed', 'incomplete') or
        data.get('phase') not in PHASES or
        data.get('recovery') not in ('not-needed', 'pending', 'completed-unverified') or
        not isinstance(data.get('attempt'), str) or len(data['attempt']) != 32 or
        any(c not in '0123456789abcdef' for c in data['attempt']) or
        not stamp(data.get('started_at')) or not stamp(data.get('updated_at')) or
        data['updated_at'] < data['started_at'] or
        (data['status']=='completed' and (data['phase']!='finished' or data['recovery']!='not-needed'))):
        return unavailable
    result = {key:data[key] for key in ('schema','attempt','host','pid','started_at','updated_at','status','phase','recovery')}
    result.update(read_only=True, available=True, limits=LIMITS)
    if data.get('reason') in ('interrupted','command-timeout','installer-error','outcome-unavailable'):
        result['reason'] = data['reason']
    if result['status'] == 'running':
        try:
            os.kill(result['pid'], 0)
            result['process_observation'] = 'present'
        except ProcessLookupError:
            result['process_observation'] = 'not-found'
        except OSError:
            result['process_observation'] = 'unknown'
    return result
