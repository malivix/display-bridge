# SPDX-License-Identifier: MIT
"""Read-only local health checks. Never repairs, writes settings, or uploads data."""
import hashlib
import json
import os
import stat
import time
from release_manifest import RUNTIME_MODULES, HELPER_HASH_FIELDS
from persisted_state import validate_control,validate_recovery
from display_snapshot import saved_layout
import size_presets


def mode_checks(config,inputs,metadata):
    """Compare only displays currently local; never judge the other Mac's screen."""
    result=[]
    local={'A':{'pg':17,'benq':19},'B':{'pg':18,'benq':15}}[config['host']]
    rows=metadata.get('displays',[])
    if not isinstance(rows,list):raise ValueError('Invalid mode inventory')
    for role,label in (('pg','PG'),('benq','BenQ')):
        if inputs[role]!=local[role]:continue
        matches=[r for r in rows if isinstance(r,dict) and r.get('key')==config['keys'][role]]
        problems=[]
        if len(matches)!=1:
            result.append({'name':label+' mode','status':'warning','detail':'Mode identity missing or ambiguous.','action':'Retry after the displays settle; do not substitute another monitor.'});continue
        row=matches[0]
        baseline=saved_layout(config,rows)
        saved=next((s for s in baseline['screens'] if s['key']==config['keys'][role]),None) if baseline else None
        if not saved or any(row.get(k)!=saved.get(k) for k in ('width','height','pixelWidth','pixelHeight','rotation','modeID')):
            problems.append('Current resolution, orientation or mode differs from the saved profile')
        hz=row.get('hz')
        if type(row.get('width')) is not int or type(row.get('height')) is not int or row.get('pixelWidth')!=2*row['width'] or row.get('pixelHeight')!=2*row['height']:
            problems.append('2× HiDPI rendering is not confirmed')
        if type(hz) not in (int,float) or not abs(hz-120)<.2:problems.append('120 Hz is not confirmed')
        if row.get('variableRefresh') is not False or row.get('proMotion') is not False:problems.append('Fixed refresh is not confirmed (VRR/ProMotion active or unavailable)')
        if row.get('hdrPreferenceEnabled') is not False:problems.append('HDR-off preference is not confirmed')
        if row.get('metadataError') or row.get('error'):problems.append(str(row.get('metadataError') or row['error']))
        result.append({'name':label+' mode','status':'warning' if problems else 'ok','detail':'; '.join(problems) if problems else f"Saved {row['width']} × {row['height']} HiDPI mode matches; fixed 120 Hz and HDR-off preference confirmed.",**({'action':'Let switching finish and retry. If persistent, check Displays settings and the saved profile; this check changes nothing.'} if problems else {})})
    if not result:result.append({'name':'Display modes','status':'info','detail':'Both displays show the other Mac; local mode-policy checking is deferred.'})
    return result


def setup_checks(config):
    """Describe saved enrollment, not physical calibration or mutation authorization."""
    checks=[]
    host=config.get('host')
    if host in ('A','B'):
        local={'A':(17,19),'B':(18,15)}[host]
        checks.append({'name':'Host enrollment','status':'ok','detail':f'Mac {host}; expected local inputs PG={local[0]}, BenQ={local[1]}. Enrollment belongs to this Mac only.',
                       'action':'For another Mac, run independent enrollment; do not copy device identities or recovery journals.'})
    else:
        checks.append({'name':'Host enrollment','status':'warning','detail':'Host role is unavailable.','action':'Review the configuration before enrollment; do not infer a role from monitor names.'})
    rotation=config.get('rotation',{})
    baselines=rotation.get('baselines',{}) if isinstance(rotation,dict) else {}
    sensor_map=rotation.get('sensor_map',{}) if isinstance(rotation,dict) else {}
    keys=config.get('keys',{})
    found=[]
    if isinstance(baselines,dict) and isinstance(keys,dict) and set(keys)=={'pg','benq'}:
        for angle in ('0','90'):
            baseline=baselines.get(angle)
            rows=baseline.get('screens') if isinstance(baseline,dict) else None
            if isinstance(rows,list) and len(rows)==2 and all(isinstance(row,dict) for row in rows):
                if {row.get('key') for row in rows if isinstance(row.get('key'),str)}==set(keys.values()):
                    benq=next((row for row in rows if row.get('key')==keys['benq']),{})
                    if type(benq.get('rotation')) in (int,float) and benq['rotation']==int(angle):found.append(angle)
    mapping=isinstance(sensor_map,dict) and bool(sensor_map) and all(isinstance(k,str) and type(v) is int and v in (0,90) for k,v in sensor_map.items()) and set(sensor_map.values())=={0,90}
    enabled=isinstance(rotation,dict) and rotation.get('enabled') is True
    complete=set(found)=={'0','90'} and mapping
    detail='Stored landscape and portrait profiles and sensor mapping are present.' if complete else 'Rotation enrollment is incomplete: both matching orientation profiles and sensor mapping are required.'
    detail+=' Automatic rotation is '+('configured.' if enabled else 'not configured.')
    checks.append({'name':'Rotation enrollment','status':'ok' if complete else 'warning' if enabled else 'info','detail':detail,
                   'action':'Confirm rotation physically after enrollment. Stored profiles do not prove sensor operation or timing.' if complete else 'Keep existing profiles. Capture the missing orientation through the installer on this Mac; do not copy profiles from another host.'})
    return checks


def report(root, bin_dir, version, validate_config, read_inputs, inspect_modes=None):
    checks=[]
    def add(name, status, detail, action=None):
        item={'name':name,'status':status,'detail':detail}
        if action:item['action']=action
        checks.append(item)
    def read(name, optional=False):
        path=root/name
        try:
            descriptor=os.open(path,os.O_RDONLY|os.O_NONBLOCK|os.O_NOFOLLOW)
            with os.fdopen(descriptor,'rb') as stream:
                info=os.fstat(stream.fileno())
                if not stat.S_ISREG(info.st_mode):raise ValueError('State must be a regular file; original preserved')
                if info.st_size>1024*1024:raise ValueError('State file exceeds the health-check read limit; original preserved')
                raw=stream.read(1024*1024+1)
            if len(raw)>1024*1024:raise ValueError('State file exceeds the health-check read limit; original preserved')
            value=json.loads(raw)
            if not isinstance(value,dict):raise ValueError('Expected a JSON object')
            return value
        except (OSError,ValueError) as error:
            if optional and isinstance(error,FileNotFoundError):return None
            add(name,'error',str(error),'Save a diagnostic report; restore a known-good local backup rather than deleting recovery files.')
            return None

    config=read('config.json')
    valid=False
    if config is not None:
        try:validate_config(config);valid=True;add('Configuration','ok','Configuration and saved baseline agree.')
        except (OSError,ValueError,RuntimeError,KeyError,TypeError) as error:
            add('Configuration','error',str(error),'Reinstall from the trusted source package or restore a known-good backup.')
    health=read('health.json')
    if health is not None:
        try:
            pid=health.get('pid');age=time.time()-float(health.get('updated_at',0))
            if type(pid) is not int or pid<=0:raise ValueError('Missing controller process')
            os.kill(pid,0)
            if not 0<=age<15:raise ValueError('Controller heartbeat is stale')
            if health.get('version')!=version:raise ValueError('Controller and command versions differ')
            status=health.get('status','unknown')
            add('Controller','ok' if status=='ready' else 'warning',f'{status}; heartbeat age {age:.1f}s.',None if status=='ready' else 'Check pause state, monitor inputs and recovery details below.')
        except (OSError,TypeError,ValueError) as error:
            add('Controller','error',str(error),'Save diagnostics and restart the installed LaunchAgent or rerun the installer.')
    control=read('control.json',optional=True)
    if control is not None:
        try:
            validate_control(control)
            until=float(control.get('pause_until',0));manual=float(control.get('audio_manual_until',0))
            paused=bool(control.get('paused')) and (not until or until>time.time())
            if paused:add('Pause','info','Automation is paused'+(f' for about {max(1,round((until-time.time())/60))} more minutes.' if until else ' indefinitely.'),'Choose Resume automation in the menu when ready.')
            if manual>time.time():add('Audio override','info','Manual audio preservation is active.','Choose Resume automatic audio to end the override.')
            if not control.get('auto_rotate',True):add('Rotation','info','Automatic BenQ rotation is disabled; input switching and audio remain managed.','Enable Automatic BenQ rotation in the menu when wanted.')
        except (TypeError,ValueError) as error:add('Controls','error',str(error),'Restore valid control settings before resuming automation; the file is preserved.')
    recovery=read('recovery.json',optional=True)
    if recovery is not None:
        try:validate_recovery(recovery)
        except (TypeError,ValueError) as error:
            add('Recovery record','error',str(error),'Save diagnostics and restore a known-good recovery record. Do not clear the audio journal.')
            recovery=None
    if recovery and recovery.get('pending'):
        add('Recovery','warning',str(recovery.get('error') or recovery.get('reason') or 'Recovery pending'),'Keep the intended monitor inputs stable. If recovery is exhausted, use Repair audio after resuming automatic control.')
    if (root/'audio-refresh.json').exists():
        add('Audio journal','warning','An interrupted audio format recovery is pending.','Keep the original output connected; do not delete the journal. Save diagnostics if it does not clear.')
    manifest=read('manifest.json')
    if manifest:
        expected=manifest.get('source_sha256',{})
        if not isinstance(expected,dict):expected={}
        binaries=HELPER_HASH_FIELDS
        failures=[]
        runtime=RUNTIME_MODULES
        for name in (*runtime,*binaries):
            digest=manifest.get(binaries[name]) if name in binaries else expected.get(name)
            try:
                if not digest or hashlib.sha256((bin_dir/name).read_bytes()).hexdigest()!=digest:failures.append(name)
            except OSError:failures.append(name)
        add('Installed files','warning' if failures else 'ok',('Missing or differing manifest hashes: '+', '.join(failures)) if failures else 'Controller modules and native helpers match the installation manifest.','Reinstall from the trusted source package if these changes were unintended.' if failures else None)
    if valid:
        checks[:0]=setup_checks(config)
        try:
            inputs=read_inputs(config)
            known=inputs.get('pg') in (17,18) and inputs.get('benq') in (19,15)
            add('Monitor inputs','ok' if known else 'warning',f"PG={inputs.get('pg')}, BenQ={inputs.get('benq')}.",None if known else 'Select the configured HDMI/USB-C inputs. Unknown values are deliberately not guessed.')
            if known and inspect_modes:
                try:
                    mode_results=mode_checks(config,inputs,inspect_modes())
                    if read_inputs(config)!=inputs:
                        add('Display modes','info','Inputs changed during inspection; no mode verdict was retained.','Retry after switching finishes.')
                    else:checks.extend(mode_results)
                except Exception as error:add('Display modes','warning',str(error),'Retry after displays settle. Private mode metadata may need requalification after a macOS update.')
        except Exception as error:
            add('Monitor setup','info' if type(error).__name__=='SetupUnavailable' else 'warning',str(error),'On another desk, leave automation inactive. On the saved setup, check cables, input selections and DDC/CI availability.')
    if valid and (root/'size-presets.json').exists():
        try:
            presets=size_presets.read(root/'size-presets.json',config)['presets']
            add('Size presets','ok',f'{len(presets)} saved name/orientation pairs belong to this enrollment. Mode availability is checked only when opening the size chooser.')
        except (OSError,ValueError,KeyError,TypeError) as error:
            add('Size presets','warning',str(error),'Preserve the preset file and restore valid data for this enrollment. Ordinary relative-size previews remain available; this check does not reset presets.')
    menu=read('menu-health.json',optional=True)
    if menu:
        try:
            pid=menu.get('pid');age=time.time()-float(menu.get('updated_at',0))
            if type(pid) is not int or pid<=0:raise ValueError('Missing menu process')
            os.kill(pid,0)
            if not 0<=age<15:raise ValueError('Menu heartbeat is stale')
            if menu.get('app_version')!=version:raise ValueError('Menu and command versions differ')
            add('Menu app','ok',f'Menu heartbeat age {age:.1f}s; version matches the command. This does not verify its visual behavior.')
        except (OSError,TypeError,ValueError) as error:
            add('Menu app','warning',str(error),'Open the installed Display Bridge menu app or reinstall the matching app/controller pair. Do not start extra controller processes.')
    elif not (root/'menu-health.json').exists():
        add('Menu app','info','No menu heartbeat is available. The controller can run while the menu is closed.','Open the installed menu app if window controls are wanted.')
    if menu and menu.get('notification_authorization')==1:

        add('Failure notifications','info','macOS notifications are disabled for Display Auto.','Enable them in System Settings → Notifications if wanted; the menu still shows failures.')
    status='error' if any(c['status']=='error' for c in checks) else 'warning' if any(c['status']=='warning' for c in checks) else 'ok'
    return {'version':version,'read_only':True,'status':status,'checks':checks,'limits':'Readback does not prove audible sound, visual sharpness, HDR state, or absence of panel flicker. Nothing was changed or uploaded.'}
