# Installer failure boundaries around service shutdown

Prepare both maintenance and controller lock handles before stopping the old service.
A filesystem error opening the controller lock must not strand the running installation.
Check the rollback bootstrap result with a bounded deadline; do not hide restart failures.
Only say files were restored after the activated path actually restores them.

Use fake compiler outputs and launchctl calls with temporary state to inject a lock-open
failure and activation failure followed by restart failure. Verify original configuration
bytes and the service-call boundary. No installed services or hardware tests are involved.
Rollback is the previous installer source; no configuration migration is introduced.
