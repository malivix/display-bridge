# SPDX-License-Identifier: MIT
"""Small explicit hardware adjustments; caller owns setup verification and DDC lock."""
import math


def number(value):
    if not isinstance(value,str) or not value.isascii() or not value.isdecimal():
        raise ValueError('Invalid monitor setting response')
    result=int(value)
    if not 0<=result<=65535:raise ValueError('Monitor setting outside DDC range')
    return result


def inspect(config, role, request):
    if role not in ('pg','benq'):raise ValueError('Unsupported monitor')
    local={'A':{'pg':17,'benq':19},'B':{'pg':18,'benq':15}}[config['host']][role]
    if number(request('get','input'))!=local:raise RuntimeError('This monitor is not showing this Mac')
    settings={}
    for feature in ('luminance','volume'):
        value=number(request('get',feature));maximum=number(request('max',feature))
        if maximum<=0 or value>maximum:raise ValueError('Monitor returned an invalid setting range')
        settings[feature]={'value':value,'maximum':maximum,'percent':round(value*100/maximum)}
    if number(request('get','input'))!=local:raise RuntimeError('Input changed while reading; discard settings and retry')
    return {'monitor':role,'read_only':True,'settings':settings}


def adjust(config, role, feature, step, request):
    if role not in ('pg','benq') or feature not in ('luminance','volume'):
        raise ValueError('Unsupported monitor control')
    if type(step) is not int or step not in (-5,5):raise ValueError('Adjustment must be ±5 percent')
    local={'A':{'pg':17,'benq':19},'B':{'pg':18,'benq':15}}[config['host']][role]
    def ensure_local():
        if number(request('get','input'))!=local:
            raise RuntimeError('This monitor is not showing this Mac; no further setting changes made')
    ensure_local()
    current=number(request('get',feature));maximum=number(request('max',feature))
    if maximum<=0 or current>maximum:raise ValueError('Monitor returned an invalid setting range')
    delta=max(1,math.floor(maximum*abs(step)/100+.5))*(1 if step>0 else -1)
    target=min(maximum,max(0,current+delta))
    ensure_local()
    if target!=current:request('set',feature,target)
    # No automatic rollback: a changed input or manual adjustment must not be overwritten.
    ensure_local()
    actual=number(request('get',feature))
    if actual!=target:
        raise RuntimeError(f'Monitor did not confirm the requested value (wanted {target}, read {actual}); not retried')
    return {'monitor':role,'feature':feature,'before':current,'value':actual,'maximum':maximum,
            'percent':round(actual*100/maximum),'changed':actual!=current}
