# Inspect difficult window states without hardware changes

Added demo-only synthetic ready/stale/paused/away/preview/recovery states and a minimum-window
control. The demo still blocks backend commands, notifications, runtime reads and heartbeat
writes. Fixtures do not model hardware recovery or advance a real preview transaction.

At 600 x 480 window size and Largest text, fresh demo inspection confirmed preview instructions
scroll and Keep/Revert stay visible. This also exposed the need for a countdown outside the
status tab: the Keep button now includes remaining seconds on every tab, using the existing
freshness-aware countdown function. Stale/expired previews retain existing disabled gating.

Validation: final source passed 192 Python tests and native builds/self-tests. The final
countdown label was visually checked at minimum size/Largest; recovery selection removed
Keep/Revert and showed the recovery headline. Physical
preview/rollback, VoiceOver navigation and light appearance remain unqualified; no installation
or hardware changes were made. Rollback is the previous menu binary; no state migration.
