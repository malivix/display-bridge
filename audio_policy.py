# SPDX-License-Identifier: MIT
"""Pure speaker-routing decisions. Device UIDs are captured on each Mac."""
DEFAULTS={'extended':'pg','pg':'pg','benq':'benq','away':'fallback'}
def preference(audio,profile):
    value=audio.get('preferences',{}).get(profile,DEFAULTS[profile])
    if value not in ('pg','benq','fallback','preserve'):raise RuntimeError('Invalid speaker preference')
    # An inactive monitor cannot play this Mac's sound.
    if value=='pg' and profile in ('benq','away') or value=='benq' and profile in ('pg','away'):
        return 'fallback'
    return value

def route(audio, profile, devices):
    if not audio or not audio.get('enabled') or profile == 'unknown':
        return None
    current = [d for d in devices if d.get('default')]
    if len(current) != 1:
        raise RuntimeError('Cannot identify the current audio output')
    known = {audio.get(k) for k in ('pg','benq','fallback')} - {None}
    # A headset, USB interface or aggregate output remains under user control.
    if current[0]['uid'] not in known:
        return None
    choice=preference(audio,profile)
    if choice=='preserve':return None
    target = audio.get(choice)
    alive = {d['uid'] for d in devices if d.get('alive')}
    if target not in alive:
        raise RuntimeError('Preferred audio output is unavailable; leaving selection unchanged')
    systems = [d for d in devices if d.get('system')]
    follow_alerts = len(systems) == 1 and systems[0]['uid'] in known
    change_output = current[0]['uid'] != target
    change_alerts = follow_alerts and systems[0]['uid'] != target
    return (target, 'both' if follow_alerts else 'output') if change_output or change_alerts else None
