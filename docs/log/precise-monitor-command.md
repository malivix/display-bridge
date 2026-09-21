# Explicit percentage targets through the existing command boundary

Added `monitor-set --monitor pg|benq --feature luminance|volume --percent 0..100`.
It uses the same preview exclusion, maintenance/DDC locks, setup verification, paused
automation check, ownership rechecks and confirmed readback as the existing step controls.
The target is rounded to the nearest native hardware step; the response reports the actual
confirmed percent rather than claiming every percentage is representable. No retry or
automatic rollback was introduced.

Tests cover native range conversion, no-op writes, invalid input before requests and
ownership loss before/after a single write. A CLI integration case uses a simulated monitor
to verify argument routing, setup verification, one write and readback. The native slider
with explicit Apply is the next part of the [plan](../plans/precise-monitor-settings.md);
this commit provides its guarded backend, not a completed slider UI.

Integration review also caught an existing defect: the CLI's hardcoded `--size` choices
excluded newer relative physical-size targets even though the service advertised them.
The parser now uses the service's size definitions. A regression invokes every advertised
identifier through the actual parser and verifies it reaches preview enqueue. Earlier
service-only tests did not cover this entry-point gap.

Validation: `scripts/verify` passed all 290 Python tests. No native source changed, live DDC
request, installation or physical test occurred. Ordinary ±5 controls remain compatible.
