#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Local m1ddc input watcher with a public-CoreGraphics layout helper."""
import argparse
import fcntl
import json
import logging
from logging.handlers import RotatingFileHandler
import os
from pathlib import Path
import re
import subprocess
import sys
import time
import uuid
from contextlib import ExitStack
from audio_policy import route as audio_route, preference
from observability import record as save_record, summary, diagnostics

def record(root,event):
    try:save_record(root,event)
    except (OSError,ValueError) as error:LOG.warning("Transition history unavailable: %s",error)
from recovery_state import Recovery
from persisted_state import StateFileError,read_state,validate_control

from release_manifest import VERSION
ROOT = Path.home() / '.config/display-auto'
CONFIG = ROOT / 'config.json'
BASELINE = ROOT / 'baseline.json'
HELPER = Path.home() / '.local/bin/display-layout'
AUDIO = Path.home() / '.local/bin/display-audio'
ROTATE = Path.home() / '.local/bin/display-rotate'
MODE_INFO = Path.home() / '.local/bin/display-mode-info'
INPUTS = {'A': {'pg': 17, 'benq': 19}, 'B': {'pg': 18, 'benq': 15}}
LOG = logging.getLogger('display-auto')
HEALTH = ROOT / 'health.json'
ONCE_TIMEOUT = 15.0
CONTROL = ROOT / 'control.json'
JOURNAL = ROOT / 'audio-refresh.json'

def new_recovery():
    return Recovery(ROOT / 'recovery.json')

def read_control():
    return read_state(CONTROL,validate_control,missing={})

def automation_paused(control, now=None):
    until=control.get('pause_until',0)
    return bool(control.get('paused')) and (not until or until>(time.time() if now is None else now))

def audio_inventory(config):
    if not config.get('audio', {}).get('enabled'):
        return []
    return json.loads(command([AUDIO, 'status']))


def remaining(deadline, maximum):
    if deadline is None:
        return maximum
    value = min(maximum, deadline - time.monotonic())
    if value <= 0:
        raise TimeoutError('One-shot convergence deadline exceeded')
    return value

def acquire_lock(file, timeout):
    deadline = time.monotonic() + timeout
    while True:
        try:
            fcntl.flock(file, fcntl.LOCK_EX | fcntl.LOCK_NB)
            return
        except BlockingIOError:
            if time.monotonic() >= deadline:
                raise TimeoutError('DDC reader is busy; timed out waiting for its lock')
            time.sleep(.02)

class AudioSelectionChanged(RuntimeError):
    pass

def command(args, timeout=5, deadline=None):
    result = subprocess.run([str(x) for x in args], capture_output=True, text=True,
                            timeout=remaining(deadline, timeout))
    if result.returncode==75 and str(args[0])==str(AUDIO):
        raise AudioSelectionChanged(result.stderr.strip())
    if result.returncode:
        raise RuntimeError(f'{Path(str(args[0])).name}: {result.stderr.strip() or result.stdout.strip()}')
    return result.stdout.strip()

def layout(deadline=None):
    return json.loads(command([HELPER, 'status'], deadline=deadline))['screens']

class SetupUnavailable(RuntimeError):
    pass

def capture_identifiers(m1ddc):
    listing=command([m1ddc,'display','list'])
    found={}
    for role,name in [('pg','PG42UQ'),('benq','BenQ RD280UG')]:
        values=re.findall(r'^\[\d+\] '+re.escape(name)+r' \(([A-Fa-f0-9-]+)\)$',listing,re.M)
        if len(values)!=1:raise RuntimeError('Cannot bind exact display identity for '+name)
        found[role]='uuid='+values[0]
    return found

def verify_setup(config, deadline=None):
    screens=layout(deadline)
    keys=[s['key'] for s in screens]
    if len(keys)!=2 or len(set(keys))!=2 or set(keys)!=set(config['keys'].values()):
        raise SetupUnavailable('Saved PG and BenQ pair is not the active two-monitor setup; automation idle')
    if config.get('ddc_identifiers'):
        listing=command([config['m1ddc'],'display','list'],deadline=deadline)
        present=set(re.findall(r'\(([A-Fa-f0-9-]+)\)',listing))
        if not all(value.removeprefix('uuid=') in present for value in config['ddc_identifiers'].values()):
            raise SetupUnavailable('Saved display identities are absent; automation idle')

def read_inputs(config, deadline=None):
    verify_setup(config,deadline)
    values = {}
    ROOT.mkdir(parents=True, exist_ok=True)
    # Status commands and the daemon must not issue DDC requests concurrently.
    with (ROOT / 'ddc.lock').open('a') as lock:
        acquire_lock(lock, remaining(deadline, 2))
        for name in ('pg', 'benq'):
            try:
                text = command([config['m1ddc'], 'display', config.get('ddc_identifiers',{}).get(name,'basic=' + config['keys'][name]), 'get', 'input'], 3, deadline)
            except (RuntimeError, subprocess.TimeoutExpired, OSError) as error:
                raise RuntimeError(f'{name}: {error}') from error
            if not re.fullmatch(r'[0-9]+', text):
                raise RuntimeError(f'{name}: invalid DDC response {text!r}')
            values[name] = int(text)
    return values

def desired(host, inputs):
    if inputs.get('pg') not in (17, 18) or inputs.get('benq') not in (19, 15):
        return 'unknown'
    local = INPUTS[host]
    pg, benq = inputs['pg'] == local['pg'], inputs['benq'] == local['benq']
    return 'extended' if pg and benq else 'pg' if pg else 'benq' if benq else 'away'

class Debounce:
    def __init__(self):
        self.reset()
    def reset(self):
        self.candidate, self.count = None, 0
        self.first_seen, self.confirmed_after = None, None
    def observe(self, value):
        now = time.monotonic()
        if value != self.candidate:
            self.first_seen, self.confirmed_after = now, None
        self.count = min(2, self.count + 1) if value == self.candidate else 1
        self.candidate = value
        if self.count == 2 and self.confirmed_after is None:
            self.confirmed_after = now - self.first_seen
        return self.count == 2

def matches(config, profile, screens):
    saved = {x['key']: x for x in config['baseline']['screens']}
    current = {x['key']: x for x in screens}
    if len(screens) != 2 or set(saved) != set(current):
        return False
    source = config['keys'].get(profile)
    for key, item in current.items():
        if profile == 'extended' or key == source:
            if item.get('mirrorOf'):
                return False
            base = saved[key]
            if base.get('strictMode') and item.get('modeID') != base.get('modeID'):
                return False
            if any(item[k] != base[k] for k in ('width', 'height', 'pixelWidth', 'pixelHeight', 'rotation')):
                return False
            if base.get('ioFlags') is not None and item.get('ioFlags') != base['ioFlags']:
                return False
            if abs(item['hz'] - base['hz']) > 0.2:
                return False
            position = (base['x'], base['y']) if profile == 'extended' else (0, 0)
            if (item['x'], item['y']) != position:
                return False
        elif item.get('mirrorOf') != source:
            return False
    return True

def apply(config, profile, deadline=None):
    if profile in ('away', 'unknown'):
        return False
    if matches(config, profile, layout(deadline)):
        return False
    command([HELPER, 'apply', config.get('active_baseline_path',BASELINE), config['keys'].get(profile, 'extended')], 8, deadline)
    for _ in range(5):
        if matches(config, profile, layout(deadline)):
            return True
        time.sleep(.1)
    raise RuntimeError('Layout readback differs from requested source or saved mode')

def read_rotation(config,profile,deadline=None):
    rotation=config.get('rotation',{})
    if not rotation.get('enabled') or profile not in ('extended','benq'):return None
    with (ROOT/'ddc.lock').open('a') as lock:
        acquire_lock(lock,remaining(deadline,2))
        value=command([config['m1ddc'],'display',config['ddc_identifiers']['benq'],'get','orientation'],3,deadline)
    angle=rotation.get('sensor_map',{}).get(value)
    if angle not in (0,90):raise RuntimeError('BenQ orientation is not calibrated: '+value)
    return angle

def stable_state(config, debounce, state, last, profile, deadline=None):
    if debounce.observe(state):return True
    # Only accelerate a rotation on the already verified input profile. Inputs
    # are still freshly rechecked by apply_rotation before any display write.
    if (not config.get('rotation',{}).get('enabled') or last is None or
        len(last)!=3 or state[:2]!=last[:2] or profile not in ('extended','benq') or
        state[2] not in (0,90) or last[2] not in (0,90) or state[2]==last[2]):return False
    time.sleep(remaining(deadline,.25))
    try:
        confirmed=read_rotation(config,profile,deadline)
    except (RuntimeError,subprocess.TimeoutExpired,OSError):
        debounce.reset();return False
    if confirmed!=state[2]:
        debounce.reset();return False
    return debounce.observe(state)

def select_rotation_baseline(config,angle):
    saved=config['rotation']['baselines'].get(str(int(angle)))
    if not saved:raise RuntimeError('No calibrated baseline for BenQ rotation')
    path=ROOT/'rotation-active.json'
    if config.get('active_baseline_path')!=path or config['baseline']!=saved or not path.exists():
        temporary=path.with_suffix('.tmp');temporary.write_text(json.dumps(saved)+'\n');temporary.replace(path)
    config['baseline']=saved
    config['active_baseline_path']=path

def apply_rotation(config,profile,angle,inputs,deadline=None):
    if not config.get('rotation',{}).get('enabled'):return False
    screens=layout(deadline)
    current=next(s for s in screens if s['key']==config['keys']['benq'])['rotation']
    select_rotation_baseline(config,current)
    if angle is None or profile not in ('extended','benq') or angle==current:return False
    # Only a confirmed local BenQ may rotate. Release mirroring first.
    if any(s.get('mirrorOf') for s in screens):
        confirm_inputs(config,inputs,deadline)
        apply(config,'extended',deadline)
    confirm_inputs(config,inputs,deadline)
    rotation_started=time.monotonic()
    try:
        command([ROTATE,config['keys']['pg'],config['keys']['benq'],str(angle)],6,deadline)
    finally:
        actual=next(s for s in layout(deadline) if s['key']==config['keys']['benq'])['rotation']
        select_rotation_baseline(config,actual)
    if actual!=angle:raise RuntimeError('BenQ rotation readback differs')
    LOG.info('BenQ sensor rotation applied: %s degrees; native call/readback %.2fs',angle,time.monotonic()-rotation_started)
    return True

def capture_audio():
    devices = json.loads(command([AUDIO, 'status']))
    def unique(rows, label):
        if len(rows) != 1:
            raise RuntimeError(f'Cannot uniquely identify {label} audio output')
        return rows[0]['uid']
    return {'enabled': True, 'refresh_on_transition': ['pg','benq'],
            'pg': unique([d for d in devices if d['name'] == 'PG42UQ'], 'PG'),
            'benq': unique([d for d in devices if d['name'] == 'BenQ RD280UG'], 'BenQ'),
            'fallback': unique([d for d in devices if d.get('builtin')], 'built-in')}

def sync_audio(config, profile, deadline=None, refresh=False):
    verify_setup(config,deadline)
    audio=config.get('audio')
    if not audio or not audio.get('enabled') or profile=='unknown':
        return {'state':'disabled' if profile!='unknown' else 'unknown-input'}
    if JOURNAL.exists():
        command([AUDIO,'recover',JOURNAL],timeout=4,deadline=deadline)
    devices=json.loads(command([AUDIO,'status'],deadline=deadline))
    decision=audio_route(audio,profile,devices)
    refreshed=False
    try:
        if decision:
            uid,scope=decision
            expected=next(d['uid'] for d in devices if d.get('default'))
            expected_system=next((d['uid'] for d in devices if d.get('system')),'-')
            command([AUDIO,'select',uid,scope,expected,expected_system],deadline=deadline)
            devices=json.loads(command([AUDIO,'status'],deadline=deadline))
            if audio_route(audio,profile,devices) is not None:
                raise RuntimeError('Audio route readback differs from requested output')
        monitor=preference(audio,profile)
        if monitor not in ('pg','benq'):monitor=None
        selected=next((d for d in devices if d.get('default')),None)
        if (refresh or decision) and monitor in audio.get('refresh_on_transition',[]) and selected and selected['uid']==audio[monitor]:
            if deadline is not None and remaining(deadline,4)<4:
                raise TimeoutError('Insufficient time to safely refresh the audio stream')
            response=json.loads(command([AUDIO,'refresh',audio[monitor],JOURNAL],timeout=4,deadline=deadline))
            if not isinstance(response,dict) or not isinstance(response.get('original_rate'),(float,int)):
                raise RuntimeError('Invalid native audio restoration receipt')
            selected=dict(selected,sampleRate=response['original_rate'])
            refreshed=True
            LOG.info('%s audio stream refreshed after transition; original rate restored',monitor)
    except AudioSelectionChanged:
        devices=json.loads(command([AUDIO,'status'],deadline=deadline))
        selected=next((d for d in devices if d.get('default')),None)
        return {'state':'concurrent-selection-preserved','selected':selected,'refreshed':False}
    managed={audio.get(k) for k in ('pg','benq','fallback')}
    state='managed' if selected and selected['uid'] in managed else 'external-selection-preserved'
    if decision and selected:LOG.info('Audio selected for profile=%s: %s',profile,selected['name'])
    return {'state':state,'selected':selected,'route_changed':bool(decision),'refreshed':refreshed}


def capture(host, m1ddc):
    screens = layout()
    # The shared deployment intentionally targets the two external monitors only.
    if len(screens) != 2 or any(x.get('mirrorOf') for x in screens):
        raise RuntimeError('Capture requires exactly two online, extended displays. Close the laptop lid if applicable.')
    if any(abs(s['hz']-120)>.2 for s in screens):raise RuntimeError('Select fixed 120 Hz on both displays before capture')
    screens=[dict(s,strictMode=True) for s in screens]
    keys = {}
    for name, prefix in [('pg', '1715:17120:'), ('benq', '2513:32963:')]:
        found = [x['key'] for x in screens if x['key'].startswith(prefix)]
        if len(found) != 1:
            raise RuntimeError(f'Cannot uniquely identify {name}; no configuration written')
        keys[name] = found[0]
    config = {'version': VERSION, 'host': host, 'm1ddc': str(Path(m1ddc).resolve()),
              'keys': keys, 'ddc_identifiers':capture_identifiers(m1ddc), 'audio': capture_audio(), 'poll_interval': .25, 'baseline': {'screens': screens}}
    for _ in range(2):
        if read_inputs(config) != INPUTS[host]:
            raise RuntimeError(f'Both monitors must show Mac {host} during capture')
        time.sleep(.25)
    ROOT.mkdir(parents=True, exist_ok=True)
    for path, value in [(BASELINE, config['baseline']), (CONFIG, config)]:
        temporary = path.with_suffix('.tmp')
        temporary.write_text(json.dumps(value, indent=2) + '\n')
        temporary.replace(path)
    print(f'Captured Mac {host} baseline: {CONFIG}')

def write_health(config, status, profile=None, inputs=None, **details):
    value = {'version': VERSION, 'host': config['host'], 'pid': os.getpid(),
             'updated_at': time.time(), 'status': status, 'profile': profile, 'inputs': inputs,
             'audibility': 'requires physical confirmation', 'rotation':config.get('_rotation_status',{'enabled':bool(config.get('rotation',{}).get('enabled'))}), **details}
    request=config.get('_command_request')
    if request:
        from command_results import outcome, publish
        observed_status=status
        if request['action']=='rotation-auto' and (not config.get('rotation',{}).get('enabled') or config.get('_rotation_status',{}).get('sensor_degrees') not in (0,90)):
            observed_status='waiting-for-sensor'
        result_state,result_detail=outcome(request,observed_status,profile,config.get('_command_control',{}),time.time())
        try:
            value['command_result']=publish(ROOT/'command-results.json',request,result_state,result_detail)
        except (OSError,ValueError,TypeError) as error:
            value['command_tracking_error']=f'Command tracking unavailable: {error}'
    recovery=details.get('recovery')
    if recovery:
        value['retry_in_seconds']=None if recovery.get('attempts',0)>=3 else round(max(0,recovery.get('retry_at',0)-time.monotonic()),1)
    temporary = HEALTH.with_suffix('.tmp')
    temporary.write_text(json.dumps(value) + '\n')
    temporary.replace(HEALTH)

def validate_config(config):
    if not isinstance(config,dict):raise RuntimeError('Configuration must be a JSON object')
    if not isinstance(config.get('baseline'),dict) or not isinstance(config.get('keys'),dict):
        raise RuntimeError('Configuration baseline and display keys must be objects')
    if not isinstance(config['baseline'].get('screens'),list) or any(not isinstance(s,dict) for s in config['baseline']['screens']):
        raise RuntimeError('Configuration screens must be a list of objects')
    if any(not isinstance(k,str) or not k for k in config['keys'].values()):
        raise RuntimeError('Display keys must be nonempty strings')
    if config.get('audio') is not None and not isinstance(config['audio'],dict):
        raise RuntimeError('Audio configuration must be an object')
    if config.get('version') != VERSION or config.get('host') not in INPUTS:
        raise RuntimeError('Configuration version or host mismatch; rerun the installer')
    if type(config.get('poll_interval')) not in (int,float) or not .1 <= config['poll_interval'] <= 10:
        raise RuntimeError('Invalid polling interval')
    screens = config.get('baseline', {}).get('screens', [])
    keys = config.get('keys', {})
    if len(screens) != 2 or set(keys) != {'pg','benq'} or len(set(keys.values())) != 2:
        raise RuntimeError('Invalid two-display configuration')
    if set(x.get('key') for x in screens) != set(keys.values()):
        raise RuntimeError('Display keys differ from baseline')
    audio = config.get('audio')
    if audio and audio.get('enabled'):
        if not isinstance(audio.get('refresh_on_transition', []), list) or not set(audio.get('refresh_on_transition', [])).issubset({'pg','benq'}):
            raise RuntimeError('Invalid audio refresh policy')
        uids = [audio.get(k) for k in ('pg','benq','fallback')]
        if any(not isinstance(uid,str) or not uid for uid in uids) or len(set(uids)) != 3:
            raise RuntimeError('Invalid audio device mapping; rerun installer')
    if json.loads(BASELINE.read_text()) != config['baseline']:
        raise RuntimeError('Baseline file differs from configuration; rerun installer to repair')

def startup_config(wait=False):
    """Stay inspectable on invalid startup files; never invent a default config."""
    last_error=None
    while True:
        try:
            config=json.loads(CONFIG.read_text())
            validate_config(config)
            if last_error:LOG.info('Startup configuration repaired; beginning fresh input checks')
            return config
        except (OSError,ValueError,RuntimeError,TypeError,KeyError,AttributeError) as error:
            if not wait:raise
            detail=f'Configuration unavailable: {error}. No hardware changes made. Restore known-good config.json and baseline.json; originals were preserved.'
            if detail!=last_error:LOG.error('%s',detail)
            last_error=detail
            # Do not trust a host role read from damaged or unvalidated data.
            write_health({'host':'?'},'state-error',error=detail)
            time.sleep(2)

class InputsChanged(RuntimeError):
    pass

def confirm_inputs(config, expected, deadline=None):
    if read_inputs(config,deadline) != expected:
        raise InputsChanged('Inputs changed during layout application; superseding old audio work')

def watch(config, once=False, interrupt=None):
    deadline = time.monotonic() + ONCE_TIMEOUT if once else None
    recovery_failed=False
    while True:
        try:
            work=new_recovery()
            if recovery_failed and work.path and not work.path.exists():
                raise StateFileError('Recovery file disappeared after a read error; restore a known-good copy before automation can continue.')
            break
        except StateFileError as error:
            recovery_failed=True
            write_health(config,'state-error',error=str(error))
            if once:raise
            time.sleep(2)
    previous_poll = time.time()
    debounce = Debounce()
    last, last_check, warned = None, 0, None
    inventory, next_inventory = None, 0
    preferences_before=None
    observed_command=None
    control_token, paused_before, manual_before = work.data.get('control_token'), False, False
    status, layout_status, audio_status = 'starting', 'unverified', 'unverified'
    profile, inputs = None, None
    heartbeat = 0
    control_failed=False
    write_health(config, status)
    LOG.info('Started v%s host=%s backend=m1ddc-read-fix2+CoreGraphics', VERSION, config['host'])
    while True:
        if interrupt and interrupt():return
        remaining(deadline, ONCE_TIMEOUT)
        wall, now = time.time(), time.monotonic()
        try:
            if control_failed and not CONTROL.exists():
                raise StateFileError('Control file disappeared after a read error; restore a known-good copy before automation can continue.')
            control = read_control()
        except StateFileError as error:
            if not control_failed:LOG.error('Invalid saved controls: %s',error)
            control_failed=True
            write_health(config,'state-error',error=str(error),recovery=work.data)
            debounce.reset();last=None
            if once:raise
            previous_poll=wall
            time.sleep(2);continue
        if control_failed:
            LOG.info('Saved controls valid again; requiring fresh input confirmation')
            control_failed=False;previous_poll=wall
        request=control.get('command_request')
        config['_command_control']=dict(control)
        config['_command_request']=request
        if request and request['id']!=observed_command:
            observed_command=request['id']
            if request['action'] in ('resume','audio-auto','repair-audio','rotation-auto'):
                # An older Ready heartbeat must never acknowledge a new command.
                last=None;debounce.reset();status='recovering'
                # Repair already has a durable token and must not be replayed on restart.
                if request['action']!='repair-audio' and not work.pending:
                    work.request('settings request requires reconciliation')
        if config.get('audio'):
            config['audio']['preferences']=control.get('speaker_preferences',{})
        paused = automation_paused(control,wall)
        manual_audio = control.get('audio_manual_until', 0) > wall
        preferences=control.get('speaker_preferences',{})
        if preferences_before is not None and preferences != preferences_before:
            work.request('speaker preference changed');last=None
        preferences_before=dict(preferences)
        token = control.get('repair_token')
        if token != control_token:
            if token is not None:
                work.request('manual audio repair')
                last = None
            control_token = token
            work.data['control_token']=token; work.save()
        if paused_before and not paused:
            work.request('automation resumed'); last = None; debounce.reset()
        if manual_before and not manual_audio:
            work.request('automatic audio resumed'); last = None
        paused_before, manual_before = paused, manual_audio
        if wall - previous_poll > 5:
            debounce.reset(); last = None
            # A slow failed operation can itself cause this gap. Do not erase
            # an existing failure budget without an independent recovery event.
            if not work.pending:work.request('wake or polling gap')
            LOG.info('Polling gap detected; fresh inputs and audio recovery required')
        previous_poll = wall
        if paused:
            status='paused'
            if once: raise RuntimeError('Automation paused; resume before one-shot verification')
        else:
            try:
                inputs = read_inputs(config, deadline)
                profile = desired(config['host'], inputs)
                angle=None
                if config.get('rotation',{}).get('enabled') and not control.get('auto_rotate',True):
                    config['_rotation_status']={'enabled':True,'automatic':False,'state':'manual','sensor_degrees':None}
                elif config.get('rotation',{}).get('enabled'):
                    try:
                        angle=read_rotation(config,profile,deadline)
                        config['_rotation_status']={'enabled':True,'automatic':True,'state':'tracking' if angle is not None else 'deferred-until-benq-local','sensor_degrees':angle}
                    except (RuntimeError,subprocess.TimeoutExpired,OSError) as error:
                        config['_rotation_status']={'enabled':True,'state':'sensor-unavailable','error':str(error)}
                        LOG.debug('Rotation sensor unavailable: %s',error)
                state = (inputs['pg'], inputs['benq'])
                if config.get('rotation',{}).get('enabled'):state += (angle,)
            except SetupUnavailable as error:
                debounce.reset();last=None;warned='setup'
                write_health(config,'inactive-setup',error=str(error))
                if once:raise
                time.sleep(max(2,config['poll_interval']));continue
            except (RuntimeError, subprocess.TimeoutExpired, OSError) as error:
                debounce.reset(); last = None; status='waiting-for-ddc'
                if warned != 'ddc':
                    LOG.warning('DDC unavailable; no changes: %s', error)
                    write_health(config, status, error=str(error), recovery=work.data)
                warned='ddc'
                if now >= heartbeat:
                    write_health(config,status,profile,inputs,error=str(error),recovery=work.data)
                    heartbeat=now+2
                if once: raise
                previous_poll=wall+max(0,time.monotonic()-now)
                time.sleep(config['poll_interval']); continue
            if warned == 'setup':
                work.request('saved setup returned');warned=None
            if warned == 'ddc':
                LOG.info('DDC recovered'); warned=None
                if work.pending:work.request('DDC recovered with unfinished work')
            if stable_state(config,debounce,state,last,profile,deadline):
                if work.select(inputs, profile, angle):
                    last=None; layout_status='unverified'; audio_status='pending'
                # Poll availability separately from layout verification. A returning
                # endpoint re-arms exhausted recovery without touching a headset.
                if now >= next_inventory:
                    try:
                        devices=audio_inventory(config)
                        signature=sorted((d['uid'],d.get('id'),bool(d.get('alive'))) for d in devices)
                        if inventory is not None and signature != inventory:
                            work.request('audio device availability changed'); last=None
                        inventory=signature
                    except (RuntimeError, subprocess.TimeoutExpired, OSError, ValueError) as error:
                        if inventory is not None and inventory != []:
                            inventory=[]; work.request('audio inventory unavailable'); last=None
                        LOG.debug('Audio inventory unavailable: %s', error)
                    next_inventory=now+5
                due=state != last or work.pending or now-last_check>=30
                if due and work.eligible(now):
                    started=time.monotonic()
                    reason=work.data.get('reason')
                    try:
                        rotated=apply_rotation(config,profile,angle,inputs,deadline)
                        rotation_finished=time.monotonic()
                        if profile not in ('unknown', 'away'):
                            confirm_inputs(config, inputs, deadline)
                        changed=apply(config, profile, deadline) or rotated
                        layout_finished=time.monotonic()
                        layout_status='unchanged-away' if profile=='away' else 'unknown' if profile=='unknown' else 'verified'
                        if changed and not work.pending: work.request('layout changed')
                        if profile != 'unknown':confirm_inputs(config,inputs,deadline)
                        inputs_finished=time.monotonic()
                        if manual_audio:
                            audio_status='manual override'
                        else:
                            audio_status=sync_audio(config, profile, deadline, refresh=work.pending or bool(changed))
                        finished=time.monotonic()
                        if work.pending or changed:
                            LOG.info('Transition phases: layout=%.2fs input-confirm=%.2fs audio=%.2fs total=%.2fs',layout_finished-started,inputs_finished-layout_finished,finished-inputs_finished,finished-started)
                            seconds={'rotation_check':round(rotation_finished-started,3),'layout_apply':round(layout_finished-rotation_finished,3),'layout':round(layout_finished-started,3),'input_confirmation':round(inputs_finished-layout_finished,3),'audio':round(finished-inputs_finished,3),'total':round(finished-started,3)}
                            if rotated or reason=='input transition':
                                seconds['settling']=round(debounce.confirmed_after,3)
                            record(ROOT,{'version':VERSION,'profile':profile,'result':'ready','inputs':inputs,'reason':reason or ('rotation' if rotated else 'layout changed'),'rotated':rotated,'orientation':angle,'seconds':seconds})
                        work.complete()
                    except InputsChanged as error:
                        debounce.reset();last=None;status='settling'
                        LOG.info('%s',error)
                        if once:remaining(deadline,ONCE_TIMEOUT)
                    except (RuntimeError, subprocess.TimeoutExpired, OSError) as error:
                        work.failed(error, time.monotonic())
                        record(ROOT,{'profile':profile,'result':'failed','error':str(error),'attempt':work.data['attempts']})
                        status='degraded' if work.exhausted else 'recovering'
                        audio_status='pending' if layout_status=='verified' else 'unverified'
                        if warned != str(error): LOG.error('Recovery failed: %s', error)
                        warned=str(error)
                        write_health(config,status,profile,inputs,layout=layout_status,audio=audio_status,recovery=work.data)
                        if once: raise
                    else:
                        status='waiting-for-known-input' if profile=='unknown' else 'ready'
                        if state != last or warned:
                            LOG.info('PG=%s BenQ=%s profile=%s checked in %.2fs',*state[:2],profile,time.monotonic()-started)
                        last,last_check,warned=state,time.monotonic(),None
                        write_health(config,status,profile,inputs,layout=layout_status,audio=audio_status,recovery=work.data)
                        if once:
                            if profile=='unknown':raise RuntimeError('Unknown monitor input combination; profile was not verified')
                            return
                elif work.exhausted:
                    status='degraded'
                    if once:raise RuntimeError('Recovery exhausted; request repair-audio to retry')
        if now >= heartbeat:
            write_health(config,status,profile,inputs,layout=layout_status,audio=audio_status,recovery=work.data,
                         audio_journal_pending=JOURNAL.exists())
            heartbeat=now+2
        # Exclude time spent in our own native operations from wake-gap detection.
        previous_poll=wall+max(0,time.monotonic()-now)
        time.sleep(config['poll_interval'])

def control_command(action, minutes, profile=None, speaker=None):
    from preview_service import mutation_guard
    from types import SimpleNamespace
    with mutation_guard(SimpleNamespace(**globals())):
        ROOT.mkdir(parents=True,exist_ok=True)
        with (ROOT/'control.lock').open('a') as lock:
            acquire_lock(lock,2)
            control=read_control()
            if action=='speaker':
                if profile not in ('extended','pg','benq','away') or speaker not in ('pg','benq','fallback','preserve'):raise RuntimeError('Invalid profile or speaker')
                control.setdefault('speaker_preferences',{})[profile]=speaker
            elif action=='rotation-auto':control['auto_rotate']=True
            elif action=='rotation-manual':control['auto_rotate']=False
            elif action=='pause':control.update(paused=True,pause_until=0)
            elif action=='pause-for':
                if not 1<=minutes<=1440:raise RuntimeError('Pause duration must be 1–1440 minutes')
                control.update(paused=True,pause_until=time.time()+minutes*60)
            elif action=='resume':control.update(paused=False,pause_until=0)
            elif action=='audio-manual':
                if not 1 <= minutes <= 1440:raise RuntimeError('Override duration must be 1–1440 minutes')
                control['audio_manual_until']=time.time()+minutes*60
            elif action=='audio-auto':control['audio_manual_until']=0
            elif action=='repair-audio':
                if automation_paused(control) or control.get('audio_manual_until',0)>time.time():
                    raise RuntimeError('Resume automation and automatic audio before requesting repair')
                control['repair_token']=str(time.time_ns())
            control['command_request']={'id':uuid.uuid4().hex,'action':action,'created_at':time.time()}
            validate_control(control)
            temporary=CONTROL.with_suffix('.tmp')
            temporary.write_text(json.dumps(control)+'\n');temporary.replace(CONTROL)
        print(json.dumps({'requested':action,'request_id':control['command_request']['id'],'control':control,'note':'Applied by the running controller after its current operation'},indent=2))

def main():
    with ExitStack() as resources:
        run_main(resources)

def run_main(resources):
    parser = argparse.ArgumentParser()
    parser.add_argument('action', choices=['capture', 'check', 'run', 'once', 'test-layouts', 'restore','status','pause','pause-for','resume','repair-audio','audio-manual','audio-auto','speaker','diagnostics','support-summary','history','hidpi','doctor','display-info','ddc-history','monitor-adjust','monitor-settings','preview-options','preview-start','preview-keep','preview-revert','preview-repair','rotation-auto','rotation-manual'])
    parser.add_argument('--host', choices=['A', 'B'])
    parser.add_argument('--m1ddc', default=str(Path.home() / '.local/bin/display-ddc'))
    parser.add_argument('--minutes',type=int,default=30)
    parser.add_argument('--profile',choices=['extended','pg','benq','away'])
    parser.add_argument('--speaker',choices=['pg','benq','fallback','preserve'])
    parser.add_argument('--monitor',choices=['pg','benq'])
    parser.add_argument('--feature',choices=['luminance','volume'])
    parser.add_argument('--step',type=int,choices=[-5,5])
    parser.add_argument('--size',choices=['larger','current','more-space'])
    parser.add_argument('--token')
    parser.add_argument('--fingerprint')
    args = parser.parse_args()
    if args.action=='preview-options':
        from types import SimpleNamespace
        from preview_service import options
        print(json.dumps(options(SimpleNamespace(**globals()))));return
    if args.action in ('preview-start','preview-keep','preview-revert','preview-repair'):
        from types import SimpleNamespace
        from preview_service import enqueue
        print(json.dumps(enqueue(SimpleNamespace(**globals()),args.action.removeprefix('preview-'),args.size,args.token,args.fingerprint)));return
    if args.action in ('monitor-adjust','monitor-settings'):
        if args.action=='monitor-adjust':
            from preview_service import mutation_guard
            resources.enter_context(mutation_guard(__import__('types').SimpleNamespace(**globals())))
        from monitor_controls import adjust,inspect
        if args.monitor is None:parser.error('--monitor is required')
        if args.action=='monitor-adjust' and (args.feature is None or args.step is None):parser.error('--feature and --step are required')
        config=json.loads(CONFIG.read_text());validate_config(config)
        if args.action=='monitor-adjust' and automation_paused(read_control()):raise RuntimeError('Resume automation before using monitor controls')
        with (ROOT/'maintenance.lock').open('a') as maintenance, (ROOT/'ddc.lock').open('a') as lock:
            try:fcntl.flock(maintenance,fcntl.LOCK_SH | fcntl.LOCK_NB)
            except BlockingIOError:raise RuntimeError('Installation in progress; try again later')
            verify_setup(config);acquire_lock(lock,2)
            def request(action,feature,value=None):
                args=[config['m1ddc'],'display',config['ddc_identifiers'][args_monitor],action,feature]
                if value is not None:args.append(str(value))
                result=command(args,3)
                # Explicit OSD writes can be ignored when issued back-to-back.
                # Keep the shared DDC lock through the bounded settling interval.
                if action=='set':time.sleep(2)
                return result
            args_monitor=args.monitor
            result=inspect(config,args.monitor,request) if args.action=='monitor-settings' else adjust(config,args.monitor,args.feature,args.step,request)
        print(json.dumps(result));return
    if args.action=='display-info':
        from display_snapshot import report
        with (ROOT/'maintenance.lock').open('a') as maintenance:
            try:fcntl.flock(maintenance,fcntl.LOCK_SH|fcntl.LOCK_NB)
            except BlockingIOError:raise RuntimeError('Installation in progress; try again later')
            config=startup_config()
            inputs=read_inputs(config)
            first=json.loads(command([MODE_INFO,'status']))
            second=json.loads(command([MODE_INFO,'status']))
            if read_inputs(config)!=inputs:raise RuntimeError('Inputs changed during inspection; refresh after switching settles')
            snapshot=report(config,inputs,first,second)
            snapshot['observed_at']=time.time()
            print(json.dumps(snapshot))
        return
    if args.action=='hidpi':
        from hidpi_report import analyze
        print(json.dumps(analyze(json.loads(command([HELPER,'modes']))),indent=2));return
    if args.action=='support-summary':
        from support_summary import report
        print(json.dumps(report(ROOT,time.time()),indent=2));return
    if args.action=='diagnostics':
        print(diagnostics(ROOT,AUDIO.parent));return
    if args.action=='ddc-history':
        from ddc_log_report import summarize
        log=Path.home()/'Library/Logs/display-auto-v2.log'
        print(json.dumps(summarize(log.read_text(errors='replace')),indent=2));return
    if args.action=='history':
        print(json.dumps(summary(ROOT),indent=2));return
    if args.action=='doctor':
        from health_check import report
        print(json.dumps(report(ROOT,AUDIO.parent,VERSION,validate_config,read_inputs,lambda:json.loads(command([MODE_INFO,'status']))),indent=2));return
    if args.action in ('pause','pause-for','resume','repair-audio','audio-manual','audio-auto','speaker','rotation-auto','rotation-manual'):
        control_command(args.action,args.minutes,args.profile,args.speaker);return
    if args.action=='status':
        status=json.loads(HEALTH.read_text()) if HEALTH.exists() else {'status':'not started'}
        status['heartbeat_age_seconds']=round(time.time()-status.get('updated_at',time.time()),1)
        try:
            pid=status.get('pid',0)
            if not isinstance(pid,int) or pid<=0:raise ValueError('No controller PID')
            os.kill(pid,0);status['process_alive']=True
        except (OSError,ValueError):status['process_alive']=False
        try:
            status['control']=read_control()
            status['automation_paused']=automation_paused(status['control'])
        except StateFileError as error:
            status['control_error']=str(error);status['automation_paused']=True
        try:status['audio_journal']=json.loads(JOURNAL.read_text()) if JOURNAL.exists() else None
        except (OSError,ValueError) as error:status['audio_journal_error']=str(error)
        print(json.dumps(status,indent=2));return
    ROOT.mkdir(parents=True, exist_ok=True)
    maintenance = resources.enter_context((ROOT/'maintenance.lock').open('a'))
    if args.action != 'check' and os.environ.get('DISPLAY_AUTO_INSTALLER_PID') != str(os.getppid()):
        try:fcntl.flock(maintenance,fcntl.LOCK_SH | fcntl.LOCK_NB)
        except BlockingIOError:raise RuntimeError('Installation in progress; try again when it finishes')
    if args.action in ('capture','restore','test-layouts','once'):
        from preview_service import mutation_guard
        from types import SimpleNamespace
        resources.enter_context(mutation_guard(SimpleNamespace(**globals())))
    lock = resources.enter_context((ROOT / 'controller.lock').open('a'))
    if args.action != 'check':
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            raise RuntimeError('Another controller is running. Stop the LaunchAgent first.')
    log_path = Path.home() / 'Library/Logs/display-auto-v2.log'
    log_path.parent.mkdir(parents=True, exist_ok=True)
    file_log = RotatingFileHandler(log_path, maxBytes=1_000_000, backupCount=3)
    resources.callback(file_log.close)
    resources.callback(LOG.removeHandler,file_log)
    formatter = logging.Formatter('%(asctime)s %(levelname)s %(message)s')
    file_log.setFormatter(formatter)
    console = logging.StreamHandler()
    resources.callback(LOG.removeHandler,console)
    console.setFormatter(formatter)
    LOG.setLevel(logging.INFO)
    LOG.addHandler(file_log)
    if args.action != 'run' or sys.stderr.isatty():
        LOG.addHandler(console)
    if args.action == 'capture':
        if args.host is None:
            parser.error('capture requires --host A or --host B')
        capture(args.host, args.m1ddc)
        return
    if args.action=='run':
        from types import SimpleNamespace
        from preview_service import Service
        service=Service(SimpleNamespace(**globals()))
        while True:
            service.drain()
            config=startup_config(wait=True)
            watch(config,interrupt=service.pending)
    config = startup_config()
    if config.get('audio') and args.action in ('restore','test-layouts'):
        config['audio']['preferences']=read_control().get('speaker_preferences',{})
    if args.action in ('restore','test-layouts'):
        confirm_inputs(config,INPUTS[config['host']])
    if config.get('rotation',{}).get('enabled') and args.action in ('restore','test-layouts'):
        actual=next(s for s in layout() if s['key']==config['keys']['benq'])['rotation']
        select_rotation_baseline(config,actual)
    if args.action == 'check':
        inputs = read_inputs(config)
        profile = desired(config['host'], inputs)
        print(json.dumps({'version': VERSION, 'host': config['host'], 'inputs': inputs,
                          'profile': profile, 'screens': layout(),
                          'audio': json.loads(command([AUDIO, 'status'])) if config.get('audio') else None}, indent=2))
    elif args.action == 'restore':
        confirm_inputs(config,INPUTS[config['host']])
        changed = apply(config, 'extended')
        confirm_inputs(config,INPUTS[config['host']])
        sync_audio(config, 'extended', refresh=changed)
    elif args.action == 'test-layouts':
        if read_inputs(config) != INPUTS[config['host']]:
            raise RuntimeError('Both displays must show this Mac for the layout test')
        try:
            for profile in ['pg', 'extended', 'benq', 'extended']:
                start = time.monotonic()
                changed = apply(config, profile)
                sync_audio(config, profile, refresh=changed)
                LOG.info('PASS layout=%s %.2fs', profile, time.monotonic()-start)
        finally:
            changed = apply(config, 'extended')
            sync_audio(config, 'extended', refresh=changed)
    else:
        watch(config, once=args.action == 'once')

if __name__ == '__main__':
    try:
        main()
    except KeyboardInterrupt:
        pass
    except Exception as error:
        print(f'ERROR: {error}', file=sys.stderr)
        sys.exit(1)
