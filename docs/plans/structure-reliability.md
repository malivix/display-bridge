# Structure and reliability pass

Acceptance criteria: existing runtime entry points and installed layout remain compatible;
unit/native/physical tests are visibly separate; install-time tests use a disposable home;
menu commands have bounded output and execution time; documentation gives distinct install,
use, development, and recovery paths; all checks pass on a fresh hosted checkout.

Plan: move native sources and tests, update all build/test/source-manifest references,
reproduce unbounded menu execution with a hardware-free test, implement its watchdog,
and rewrite onboarding around the actual commands. Audit publication checks and review
remaining deployment limitations before committing. Record exact verification and limits.

Rollback: these are source-only changes. Git can revert them; no installed service or saved
hardware state is modified. Physical rollback and power-loss qualification remain separate.

Review amendment: complete the controller/menu rollback boundary. Snapshot directory contents
and companion LaunchAgent together, preflight backup contents before changing installed files,
stop/restart both services around rollback, and reject old/incomplete companion snapshots.
Use temporary-directory and fake-launchctl tests; do not exercise live rollback.
