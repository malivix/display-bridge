# Read-only display details

Added `display-info` and a Displays tab with an explicit Refresh action. The snapshot
compares two mode inventories and brackets them with input reads, rejecting changed inputs,
changed modes, extra displays, or ambiguous identities. Only locally visible enrolled
monitors receive mode details. Output excludes device keys and local mode identifiers.

Logical/framebuffer dimensions, HiDPI, refresh, fixed/variable metadata, HDR preference,
and saved-mode comparison are distinct fields. Missing private metadata stays unknown;
readback does not claim native sharpness or optical HDR. Rotation selects the saved layout
for both monitors, not just BenQ. The user explicitly refreshes; there is no new polling load.

Tests cover mode/input changes, identity/topology, unavailable metadata, invalid numeric
fields, away screens, and orientation-dependent baselines. The CLI race test confirms all
helper calls are read-only status requests. The demo Displays tab was clicked/refreshed and
visually inspected with synthetic measured/saved values and an unavailable monitor. No real
hardware inspection or settings changes occurred. UI snapshots remain ignored locally.

Rollback removes the menu/CLI snapshot feature; no state format changes or device writes.
The new module is included in the installed inventory. CI for the previous dashboard commit
completed successfully before this work was committed.

Validation passed: 186 Python tests, native builds, menu/DDC self-tests, staged privacy and
secret checks, and whitespace checks. The hardware-free demo was closed after inspection.
Real mode readback remains to be qualified after deployment.
