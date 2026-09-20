# Menu feedback and trustworthy status

The active product roadmap begins with command feedback and status correctness. This slice
changes presentation only: show an operation and elapsed time as soon as a command starts,
mark old or unconfirmed display/audio details as last known, show heartbeat age, and route a
notification-body click to status. Busy notification actions open status instead of silently
being dropped. Stale heartbeat disables audio-repair and preview-repair menu entries.

A native self-test first failed on an expired heartbeat whose monitor ownership lacked a
nearby stale label. After the change, it passes together with missing/future/nonfinite time,
paused status, and notification action mapping cases. The notification mapping is a pure
function used by the callback; actual notification delivery still needs UI qualification.
The existing command deadline tests also pass.

This does not implement controller acknowledgements: the UI explicitly says a saved request
is not tracked to completion. Durable command outcomes and notification incident deduplication
remain next work. No hardware policy, persistence format, installed app, or device settings
were changed. Rollback is a source revert/rebuild of the menu; recovery journals stay intact.

Validation completed: `scripts/verify --native` passed 172 Python tests, all native builds,
DDC self-tests, command deadline/output tests, new menu presentation/routing tests, and
staged privacy/secret checks. The installed UI was not replaced; visual and notification
interaction checks for this source revision remain pending.
