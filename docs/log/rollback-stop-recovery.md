# Rollback restarts services after failed stop observations

Rollback recorded a service for restart only after launchctl returned successfully.
A stop that took effect before a timeout, command error or interruption could therefore
leave the controller or menu stopped. The restart list now includes each attempted stop
before dispatch, matching the recovery boundary already used by installation.

The regression drives real rollback control flow and temporary snapshot files with a
stateful fake launchctl. All six cases failed before the fix: first or second stop,
each with a command error, timeout or keyboard interruption. All passed after the fix,
asserting restored service state, the original exception, unchanged current files during
restart, no restore call and no new undo snapshot.

`scripts/verify` passed all 291 Python tests and privacy checks. No native code changed;
native compilation and physical tests were not rerun. No real service, installation or
display state was touched. Restart itself can still fail and is reported as an error;
this change does not provide power-loss-atomic installation or rollback.
