# Keep internal errors out of notification previews

The failure banner previously copied raw health/recovery errors into notification content.
Those errors can include machine details and may be visible in notification previews.
New banners now use static summaries for exhausted recovery, unsafe saved state and failed
size restoration, with an instruction to open Display Bridge for the current next action.
Detailed errors remain available inside the local status/report workflow.

The notification title and menu accessibility description now use Display Bridge. The
existing installed bundle and service namespace are unchanged; macOS notification settings
may still show Display Auto, as documented. This is not a bundle migration.

Native regressions inject private-looking error fields and verify that they never enter
banner text. Normal switching/recovery states return no notification body. Incident hashing,
deduplication, delivery callbacks and stale repair-click guards are unchanged. No permission
prompt or notification was sent during verification, and previously delivered notifications
are not claimed to have been removed. New behavior takes effect after coordinated deployment.

Validation: `scripts/verify --native` passed with 284 Python tests and native builds/self-tests. No live installation or physical operation was performed.
