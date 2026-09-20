# Expose timing coverage and failed attempts

Timing summaries retain profiles that have failed attempts but no completed transitions.
The window formatter shows completed record count, failed attempt count, and per-phase
median/p95/slowest with independent sample counts. It does not substitute a profile total
for an unknown phase count. Missing percentiles remain unavailable; invalid numeric times
are not formatted as measured values.

Failed attempts are labeled as potentially including retries. Small-sample percentiles and
unmeasured physical switching intervals are explained. No event collection or hardware
policy changed. Validation: 208 Python tests and native builds/self-tests passed; regressions
cover failure-only profiles, phase-specific counts and percentile presentation. This turn
verified report content through formatter tests, not a new physical performance measurement.
