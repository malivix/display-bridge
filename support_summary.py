# SPDX-License-Identifier: MIT
"""Allowlisted support facts, built independently of private diagnostic bundles."""
import json
import math
from collections import Counter
from release_manifest import VERSION

STATUSES = {'ready','paused','starting','inactive-setup','waiting-for-ddc',
            'waiting-for-known-input','settling','recovering','degraded','state-error',
            'preview-preparing','preview-active','preview-needs-repair','preview-error'}
PROFILES = {'extended','pg','benq','away','unknown'}


def load(path):
    try:
        with path.open('rb') as stream:
            data=stream.read(1_048_577)
        if len(data)>1_048_576:
            return None
        return json.loads(data)
    except (OSError, ValueError):
        return None


def enum(value, allowed):
    return value if isinstance(value, str) and value in allowed else 'unknown'


def boolean(value):
    return value if type(value) is bool else None


def integer(value, maximum):
    return value if type(value) is int and 0 <= value <= maximum else None


def report(root, now):
    raw = {name:load(root/name) for name in ('health.json','control.json','recovery.json','transitions.json')}
    health = raw['health.json'] if isinstance(raw['health.json'],dict) else {}
    control = raw['control.json'] if isinstance(raw['control.json'],dict) else {}
    recovery = raw['recovery.json'] if isinstance(raw['recovery.json'],dict) else {}
    stamp = health.get('updated_at')
    try:
        fresh = type(stamp) in (int,float) and math.isfinite(stamp) and 0 <= now-stamp < 15
    except OverflowError:
        fresh = False
    rows = raw['transitions.json'] if isinstance(raw['transitions.json'],list) else []
    counts = Counter()
    for row in rows[-200:]:
        if isinstance(row,dict):
            profile=enum(row.get('profile'),PROFILES)
            result=enum(row.get('result'),{'ready','failed'})
            counts[(profile,result)]+=1
    rotation=health.get('rotation') if isinstance(health.get('rotation'),dict) else {}
    # Never copy arbitrary keys, error messages, names, timestamps, raw bytes or logs.
    return {
        'schema':1, 'tool_version':VERSION, 'read_only':True,
        'controller':{'status':enum(health.get('status'),STATUSES),
                      'profile':enum(health.get('profile'),PROFILES),'heartbeat_fresh':fresh,
                      'version_matches_tool':health.get('version')==VERSION if 'version' in health else None},
        'preferences':{'pause_requested':boolean(control.get('paused')),
                       'automatic_rotation':boolean(control.get('auto_rotate'))},
        'recovery':{'pending':boolean(recovery.get('pending')),
                    'attempts':integer(recovery.get('attempts'),3),
                    'audio_journal_present':(root/'audio-refresh.json').exists(),
                    'preview_journal_present':(root/'scaling-preview.json').exists()},
        'rotation':{'enabled':boolean(rotation.get('enabled'))},
        'recent_transition_counts':[{'profile':p,'result':r,'count':n} for (p,r),n in sorted(counts.items())],
        'unavailable_sections':[name for name,value in raw.items() if not isinstance(value,list if name=='transitions.json' else dict)],
        'omissions':['device identifiers','input values','device and audio names','local paths',
                     'raw errors','logs','exact timestamps','configuration','raw diagnostic bytes'],
        'limits':'Review before sharing. Counts cover at most 200 retained events. Pause requested is a saved preference, not proof of current pause. Journal presence does not imply unfinished recovery. Nothing was uploaded.'
    }
