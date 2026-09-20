# SPDX-License-Identifier: MIT
"""Fail-closed, read-only HiDPI candidate selection for the preview transaction."""
import copy
import math


def valid_dimensions(mode):
    return all(type(mode.get(k)) is int and 0 < mode[k] <= 65536
               for k in ("width", "height", "pixelWidth", "pixelHeight"))


def candidates(inventory,metadata,keys,require_rollback=True):
    if set(keys)!={'pg','benq'} or len(set(keys.values()))!=2:raise ValueError('Expected two distinct saved monitor identities')
    public={}
    for display in inventory:
        key=display['current']['key']
        if key in public:raise ValueError('Ambiguous public display identity')
        public[key]=display
    private={}
    for display in metadata['displays']:
        key=display['key']
        if key in private:raise ValueError('Ambiguous private display identity')
        private[key]=display
    if set(public)!=set(keys.values()) or set(private)!=set(keys.values()):raise ValueError('Only the saved two-monitor setup can be previewed')
    result={}
    for role,key in keys.items():
        display=public[key];current=display['current'];detail=private[key]
        if not valid_dimensions(current):raise ValueError('Current display dimensions are invalid; no size comparison is safe')
        if current.get('mirrorOf'):raise ValueError('Preview requires two independent desktops')
        if detail.get('metadataError') or detail.get('error'):raise ValueError('Mode metadata unavailable; no candidate is qualified')
        if any(current.get(field)!=detail.get(field) for field in ('modeID','width','height','pixelWidth','pixelHeight','rotation')):
            raise ValueError('Display changed during inspection; retry')
        if detail.get('hdrPreferenceEnabled') is not False:raise ValueError('Preview requires HDR-off preference')
        private_modes={}
        for mode in detail.get('modes',[]):
            identifier=mode['modeID']
            if identifier in private_modes:raise ValueError('Ambiguous private mode identifier')
            private_modes[identifier]=mode
        choices=[];seen=set()
        panel=(3840,2160) if role=='pg' else (3840,2560)
        if current['rotation'] in (90,270):panel=panel[::-1]
        elif current['rotation']!=0:raise ValueError('Orientation is not qualified for preview')
        for mode in display['modes']:
            identifier=mode['modeID'];flags=private_modes.get(identifier,{})
            if identifier in seen:raise ValueError('Ambiguous public mode identifier')
            seen.add(identifier)
            if flags.get('variableRefresh') is not False or flags.get('proMotion') is not False:continue
            if mode.get('usableForDesktop') is not True:continue
            if not valid_dimensions(mode):continue
            if type(mode.get('hz')) not in (int,float) or not 0 < mode['hz'] <= 1000 or not math.isfinite(mode['hz']) or abs(mode['hz']-120)>=.2:continue
            if mode['pixelWidth']!=2*mode['width'] or mode['pixelHeight']!=2*mode['height']:continue
            if abs(mode['width']/mode['height']-panel[0]/panel[1])>.003:continue
            choices.append(dict(mode,interface_percent=round(100*current['width']/mode['width'],1),current=identifier==current['modeID']))
        if require_rollback and not any(choice['current'] for choice in choices):raise ValueError('Current mode is not a qualified rollback target')
        result[role]={'current':copy.deepcopy(current),'choices':sorted(choices,key=lambda m:(m['width'],m['modeID']))}
    return {'read_only':True,'displays':result,'limits':'Candidates are not previews. Input ownership, current orientation, rollback persistence and post-apply mode readback must be checked by the preview transaction. Mode IDs are local to this Mac.'}


def paired_sizes(report):
    """Suggest similar relative size changes, preserving the owner's current match."""
    proposals=[]
    for label,target in (('Larger interface',125),('Current size',100),('More space',80)):
        pair={}
        for role in ('pg','benq'):
            choices=report['displays'][role]['choices']
            if target==100:choices=[c for c in choices if c['current']]
            else:choices=[c for c in choices if not c['current'] and (c['interface_percent']>100)==(target>100)]
            if not choices:break
            choice=min(choices,key=lambda c:(abs(c['interface_percent']-target),c['modeID']))
            if abs(choice['interface_percent']-target)>10:break
            pair[role]=copy.deepcopy(choice)
        if len(pair)==2 and abs(pair['pg']['interface_percent']-pair['benq']['interface_percent'])<=6:
            proposals.append({'label':label,'target_interface_percent':target,'modes':pair})
    return proposals
