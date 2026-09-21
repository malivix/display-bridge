#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Read-only scaling analysis. Input: display-layout modes JSON. No display writes."""
import argparse
import json
from pathlib import Path

# Panel specifications for this project only; never infer another monitor's panel
# resolution from its largest advertised/supersampled framebuffer.
# A monitor may publish a different EDID product code on each physical input, so one
# panel can present more than one vendor:model identity across the two hosts.
PANEL_IDENTITIES = {'pg': ('1715:17120',), 'benq': ('2513:32963', '2513:32959')}
PANEL_SPECS = {'pg': ('PG42UQ', 3840, 2160), 'benq': ('BenQ RD280UG', 3840, 2560)}
PANELS = {identity: PANEL_SPECS[role]
          for role, identities in PANEL_IDENTITIES.items() for identity in identities}

def describe(mode, panel, current):
    w, h = panel
    pw, ph = mode['pixelWidth'], mode['pixelHeight']
    exact = (pw, ph) == panel
    sampling = ('native raster' if exact else
                'upscaled raster' if pw <= w and ph <= h else
                'downsampled raster' if pw >= w and ph >= h else 'mixed-axis resampling')
    return {'logical': [mode['width'], mode['height']], 'rendered': [pw, ph],
            'sampling': sampling,
            'interface_size_percent_of_current': round(100 * current['width'] / mode['width'], 1),
            'content_zoom_to_match_current_percent': round(100 * mode['width'] / current['width'], 1),
            'modeID': mode['modeID'], 'reported_hz': mode['hz'],
            'refresh_type': 'unverified: fixed/variable require separate verification'}

def analyze(inventory):
    reports = []
    for display in inventory:
        current = display['current']
        known = PANELS.get(':'.join(current['key'].split(':')[:2]))
        if known is None:
            reports.append({'key': current['key'], 'supported': False,
                            'reason': 'Unknown panel; no panel-specific recommendations'})
            continue
        name, w, h = known
        angle = current['rotation'] % 360
        if angle not in (0, 90, 180, 270):
            reports.append({'key': current['key'], 'supported': False, 'reason': 'Unsupported rotation'})
            continue
        panel = (h, w) if angle in (90, 270) else (w, h)
        choices = []
        for mode in display['modes']:
            if not mode['usableForDesktop'] or abs(mode['hz'] - 120) >= .2:
                continue
            if mode['pixelWidth'] != 2 * mode['width'] or mode['pixelHeight'] != 2 * mode['height']:
                continue
            # Exclude letterboxed/non-panel aspect ratios, tolerate rounded pixels.
            if abs(mode['width'] / mode['height'] - panel[0] / panel[1]) > .003:
                continue
            choices.append(describe(mode, panel, current))
        reports.append({'key': current['key'], 'name': name, 'supported': True,
                        'panel_pixels': panel, 'current': describe(current, panel, current),
                        'candidates': choices})
    return {'read_only': True, 'displays': reports,
            'limitations': ['HDR and VRR are not identified by this CoreGraphics inventory.',
                            'Mode IDs must be revalidated on this Mac; never copy them to Mac B.',
                            'Content zoom does not enlarge every menu or toolbar.',
                            'Native raster is a sampling property, not proof that halos or all softness are fixed.',
                            'Panel specifications are model-based; mutations must also verify the saved device UUIDs.']}

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('inventory', type=Path)
    args = parser.parse_args()
    print(json.dumps(analyze(json.loads(args.inventory.read_text())), indent=2))

if __name__ == '__main__':
    main()
