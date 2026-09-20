# Bound preview size arithmetic

Reproduced overflow exceptions from extremely large refresh/dimension integers in candidate
mode reports, plus acceptance of invalid current widths when rollback qualification was not
required. Current dimensions now require positive integer values bounded to 65536; booleans
and floats are rejected. Candidate dimensions use the same bound, and refresh values are
range-checked before float conversion. Invalid candidates are excluded; an invalid current
comparison target produces a ValueError before size arithmetic.

Focused regressions failed before the fix and passed afterward. All 249 Python tests and
staged privacy checks passed. Native code was unchanged; no hardware tests, installation,
mode writes or configuration changes were performed. This validates numeric fields used in
size arithmetic, not every possible malformed helper report or physical mode compatibility.
