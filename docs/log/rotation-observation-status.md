# Explain rotation freshness and waiting states

The controller now timestamps successful sensor observations independently of heartbeat writes,
including accelerated confirmation reads. Failed/deferred observations clear sensor confirmation;
bounced confirmation reports the latest angle without treating it as confirmed. macOS rotation
readback has its own timestamp and remains explicitly historical until read again. Private sensor
errors remain available for diagnostics and clear after a successful/deferred read or manual mode.

The dashboard and BenQ section share a formatter for paused/manual, ownership, setup, preview,
sensor-confirmation and recovery waits. Missing, old, future or malformed sensor timestamps cannot
produce a current-confirmation claim. Software readback is not physical orientation proof. This
changes observation metadata and presentation only; polling, locks and mutation gates are intact.

Validation: 267 Python tests, native builds and isolated self-tests passed. Coverage includes
independent timestamps, sensor failures/bounce, successful accelerated confirmation, malformed
native values, legacy missing fields and stale/remote/preview precedence. The isolated demo was
inspected in dark appearance at Largest text: the dated details remain readable when scrolled,
with recovery above them. Stale status removed the current-confirmation claim. That inspection
also exposed fresh synthetic sensor timestamps in the stale fixture; they were corrected and
covered by a native regression. Full VoiceOver and physical latency checks remain unqualified.

No installed controller, monitor settings, audio route or service changed. The demo bundle stays
private and isolated. In-flight phase updates and physical measurements remain later work.
