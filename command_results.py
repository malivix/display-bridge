# SPDX-License-Identifier: MIT
"""Bounded command observations; never a hardware execution queue."""
import json
import math
import os
import re

ACTIONS = {'pause', 'pause-for', 'resume', 'audio-manual', 'audio-auto', 'speaker',
           'rotation-manual', 'rotation-auto', 'repair-audio'}
TERMINAL = {'policy-applied', 'verified', 'failed', 'superseded'}
STATES = TERMINAL | {'accepted', 'deferred', 'applying'}


def validate_request(value):
    if not isinstance(value, dict) or set(value) != {'id', 'action', 'created_at'}:
        raise ValueError('Invalid command request metadata')
    if not isinstance(value['id'], str) or not re.fullmatch('[0-9a-f]{32}', value['id']):
        raise ValueError('Invalid command request ID')
    if value['action'] not in ACTIONS:
        raise ValueError('Invalid tracked command')
    stamp = value['created_at']
    try:
        valid = type(stamp) in (int, float) and math.isfinite(stamp) and stamp >= 0
    except OverflowError:
        valid = False
    if not valid:
        raise ValueError('Invalid command request time')
    return value


def outcome(request, status, profile, control, now):
    """Called only after the controller has consumed this request's settings."""
    action = request['action']
    if status == 'state-error':
        return 'deferred', 'Saved settings need attention'
    if action in {'pause', 'pause-for'}:
        if status == 'paused':
            return 'policy-applied', 'Controller acknowledged pause'
        return 'deferred', 'Pause is not active; it may have expired before observation'
    if action in {'speaker', 'rotation-manual', 'audio-manual'}:
        return 'policy-applied', 'Controller accepted the preference; physical effects depend on the active profile'
    if status == 'degraded':
        return 'failed', 'Controller recovery exhausted; inspect health before requesting repair'
    if status == 'ready' and profile not in (None, 'unknown'):
        if action == 'rotation-auto' and profile not in ('extended', 'benq'):
            return 'deferred', 'Waiting for BenQ to show this Mac'
        if control.get('audio_manual_until', 0) > now and action in {'resume', 'repair-audio'}:
            return 'deferred', 'Manual audio override prevents full reconciliation'
        return 'verified', 'Controller reconciliation completed; audibility still requires listening'
    if status in {'recovering', 'settling', 'starting'}:
        return 'applying', 'Waiting for stable inputs and controller reconciliation'
    return 'deferred', 'Waiting for an available, unpaused, known monitor setup'


def publish(path, request, state, detail):
    validate_request(request)
    if state not in STATES or not isinstance(detail, str):
        raise ValueError('Invalid command result')
    try:
        rows = json.loads(path.read_text())
    except FileNotFoundError:
        rows = []
    if not isinstance(rows, list) or len(rows) > 20:
        raise ValueError('Invalid command result history; preserve it for diagnostics')
    for row in rows:
        if not isinstance(row, dict) or set(row) != {'request', 'state', 'detail'}:
            raise ValueError('Invalid command result record')
        validate_request(row['request'])
        if row['state'] not in STATES or not isinstance(row['detail'], str):
            raise ValueError('Invalid command result state')
    ids = [row['request']['id'] for row in rows]
    if len(ids) != len(set(ids)):
        raise ValueError('Duplicate command result IDs')
    existing = next((row for row in rows if row['request']['id'] == request['id']), None)
    if existing and existing['request'] != request:
        raise ValueError('Command ID was reused with different metadata')
    if existing and existing['state'] in TERMINAL:
        return existing
    for row in rows:
        if row['request']['id'] != request['id'] and row['state'] not in TERMINAL:
            row.update(state='superseded', detail='A newer settings request replaced this unfinished request')
    result = {'request': dict(request), 'state': state, 'detail': detail}
    if existing is not None:
        existing.update(result)
    else:
        rows.append(result)
    data = json.dumps(rows[-20:], indent=2) + '\n'
    if not path.exists() or path.read_text() != data:
        temporary = path.with_suffix('.tmp')
        with temporary.open('w') as stream:
            os.chmod(temporary, 0o600)
            stream.write(data)
            stream.flush()
            os.fsync(stream.fileno())
        temporary.replace(path)
    return result
