# SPDX-License-Identifier: MIT
"""Validate saved controls/recovery without replacing damaged evidence."""
import json
import math


class StateFileError(RuntimeError):
    pass


def number(value):
    try:return type(value) in (int,float) and math.isfinite(value) and value>=0
    except OverflowError:return False


def validate_control(value):
    if not isinstance(value,dict):raise ValueError('expected an object')
    for key in ('paused','auto_rotate'):
        if key in value and type(value[key]) is not bool:raise ValueError(f'{key} must be true or false')
    for key in ('pause_until','audio_manual_until'):
        if key in value and not number(value[key]):raise ValueError(f'{key} must be a finite nonnegative timestamp')
    if 'repair_token' in value and not isinstance(value['repair_token'],str):raise ValueError('invalid repair token')
    if 'command_request' in value:
        from command_results import validate_request
        validate_request(value['command_request'])
    prefs=value.get('speaker_preferences',{})
    if not isinstance(prefs,dict) or not set(prefs).issubset({'extended','pg','benq','away'}):raise ValueError('invalid speaker profile')
    if any(v not in ('pg','benq','fallback','preserve') for v in prefs.values()):raise ValueError('invalid speaker preference')
    return value


def validate_recovery(value):
    required={'state','profile','pending','attempts','retry_at'}
    if not isinstance(value,dict) or not required.issubset(value):raise ValueError('incomplete recovery record')
    state=value['state']
    if state is not None and (not isinstance(state,list) or len(state)!=2 or any(type(n) is not int or not 0<=n<=65535 for n in state)):raise ValueError('invalid input state')
    if value['profile'] not in (None,'extended','pg','benq','away','unknown'):raise ValueError('invalid recovery profile')
    if type(value['pending']) is not bool:raise ValueError('pending must be true or false')
    if type(value['attempts']) is not int or not 0<=value['attempts']<=3:raise ValueError('invalid recovery attempt count')
    if not value['pending'] and value['attempts']!=0:raise ValueError('completed recovery still has failed attempts')
    if not number(value['retry_at']):raise ValueError('invalid retry deadline')
    angle=value.get('orientation')
    if angle is not None and (type(angle) not in (float,int) or angle not in (0,90)):raise ValueError('invalid recovery orientation')
    for key in ('reason','error','control_token'):
        if value.get(key) is not None and not isinstance(value[key],str):raise ValueError(f'invalid {key}')
    return value


def read_state(path,validator,missing=None):
    try:
        value=json.loads(path.read_text())
        return validator(value)
    except FileNotFoundError:
        return missing
    except (OSError,ValueError,TypeError) as error:
        raise StateFileError(f'{path.name}: {error}. Automation is stopped; the file was not changed. Save diagnostics and restore a known-good copy.') from error
