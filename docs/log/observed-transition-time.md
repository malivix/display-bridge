# Include settling and retry waits in transition timing

Transition reports now show First observation to outcome for recent attempts and First
observation to ready for completed aggregates. The monotonic interval belongs to the latest
uninterrupted candidate. It survives retries, resets with candidate changes or invalidated
observations, and retires after successful reconciliation. Routine checks do not reuse a
completed candidate's start time. Failed attempts remain outside successful aggregates.

The interval includes settling and work before application starts, overlaps application phases,
and cannot be summed with them. Physical motion and handshake time before its first reading
remain unmeasured. Older records keep the metric unavailable. Sensor freshness and detailed
rotation wait-state presentation remain separate work; polling and mutation policy are unchanged.

Validation: 265 Python tests passed, including a fake-clock controller retry that records
4.25 seconds observed-to-ready versus 1 second application time. Tests also cover invalid
values, missing older records, candidate changes, retirement and failed-phase projection.
Native builds and isolated presentation/self-tests passed. No hardware, installed controller,
audio route or service was changed, and no physical latency improvement is claimed.
