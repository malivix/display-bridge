# Distinguish unreadable controls from defaults

The bounded menu reader now returns failure separately from a valid empty object. Only a
missing optional controls file permits defaults. Unreadable controls mark preferences
unavailable, clear speaker selections, disable mutation controls/menu items, and reject new
setting commands at dispatch. Read-only inspection, quit and preview restoration remain
available. The warning overrides a stale Ready headline from otherwise fresh controller data.
Controller-side schema and hardware authorization remain authoritative; this change does not
claim complete UI validation of every field in otherwise parseable JSON.

Validation: 210 Python tests and native builds/self-tests passed on final source. Native
regressions cover missing-file behavior, unavailable action gating and headline precedence.
The controls-error demo confirmed disabled Pause/preview/audio controls, blank speaker choices,
and available Health/Diagnostics. Final headline and top-of-audio explanations were also
covered by source/build validation. No installed runtime, control file or monitor changed.
