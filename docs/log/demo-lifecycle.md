# Review lifecycle and duplicate menu icons

The reported duplicate icons came from 33 leftover private development demos and
probes. The installed menu had one process. The private processes were stopped;
the controller and installed menu remained running.

Demo builds now acquire a shared per-user review lock before opening windows,
create no status item, and terminate when their last window closes. More controls
uses an independent menu reference; the installed menu retains its background
behavior and separate ownership lock. The demo quit action is labelled Quit review.

## Validation

- Full `scripts/verify --native` passed: 306 Python tests, native builds and
  isolated self-tests. Physical tests were not run.

- A second demo with a different bundle identity exited while the first held the lock.
- More controls opened using its keyboard shortcut without a status item.
- Closing the first review ended its process; the second could then open normally.
- Closing the second review ended its process. Process inspection found no private
  review apps and exactly one installed menu process.
- Installer preflight passed without service or hardware changes. Installed doctor
  reported matching helper hashes, a ready extended profile, both inputs local,
  saved HiDPI modes, fixed 120 Hz and HDR off. Notifications remain disabled.

The installed version remains 2.10.2; checkout changes do not deploy automatically.
These observations do not replace audible/physical tests, Mac B qualification, or
power-loss testing. No installation or monitor configuration was changed here.
