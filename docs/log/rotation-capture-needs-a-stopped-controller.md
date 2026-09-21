# The second rotation capture races the controller

Capturing the orientation that differs from the saved baseline fails against a running
controller. Changing the macOS rotation makes `display-layout` refuse the saved baseline
with `Rotation changed for <key>; restore it and recapture; no changes applied`, so the
controller enters recovery. Capture writes the new baseline only afterwards, and the
verification it then runs rejects a pending recovery and, separately, an exhausted one.
Pausing does not help; a paused controller fails the same verification with
`Automation paused; resume before one-shot verification`.

Observed on Mac B: the landscape capture succeeded because that orientation already matched
the saved baseline. The portrait capture failed twice, first reporting
`Recovery exhausted; request repair-audio to retry`. Both attempts rolled back and left the
installation working. Requesting `repair-audio` cleared the exhausted flag but the retry hit
the same rotation mismatch, because the baseline it validates against is still the old one.

Stopping the controller before changing the rotation avoids the whole sequence: nothing
observes the mismatch, the journal stays clean, capture writes the matching baseline, and its
verification passes. The capture restarts both services itself. Enrollment then completed with
both profiles present, `enabled` true, and all doctor checks ok.

Documented in the installation guide rather than changed in code. The installer could stop the
controller for the duration of a rotation capture, or drop a recovery whose baseline it has
just replaced, but both touch recovery semantics that the invariants deliberately protect, so
neither belongs in an undiscussed change.

No code, tests or stored formats changed here. Sensor-driven rotation is still unexercised;
only the enrollment is complete.
