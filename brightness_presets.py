# SPDX-License-Identifier: MIT
"""Named hardware brightness values. Caller holds writer and hardware locks."""
import json,os,tempfile
from pathlib import Path
from size_presets import name,scope,revision


def validate(store,config):
    if not isinstance(store,dict) or set(store)!={'schema','scope','presets'} or type(store['schema']) is not int or store['schema']!=1 or store['scope']!=scope(config):
        raise ValueError('Invalid brightness preset store or different enrollment; original preserved')
    entries=store['presets']
    if not isinstance(entries,list) or len(entries)>20:raise ValueError('Brightness presets are limited to 20 entries')
    seen=set()
    for entry in entries:
        if not isinstance(entry,dict) or set(entry)!={'name','monitor','value','maximum'}:raise ValueError('Invalid brightness preset entry')
        name(entry['name'])
        if entry['monitor'] not in ('pg','benq'):raise ValueError('Invalid preset monitor')
        if type(entry['value']) is not int or type(entry['maximum']) is not int or not 0<=entry['value']<=entry['maximum']<=65535 or entry['maximum']==0:
            raise ValueError('Invalid brightness preset range')
        key=(entry['name'],entry['monitor'])
        if key in seen:raise ValueError('Duplicate brightness preset')
        seen.add(key)
    return store


def read(path,config):
    try:
        with Path(path).open('rb') as stream:raw=stream.read(128*1024+1)
    except FileNotFoundError:return {'schema':1,'scope':scope(config),'presets':[]}
    if len(raw)>128*1024:raise ValueError('Brightness preset store exceeds read limit; original preserved')
    return validate(json.loads(raw),config)


def write(path,config,store):
    validate(store,config);path=Path(path)
    fd,temp=tempfile.mkstemp(prefix='.brightness-presets-',dir=path.parent)
    try:
        with os.fdopen(fd,'w') as stream:
            json.dump(store,stream,indent=2);stream.write('\n');stream.flush();os.fsync(stream.fileno())
        os.replace(temp,path)
        directory=os.open(path.parent,os.O_RDONLY)
        try:os.fsync(directory)
        finally:os.close(directory)
    finally:
        if os.path.exists(temp):os.unlink(temp)


def save(path,config,label,monitor,reading,replace=False):
    name(label);store=read(path,config)
    matches=[e for e in store['presets'] if (e['name'],e['monitor'])==(label,monitor)]
    if matches and not replace:raise ValueError('Preset exists; explicitly replace it or use another name')
    entry={'name':label,'monitor':monitor,'value':reading['value'],'maximum':reading['maximum']}
    store['presets']=[e for e in store['presets'] if e not in matches]+[entry]
    write(path,config,store);return entry


def find(store,label,monitor,expected):
    name(label)
    matches=[e for e in store['presets'] if (e['name'],e['monitor'])==(label,monitor)]
    if len(matches)!=1:raise ValueError('No brightness preset with this name for this monitor')
    entry=matches[0]
    if not isinstance(expected,str) or expected!=revision(entry):raise ValueError('Brightness preset changed; refresh the list before applying or removing it')
    return entry


def remove(path,config,label,monitor,expected):
    store=read(path,config);entry=find(store,label,monitor,expected)
    store['presets'].remove(entry);write(path,config,store);return entry
