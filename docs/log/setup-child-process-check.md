# Exercise setup reporting with an actual child process

Added a native integration case using a temporary shell fixture, not the installer.
The child writes a bounded progress report containing its actual PID, waits on standard
input, and exits with status 7 after release. The production regular-file reader and
current-attempt formatter observe both the waiting child and its retained running report
after exit. The test also rejects that record for a later launch and checks that neither
observation claims completion. Missing initial report is covered before launch.

The temporary directory is private. Child waits are bounded, including a ten-second
shell read timeout, and normal cleanup closes pipes and kills a surviving owned child.
No descendants, installer, service operations, display/audio helpers or user state are
used. The fixture models a failed process retaining its report; it does not qualify
installer rollback, power loss, AppKit close protection or real hardware recovery.

Validation: `scripts/verify --native` passed with 279 Python tests and native builds/
self-tests. After adding the fixture's shell timeout, the setup executable was rebuilt
and its complete self-tests rerun. This narrows the prior subprocess evidence gap without
claiming full installer fault-injection coverage.
