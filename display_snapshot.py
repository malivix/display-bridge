# SPDX-License-Identifier: MIT
"""Read-only, identity-scoped mode information for the user interface."""
import math

FIELDS = ('id', 'mirrorSourceID', 'modeID', 'width', 'height', 'pixelWidth', 'pixelHeight', 'hz', 'rotation',
          'variableRefresh', 'proMotion', 'hdrPreferenceEnabled', 'metadataError', 'error')


def rows_by_identity(metadata, keys):
    rows = metadata.get('displays') if isinstance(metadata, dict) else None
    if not isinstance(rows, list) or len(rows) != 2:
        raise ValueError('Mode snapshot requires exactly the enrolled pair')
    result = {}
    for row in rows:
        if not isinstance(row, dict) or not isinstance(row.get('key'), str) or row['key'] in result:
            raise ValueError('Missing or ambiguous mode identity')
        result[row['key']] = row
    if set(result) != set(keys.values()):
        raise ValueError('Mode snapshot does not match the enrolled pair')
    return result


def dimensions(row):
    if not row or any(type(row.get(k)) is not int or not 0 < row[k] <= 65536
                      for k in ('width', 'height', 'pixelWidth', 'pixelHeight')):
        return None
    return {k: row[k] for k in ('width', 'height', 'pixelWidth', 'pixelHeight')}


def validate_rotation(config):
    """Validate stored rotation state before selecting or activating any profile."""
    if 'rotation' not in config:return
    rotation=config['rotation']
    if not isinstance(rotation,dict) or type(rotation.get('enabled',False)) is not bool:
        raise ValueError('Invalid rotation configuration; original preserved')
    baselines=rotation.get('baselines',{})
    mapping=rotation.get('sensor_map',{})
    if not isinstance(baselines,dict) or not set(baselines).issubset({'0','90'}):
        raise ValueError('Invalid rotation profile orientations')
    if not isinstance(mapping,dict) or any(not isinstance(k,str) or not k or any(c<'0' or c>'9' for c in k) or type(v) is not int or v not in (0,90) for k,v in mapping.items()):
        raise ValueError('Invalid rotation sensor mapping')
    if rotation.get('enabled') and (set(baselines)!={'0','90'} or set(mapping.values())!={0,90}):
        raise ValueError('Enabled rotation requires both orientation profiles and sensor mapping')
    keys=config.get('keys')
    if not isinstance(keys,dict) or set(keys)!={'pg','benq'} or any(not isinstance(k,str) or not k for k in keys.values()) or len(set(keys.values()))!=2:
        raise ValueError('Rotation requires two distinct enrolled identities')
    for angle,baseline in baselines.items():
        rows=baseline.get('screens') if isinstance(baseline,dict) else None
        if not isinstance(rows,list) or len(rows)!=2 or any(not isinstance(row,dict) or not isinstance(row.get('key'),str) for row in rows) or {row['key'] for row in rows}!=set(keys.values()):
            raise ValueError('Rotation profile differs from enrolled monitor pair')
        for row in rows:
            expected=int(angle) if row['key']==keys['benq'] else 0
            if type(row.get('rotation')) not in (int,float) or row['rotation']!=expected:
                raise ValueError('Rotation profile orientation does not match its label')
            if dimensions(row) is None or row.get('mirrorOf') is not None:
                raise ValueError('Rotation profile requires valid independent display dimensions')
            if type(row.get('hz')) not in (int,float) or not math.isfinite(row['hz']) or row['hz']<0:
                raise ValueError('Invalid rotation profile refresh rate')
            if any(type(row.get(k)) is not int or not -(2**31)<=row[k]<2**31 for k in ('x','y')):
                raise ValueError('Invalid rotation profile position')
            if row.get('modeID') is not None and (type(row['modeID']) is not int or not -(2**31)<=row['modeID']<2**31):
                raise ValueError('Invalid rotation profile mode identifier')
            if row.get('ioFlags') is not None and (type(row['ioFlags']) is not int or not 0<=row['ioFlags']<2**32):
                raise ValueError('Invalid rotation profile mode flags')
            if row.get('strictMode') is not None and type(row['strictMode']) is not bool:
                raise ValueError('Invalid rotation profile strict-mode policy')


def rotation_baseline(config,angle):
    validate_rotation(config)
    if type(angle) not in (int,float) or angle not in (0,90):
        raise ValueError('Unsupported rotation angle; original preserved')
    saved=config.get('rotation',{}).get('baselines',{}).get(str(int(angle)))
    if saved is None:raise ValueError('No calibrated baseline for BenQ rotation')
    return saved


def saved_layout(config, rows):
    """Select the whole saved layout using this Mac's measured BenQ orientation."""
    if not config.get('rotation', {}).get('enabled'):
        return config['baseline']
    matches=[row for row in rows if isinstance(row,dict) and row.get('key')==config['keys']['benq']]
    if len(matches)!=1:
        return None
    angle=matches[0].get('rotation')
    if type(angle) not in (int,float) or angle not in (0,90):
        return None
    return config['rotation'].get('baselines',{}).get(str(int(angle)))


def logical_layout(config, inputs, rows):
    """This Mac's observed logical connections, independent of physical input ownership."""
    pair=[rows[config['keys'][role]] for role in ('pg','benq')]
    ids=[row.get('id') for row in pair]
    sources=[row.get('mirrorSourceID') for row in pair]
    valid=all(type(value) is int and 0<value<2**32 for value in ids) and len(set(ids))==2
    valid=valid and all(type(value) is int and 0<=value<2**32 for value in sources)
    state='unknown'
    if valid:
        if sources==[0,0]:state='extended'
        elif sources==[0,ids[0]]:state='pg-source'
        elif sources==[ids[1],0]:state='benq-source'
    monitors=[]
    for role,row in zip(('pg','benq'),pair):
        ports={'pg':{17:'A',18:'B'},'benq':{19:'A',15:'B'}}[role]
        value=inputs.get(role)
        owner=ports.get(value) if type(value) is int else None
        angle=row.get('rotation')
        rotation=angle if type(angle) in (int,float) and angle in (0,90,180,270) else None
        monitors.append({'monitor':role,'owner':owner,'rotation':rotation})
    return {'state':state,'monitors':monitors}


def report(config, inputs, first, second):
    before = rows_by_identity(first, config['keys'])
    after = rows_by_identity(second, config['keys'])
    local = {'A': {'pg':17, 'benq':19}, 'B': {'pg':18, 'benq':15}}[config['host']]
    for key in before:
        if any(before[key].get(k) != after[key].get(k) for k in FIELDS):
            raise ValueError('Display mode changed during inspection; refresh after switching settles')
    baseline = saved_layout(config,list(after.values()))
    result = []
    for role in ('pg', 'benq'):
        if inputs.get(role) != local[role]:
            result.append({'monitor':role, 'available':False,
                           'reason':'Not showing this Mac; its physical output is not inspected'})
            continue
        row = after[config['keys'][role]]
        saved = next((s for s in baseline['screens'] if s['key'] == config['keys'][role]), None) if baseline else None
        current = dimensions(row)
        hz = row.get('hz')
        try:
            valid_hz = type(hz) in (int,float) and math.isfinite(hz) and 0 < hz < 1000
        except OverflowError:
            valid_hz = False
        metadata_ok = not row.get('metadataError') and not row.get('error')
        result.append({'monitor':role, 'available':True, 'current':current, 'saved':dimensions(saved),
                       'hz':hz if valid_hz else None,
                       'hidpi':None if current is None else current['pixelWidth']==2*current['width'] and current['pixelHeight']==2*current['height'],
                       'fixed_refresh':None if not metadata_ok or type(row.get('variableRefresh')) is not bool or type(row.get('proMotion')) is not bool else not row['variableRefresh'] and not row['proMotion'],
                       'hdr_preference':row.get('hdrPreferenceEnabled') if metadata_ok and type(row.get('hdrPreferenceEnabled')) is bool else None,
                       'saved_mode_matches':None if not saved else all(row.get(k)==saved.get(k) for k in ('modeID','width','height','pixelWidth','pixelHeight','rotation'))})
    return {'read_only':True, 'inputs':dict(inputs), 'displays':result,
            'logical_layout':logical_layout(config,inputs,after),
            'limits':'Snapshot only. Logical size and framebuffer size are distinct. HiDPI is not proof of native pixel sharpness. HDR preference is not a measurement of panel output.'}
