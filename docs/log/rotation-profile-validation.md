# Reject invalid rotation profiles before activation

Reproduced two defects with failing isolated tests: enabled rotation without profiles
passed startup validation, and a malformed/foreign profile replaced rotation-active.json.
Native layout guards offered later protection, but active state had already been replaced.

Added shared structural validation at startup and before selecting a rotation baseline.
It checks enabled completeness, numeric sensor mapping, the enrolled identity pair,
orientation labels, independent display dimensions, refresh, positions and native mode
field types. Disabled partial enrollment remains valid for the installer capture workflow.
Malformed provided profiles are preserved and rejected. Selection errors retain RuntimeError
behavior for the controller's existing recovery handling. No hardware policy or schema change.

Validation: both reproductions failed before the fix, then 214 Python tests passed.
Added cases for invalid identity, dimensions, orientation, sensor values, numeric fields,
partial enrollment and preservation before any active-file replacement. Existing rotation
and changed-input tests use complete profile fixtures and still pass. The current local
saved configuration also passed the pure validator; no files or monitor settings changed.
No native source changed, so native compilation was not repeated. Not installed; physical
rotation requalification remains pending. Rollback and scope are in the matching plan.

The previously published fefcb6f CI run 35538506553 completed successfully; that CI result
does not cover this new unpushed change.
