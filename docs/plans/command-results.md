# Controller command results

Extend the existing desired-settings boundary with a validated request ID. This is not a
second hardware queue: the controller still applies the latest saved settings under its
existing locks. Record at most 20 command results locally. New requests supersede unfinished
older requests; saved terminal results survive restart. A result identifies policy acceptance
separately from verified reconciliation. A heartbeat from before request consumption must
never complete it.

Force fresh reconciliation for resume, automatic audio, repair, and automatic rotation.
Pausing, manual overrides, and speaker preferences can acknowledge policy acceptance without
claiming audio playback or immediate physical effects. Unknown ownership, away rotation,
paused reconciliation, and failed recovery remain deferred/failed rather than successful.
Result storage is observability: if damaged, preserve it and report tracking unavailable;
do not erase it, reset recovery, or prevent the existing controller from operating safely.

Test supersession, restart, malformed records, missing files, bounded retention, terminal
stability, and actual controller publication. Rollback removes presentation/tracking use;
original control preferences and recovery token remain authoritative. No hardware operation
is replayed by reading a result. Tracking has no expiry that silently cancels desired settings.
