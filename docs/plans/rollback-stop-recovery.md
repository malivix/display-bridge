# Recover failed stop observations during rollback

A service stop can take effect before launchctl fails, times out or is interrupted.
Record each attempted stop before dispatch, so the existing finally block restarts every
potentially stopped service. Keep the original error and leave files untouched when a stop
does not complete. Restart failures remain errors, not successful rollback reports.

Reproduce both first-service and second-service failures with a stateful fake service manager
and real temporary snapshots. Assert the original exception, restored running services,
unchanged files and no new undo snapshot. Rollback remains non-atomic across power loss;
this addresses caught failures only. No real launchctl or hardware calls in tests.
