# Independent service restart attempts

A bootstrap error in rollback's finally block previously skipped remaining service
restarts. Operational errors are now collected while the controller and menu each receive
their restart attempt. The final error lists failed services; an earlier rollback failure
remains its cause. Without an earlier failure, the first restart exception is the cause.
The successful-rollback message is not reached when restart fails.

Regression coverage uses actual rollback control flow, temporary snapshots and fake
launchctl. Controller-only, menu-only and both-service failures are exercised after both
successful restoration and failed verification. It checks both restart attempts and whether
the backup or undo snapshot supplies the final files. These six scenarios failed before
the change and pass afterward. Existing failed-stop recovery tests also pass.

`scripts/verify` passed all 292 Python tests and privacy checks. No native source changed,
so native compilation was not rerun. No real services, display settings or installation
were changed. This reports and limits partial recovery; it cannot make a failed service
start successfully or provide power-loss-atomic rollback.
