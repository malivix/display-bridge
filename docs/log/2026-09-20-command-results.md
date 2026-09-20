# Controller acknowledgements and durable outcomes

Added validated request metadata to the existing desired-controls file. Controller health
publishes matching request outcomes; the menu distinguishes acknowledgement from verified
reconciliation. Settings that affect later profiles are acknowledged as policy, not playback.
The bounded local history retains 20 observed requests, supersedes unfinished older work,
and preserves terminal results on restart. Requests overwritten before controller observation
are not individually journaled; the menu follows the latest desired request. This is not a
second execution queue and does not promise exactly-once hardware operations.

Unknown inputs, unavailable setups, manual audio preservation, unavailable rotation sensors,
and exhausted recovery cannot produce an unconditional verified result. Tracking failures
preserve damaged evidence and surface a separate error; existing hardware policy remains
independent. The controller manifest includes the new module and private diagnostics include
the result history. No installation or physical display changes were performed.

Validation includes isolated history/policy tests and an integration test through the real
watch loop and health publication with hardware replaced by mocks. It checks that the first
heartbeat does not acknowledge a new request and reconciliation precedes verified output.
The complete Python suite now has 179 tests. Native UI tests cover request-ID matching and
tracking-unavailable presentation. Physical and visual qualification remain pending.
