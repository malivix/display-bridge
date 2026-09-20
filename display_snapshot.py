# SPDX-License-Identifier: MIT
"""Read-only, identity-scoped mode information for the user interface."""
import math

FIELDS = ('modeID', 'width', 'height', 'pixelWidth', 'pixelHeight', 'hz', 'rotation',
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
            'limits':'Snapshot only. Logical size and framebuffer size are distinct. HiDPI is not proof of native pixel sharpness. HDR preference is not a measurement of panel output.'}
