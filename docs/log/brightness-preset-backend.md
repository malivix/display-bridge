# Brightness preset backend and CLI

Implemented save/list/apply/remove for named, enrollment-scoped brightness values per
monitor. The bounded versioned store uses private atomic writes, explicit replacement and
revision checks. Corruption, a changed enrollment, stale revisions and changed hardware
ranges are rejected. Save reads brightness only; list/removal do not access hardware.
Recall shares existing ownership checks, DDC locking, settling and one-write readback with
step adjustments; no retry, gamma fallback, input switch or automatic scheduling is added.

The CLI uses existing preview mutation/maintenance guards. Configuration is now read under
the maintenance lock for the shared monitor-control path. The installed module inventory
and private diagnostics include the new module/store. Existing deployment snapshots do
not restore additive preset stores; the file is left in place, as with size presets.
The Controls chooser is not implemented yet. No installation or physical test was performed.

Validation: 220 Python tests passed. No native source changed. Isolated tests cover store scope, corruption, permissions, failed replacement,
entry limits, revision changes, other-monitor preservation, changed input/range, readback
failure and no-op recall. A CLI integration test verifies save/apply/list/remove, paused
mutation rejection and no hardware access for list/removal. Existing monitor adjustment
regressions and diagnostic inclusion remain covered.
Rollback and UI follow-up are in docs/plans/brightness-presets.md.
