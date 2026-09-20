# Service-stop failure boundaries

The installer prepares both lock handles before stopping the old controller. Opening the
controller lock after shutdown previously allowed a filesystem error to bypass rollback.
Rollback restart now checks the subprocess result with a ten-second deadline instead of
ignoring nonzero exit status. Failure messages distinguish pre-activation rejection from
actual restoration of prior files.

Validation: `scripts/verify` passed 231 tests. New tests generate synthetic compiler outputs
and fake launchctl responses in temporary directories. An injected controller-lock open
failure makes no service calls. An activation failure restores original configuration;
an injected bootstrap failure propagates explicitly. No compiler, actual launchctl, monitor
or installed service was exercised in these tests. A successful bootstrap alone still does
not prove the recovered controller is healthy; physical upgrade qualification remains open.
