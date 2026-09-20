# SPDX-License-Identifier: MIT
"""Build a per-orientation scaling proposal without mutating saved settings."""
import copy,json


def build(config,report,pair):
    proposed=copy.deepcopy(config)
    roles=report['displays'];pg=roles['pg']['current'];benq=roles['benq']['current']
    if pg['key']!=config['keys']['pg'] or benq['key']!=config['keys']['benq']:raise ValueError('Saved display identities changed')
    angle=benq['rotation']
    if pg['rotation']!=0 or angle not in (0,90):raise ValueError('Unsupported preview orientation')
    # This product currently has PG as the origin and BenQ immediately left.
    # Refuse another desk arrangement instead of silently repositioning it.
    if pg['x']!=0 or pg['y']!=0 or benq['x']+benq['width']!=0:
        raise ValueError('Preview layout requires the saved PG origin and BenQ on its left')
    if set(pair['modes'])!={'pg','benq'}:raise ValueError('A paired proposal is required')
    screens=[]
    for role in ('pg','benq'):
        chosen=pair['modes'][role]
        matches=[m for m in roles[role]['choices'] if m==chosen]
        if len(matches)!=1:raise ValueError('Choice does not match the inspected mode inventory')
        screen=copy.deepcopy(roles[role]['current'])
        for field in ('modeID','width','height','pixelWidth','pixelHeight','hz','ioFlags'):
            if field not in chosen:raise ValueError('Incomplete candidate mode')
            screen[field]=chosen[field]
        screen['strictMode']=True
        screen.pop('mirrorOf',None)
        screens.append(screen)
    vertical_offset=benq['y']+benq['height']/2-pg['height']/2
    screens[1]['x']=-screens[1]['width']
    screens[1]['y']=round((screens[0]['height']-screens[1]['height'])/2+vertical_offset)
    baseline={'screens':screens}
    proposed['baseline']=copy.deepcopy(baseline)
    rotation=proposed.get('rotation',{})
    if rotation.get('enabled'):
        if str(angle) not in rotation.get('baselines',{}):raise ValueError('Current orientation has no saved profile')
        rotation['baselines'][str(angle)]=copy.deepcopy(baseline)
    # Do not persist runtime-only fields inserted by the watcher.
    for field in ('active_baseline_path','_rotation_status'):proposed.pop(field,None)
    if isinstance(proposed.get('audio'),dict):proposed['audio'].pop('preferences',None)
    encode=lambda value:(json.dumps(value,indent=2)+'\n').encode()
    return {'config.json':encode(proposed),'baseline.json':encode(baseline),
            'rotation-active.json':encode(baseline) if rotation.get('enabled') else None}
