# Allowlisted support summary

Added a read-only `support-summary` command and menu preview. It constructs fixed fields
from known status/profile enums, booleans, bounded recovery counts, and aggregated retained
transition counts. Tool version is labeled separately from whether the controller version
matches. It never copies arbitrary keys, names, identifiers, raw errors, logs, input values,
exact timestamps, or diagnostic bytes. There is no upload or automatic clipboard action.

Private diagnostics remain intact and explicitly private. The summary is not a sanitizer
for those files or a proof that sharing operational information is risk-free. Missing,
malformed, or oversized sections are named as unavailable. Reads are bounded to one MiB
per input; output counts cover at most 200 retained events.

Tests plant private canaries throughout source data and unknown fields and verify exclusion;
also cover malformed/oversized data, preservation of originals, count limits, and invalid
numeric types. A read-only source command was exercised against local state and produced
only allowlisted categories. The current unknown-input hold remains visible; no monitor
mapping, controller setting, or installed module was changed during this feature work.
Rollback removes the UI/CLI feature; no persisted state schema is introduced.

Validation passed: 191 Python tests, native builds/self-tests, and staged privacy checks.
Previous published revision CI completed successfully. This source feature is not yet in
the installed runtime; deployment is separate from the read-only source smoke test.
