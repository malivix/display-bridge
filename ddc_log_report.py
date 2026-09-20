#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Read-only DDC interruption report from retained controller logs; no hardware IO."""
import argparse
from collections import Counter
from datetime import datetime
import json
from pathlib import Path
import re

LINE = re.compile(r'^(\d{4}-\d\d-\d\d \d\d:\d\d:\d\d,\d{3}) (INFO|WARNING|ERROR) (.*)$')


def summarize(text):
    episodes, transitions, failures = [], [], []
    active = None
    first = last = None
    unmatched = 0
    for line in text.splitlines():
        match = LINE.match(line)
        if not match:
            continue
        try:
            stamp = datetime.strptime(match[1], '%Y-%m-%d %H:%M:%S,%f')
        except ValueError:
            continue
        when = stamp.isoformat(timespec='milliseconds')
        first = first or when
        last = when
        message = match[3]
        if message.startswith('Started v'):
            # A restart is not proof that a hardware interruption recovered.
            active = None
        if message.startswith('DDC unavailable; no changes:'):
            if active is None:
                reason = message.partition('no changes: ')[2]
                monitor = reason.split(':', 1)[0]
                active = {'started': when, 'monitor': monitor if monitor in ('pg', 'benq') else 'unknown',
                          'reason': reason, 'recovered': None, 'seconds': None}
                episodes.append(active)
        elif message == 'DDC recovered':
            if active is None:
                unmatched += 1
            else:
                elapsed = (stamp - datetime.fromisoformat(active['started'])).total_seconds()
                active['recovered'] = when
                active['seconds'] = round(elapsed, 3) if elapsed >= 0 else None
                active = None
        elif message.startswith('Recovery failed:'):
            failures.append({'at': when, 'reason': message.partition(': ')[2]})
        elif re.match(r'PG=\d+ BenQ=\d+ profile=', message):
            transitions.append({'at': when, 'detail': message})
    durations = [e['seconds'] for e in episodes if e['seconds'] is not None]
    return {'read_only': True, 'coverage': {'first': first, 'last': last},
            'ddc_interruptions': len(episodes), 'by_monitor': dict(Counter(e['monitor'] for e in episodes)),
            'without_recorded_recovery': sum(e['recovered'] is None for e in episodes),
            'unmatched_recovery_messages': unmatched,
            'longest_recorded_seconds': max(durations, default=None),
            'episodes': episodes, 'recovery_failures': failures, 'transitions': transitions,
            'limits': 'Retained logs only. Warnings are deduplicated, so counts are interruption episodes, not failed reads or a failure rate. Local wall-clock changes can distort durations. A recovery message proves a successful read, not stable hardware or audible sound. Restarts and log rotation can leave incomplete episodes.'}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('logs', nargs='*', type=Path, help='Logs in chronological order (oldest first). Default: current controller log.')
    args = parser.parse_args()
    paths = args.logs or [Path.home() / 'Library/Logs/display-auto-v2.log']
    try:
        result = summarize('\n'.join(p.read_text(errors='replace') for p in paths))
    except OSError as error:
        parser.exit(1, f'Cannot read log: {error}\n')
    result['sources'] = [str(p) for p in paths]
    print(json.dumps(result, indent=2))


if __name__ == '__main__':
    main()
