# SPDX-License-Identifier: MIT
"""Local semantic size presets; mode IDs are always resolved afresh."""
import hashlib,json,math,os,tempfile
from pathlib import Path

FIELDS=('width','height','pixelWidth','pixelHeight','hz')
LIMIT=20


def name(value):
    if not isinstance(value,str) or not 1<=len(value)<=48 or value!=value.strip() or any(ord(c)<32 or ord(c)==127 for c in value):
        raise ValueError('Preset name must be 1–48 characters without surrounding whitespace or control characters')
    return value


def scope(config):
    return hashlib.sha256(json.dumps({k:config[k] for k in ('host','keys','ddc_identifiers')},sort_keys=True).encode()).hexdigest()


def validate(store):
    if not isinstance(store,dict) or set(store)!={'schema','scope','presets'} or type(store['schema']) is not int or store['schema']!=1:
        raise ValueError('Unsupported or damaged size preset store; original preserved')
    if not isinstance(store['scope'],str) or len(store['scope'])!=64 or any(c not in '0123456789abcdef' for c in store['scope']):raise ValueError('Invalid preset scope')
    entries=store['presets']
    if not isinstance(entries,list) or len(entries)>LIMIT:raise ValueError('Invalid preset count')
    seen=set()
    for entry in entries:
        if not isinstance(entry,dict) or set(entry)!={'name','rotation','modes'}:raise ValueError('Invalid preset entry')
        name(entry['name'])
        if type(entry['rotation']) is not int or entry['rotation'] not in (0,90):raise ValueError('Invalid preset orientation')
        key=(entry['name'],entry['rotation'])
        if key in seen:raise ValueError('Duplicate preset name and orientation')
        seen.add(key)
        if not isinstance(entry['modes'],dict) or set(entry['modes'])!={'pg','benq'}:raise ValueError('Preset requires both monitors')
        for mode in entry['modes'].values():
            if not isinstance(mode,dict) or set(mode)!=set(FIELDS):raise ValueError('Invalid preset mode')
            for field in FIELDS[:-1]:
                if type(mode[field]) is not int or not 1<=mode[field]<=32768:raise ValueError('Invalid preset dimensions')
            if mode['pixelWidth']!=2*mode['width'] or mode['pixelHeight']!=2*mode['height']:raise ValueError('Preset must use 2x HiDPI')
            if type(mode['hz']) not in (int,float) or not math.isfinite(mode['hz']) or abs(mode['hz']-120)>=.2:raise ValueError('Preset requires fixed 120 Hz')
    return store


def read(path,config):
    try:
        with Path(path).open('rb') as stream:data=stream.read(131073)
    except FileNotFoundError:return {'schema':1,'scope':scope(config),'presets':[]}
    if len(data)>131072:raise ValueError('Size preset store too large; original preserved')
    store=validate(json.loads(data))
    if store['scope']!=scope(config):raise ValueError('Size presets belong to another enrollment; original preserved')
    return store


def capture(label,rotation,report):
    entry={'name':name(label),'rotation':rotation,'modes':{}}
    for role in ('pg','benq'):
        choices=[m for m in report['displays'][role]['choices'] if m['current']]
        if len(choices)!=1:raise ValueError('Current size is not uniquely qualified')
        entry['modes'][role]={field:choices[0][field] for field in FIELDS}
    return entry


def resolve(entry,rotation,report):
    if entry['rotation']!=rotation:raise ValueError('Preset belongs to the other orientation')
    pair={'label':entry['name'],'modes':{}}
    for role in ('pg','benq'):
        matches=[m for m in report['displays'][role]['choices'] if all(m.get(field)==entry['modes'][role][field] for field in FIELDS)]
        if len(matches)!=1:raise ValueError('Preset mode unavailable or ambiguous; no substitute applied')
        pair['modes'][role]=matches[0]
    return pair


def find(store,label,rotation):
    name(label)
    matches=[entry for entry in store['presets'] if entry['name']==label and entry['rotation']==rotation]
    if len(matches)!=1:raise ValueError('No saved preset with this name for the current orientation')
    return matches[0]


def save(path,config,entry,replace=False):
    """Caller holds the preset file lock across this read/modify/write."""
    path=Path(path);store=read(path,config)
    matches=[e for e in store['presets'] if (e['name'],e['rotation'])==(entry['name'],entry['rotation'])]
    if matches and not replace:raise ValueError('Preset already exists; explicitly replace it or choose another name')
    store['presets']=[e for e in store['presets'] if e not in matches]+[entry]
    validate(store)
    fd,temp=tempfile.mkstemp(prefix='.size-presets-',dir=path.parent)
    try:
        with os.fdopen(fd,'w') as stream:
            json.dump(store,stream,indent=2);stream.write('\n');stream.flush();os.fsync(stream.fileno())
        os.replace(temp,path)
        directory=os.open(path.parent,os.O_RDONLY)
        try:os.fsync(directory)
        finally:os.close(directory)
    finally:
        if os.path.exists(temp):os.unlink(temp)
    return entry
