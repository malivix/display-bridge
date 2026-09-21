# Keep prior monitor readings with their target

The menu previously retained one shared successful reading. Selecting another monitor
cleared visible text but retained that shared value; a subsequent failed request could
append the other monitor's old reading. Its embedded model label reduced ambiguity but
did not make it an appropriate fallback for the selected target.

The session cache now stores successful readings by validated monitor role. Failures
only append the selected target's previous reading, and switching back to a monitor
shows its retained reading explicitly marked not refreshed. An unread target has no
fallback. Read-only snapshots now include a date/time, matching their observational
scope. No automatic reads, persistence, extra polling or hardware writes were added.

Native regressions verify isolation between PG and BenQ, no fallback for unread or
unmanaged targets, retained-reading labels and snapshot timestamps. Controller guards,
response validation and serialized command handling are unchanged. This is software
state coverage; optical brightness and physical volume remain unqualified by these tests.

Validation: `scripts/verify --native` passed with 279 Python tests and native builds/self-tests. No installation or live monitor operation was performed.
