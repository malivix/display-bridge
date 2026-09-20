# Audio preference controls

Added an Audio tab with the selected output, per-profile speaker selectors, manual-output
preservation, resume, and repair actions. Existing controller commands remain authoritative;
the UI does not manipulate devices independently. Shared speaker choices keep the menu and
tab consistent. Unavailable monitor destinations are omitted for each profile.

Repair availability now has an explicit reason for stale status, busy commands, paused
control, active manual preservation, unknown ownership, and unfinished switching/preview.
The same gate is used by the advanced menu. Manual-preservation expiry is shown when active.
Text sizing applies to explanation/status fields; popup/button sizes remain native.

The hardware-free demo was opened and the Audio tab inspected. The accessibility tree
exposes each profile selector by name and shows its selected value. Tests cover away-profile
choices and repair gating. No live routing or preference changes were made. Actual audio,
full keyboard/VoiceOver navigation, and deployment remain separate qualification work.
Rollback is a menu rebuild; existing preferences and recovery journals remain unchanged.

Validation passed: 186 Python tests, native builds, menu/DDC self-tests, and privacy checks.
The preceding display-snapshot revision also passed GitHub CI. The demo screenshot remains
ignored/private; the standalone demo was closed after inspection.
