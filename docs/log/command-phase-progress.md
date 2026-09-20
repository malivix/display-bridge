# Accurate command-phase progress

The menu previously displayed one 45-second deadline while preset commands could first
spend five seconds probing compatibility. The runner now reports each phase before it
starts. The window shows Checking preset support with its five-second limit, then the
actual command with a new elapsed timer and 45-second deadline. Phase updates and completion
are posted in order to the main queue. Existing execution limits and hardware policy are
unchanged; failed probes still send no requested command.

Validation: `scripts/verify --native` passed 232 Python tests and all native builds/self-tests.
Injected-runner regressions assert ordered phase names/deadlines for accepted and rejected
probes, and one direct 45-second phase for legacy recovery. No hardware command or installed
menu was exercised. Actual runtime timing/visual qualification remains pending.
