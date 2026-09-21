# Capture re-requests recovery instead of inheriting a stale attempt count

The earlier log for this failure concluded that stopping the controller by hand was the
remedy and that no code should change. That reading was incomplete: the installer already
stops the controller (`stopping-controller` phase) and restarts it afterwards, so a running
controller is not what defeats the capture.

What defeats it is the recovery journal. Changing the macOS rotation makes `display-layout`
refuse the saved baseline, the controller records three failed attempts in the window before
the installer is started, and `attempts >= 3` reads as exhausted. Capture then replaces
`baseline.json`, but the attempt count from the previous baseline survives, so the one-shot
verification raises `Recovery exhausted; request repair-audio to retry` without ever trying
to reconcile against the baseline just written. Stopping the controller by hand only worked
because it froze the counter below three.

`requeue_recovery` now re-requests a pending recovery after the new configuration and
baseline are written. `Recovery.request` resets attempts and the last error while keeping the
journal, its saved inputs, profile and orientation, so verification retries against the
current baseline. Recovery that is not pending is left alone; the installer never invents
work, and the journal is never dropped.

Tests assert an exhausted journal becomes pending with zero attempts and no error while its
state, profile and orientation survive, and that an absent journal stays absent and is not
created. The first fails against the previous implementation, which left the journal
exhausted.

Rollback restores the stale attempt count and the failure with it.

Validation: 312 Python tests and `./scripts/verify --native` pass. The physical sequence was
not re-run; the monitor is enrolled in both orientations and reproducing the failure needs it
physically turned again. The installation guide no longer tells the reader to stop the
controller.
