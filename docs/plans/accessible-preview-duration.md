# Bounded accessible size-preview duration

Offer 20 seconds (existing default) or 40 seconds before starting a size preview. Advertise
supported durations in the read-only options response; older responses expose only 20 and
the menu sends no new flag for that default. A nondefault request must be validated by both
the enqueue boundary and daemon before hardware preparation, then persisted in the journal.

The watchdog retains its existing 120-second total lifetime. Confirmation time begins only
after verified apply, and is truncated by that lifetime. Menu closure never owns restoration;
a controller restart still restores instead of resuming a preview. Existing journals missing
the new optional field retain 20-second behavior. Invalid durations preserve recovery state.

Tests cover persistence, expiry, hard cap, restart, old journals, malformed duration and
service propagation. Inspect the enlarged picker and Escape navigation in the isolated demo.
No physical tests or installation as part of source verification. Rollback replaces the
coordinated controller/menu; preserve journals and let existing hard deadlines govern recovery.
