# Explain recovery state and retry eligibility

Overview and Details now share a recovery summary for stale status, saved-state errors,
size restoration, paused work, unknown ownership, pending retries and exhausted recovery.
It shows the reported trigger/last error and ages the controller's relative retry delay.
Eligibility is conditional on stable ownership; it is not a guaranteed execution deadline.
Stale or invalid delay values never become a current countdown. No recovery policy changed.

Validation: 205 Python tests and native builds/self-tests passed. Native regressions cover
aged retry delay, stale state, pause, exhausted attempts, invalid delay and unknown input.
Largest-text demo inspection confirmed scrolling and readable retry/reason/error information.
The existing GitHub run for b2411b8 completed successfully. No installation/hardware changes.
