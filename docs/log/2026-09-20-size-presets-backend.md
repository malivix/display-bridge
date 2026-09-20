# Named orientation-specific size preset backend

Added a bounded versioned private preset store, explicit replacement, semantic mode matching,
and enrollment scope. Saving inspects qualified current modes with input/orientation checks
and a final mode readback; it writes no hardware settings. A dedicated writer lock and atomic
fsynced replacement protect concurrent saves. Corrupt or mismatched stores are preserved.

CLI preset-save and preview-start --preset use the existing preview service. preview-options
reports availability and fingerprints. The installed inventory includes the new module.
Native save/recall UI remains next; this is not a completed GUI preset workflow.

Validation includes fresh mode-ID resolution, two orientations, duplicate protection, private
permissions, invalid names/schema/counts, damaged store preservation, scope mismatch, unavailable
and ambiguous modes, writer contention, stale fingerprint rejection before hardware writes,
and the existing preview/restart rollback path. No installed configuration or physical display
was changed. Rollback and acceptance plan: docs/plans/named-size-presets.md.

Final validation: 201 isolated tests and source verification passed. Preset data is additive
local user state, left intact by installer/rollback paths; it is not part of runtime-file
replacement. An enrollment change makes the retained store unavailable instead of rewriting it.
