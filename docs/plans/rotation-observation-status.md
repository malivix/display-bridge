# Explain rotation observations

Expose the wall-clock time of the latest successful sensor reading separately from health
heartbeat time, and macOS rotation readback with its own observation time. Refresh these only
when their respective reads succeed. Failed, bounced or deferred sensor confirmation must
never leave a confirmed candidate displayed. Preserve old macOS readback as explicitly dated
historical information; it is not physical orientation or proof that the next write will succeed.

Use one native formatter for the dashboard and BenQ section. Distinguish paused/manual,
remote or unknown ownership, missing sensor, pending confirmation and recovery waits. Stale
heartbeat or missing/malformed timestamps prevent a current-confirmation claim. Older
controllers remain readable with unavailable freshness. No polling, ownership, mutation,
notification or persisted policy change. Rollback is a coordinated release.

Verify failed and accelerated sensor reads, independent timestamps, malformed native data and
status precedence using synthetic data. Native compilation does not qualify physical latency.
