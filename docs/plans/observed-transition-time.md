# Measure observed transition latency

Add a monotonic interval from the first observation of a candidate input/orientation tuple
through a recorded success or failed attempt. Keep it pending across recovery retries, end
it after successful reconciliation, and discard it when candidate observations reset or
change. Periodic verification and later repair of an already completed candidate must not
reuse its old start time. The interval begins after input/sensor reads finish; physical motion,
handshake time before that observation and invalidated earlier candidates are unmeasured.

Expose the interval in recent history and completed-sample aggregates. Failed attempts may
include time waiting for a retry; they do not enter successful aggregates. The interval overlaps
settling and application phases and must not be summed with them. Missing older data stays
missing. No journal, ownership, polling or hardware mutation policy changes. Rollback is a
coordinated source release; older reports ignore the additional optional timing field.

Validate candidate changes, resets, retry retention, completed-candidate retirement, and the
controller's measured phase boundaries with a fake monotonic clock. Check typed native
presentation without physical playback or monitor changes.
