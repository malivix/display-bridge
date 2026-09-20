# Reject blocking and redirected health state reads

A disposable FIFO named config.json caused the health report to block until the isolated
process timeout. Health-check JSON reads now open without following symlinks and without
blocking, validate the opened descriptor as a regular file, and enforce the existing 1 MiB
size cap before and after reading. Missing optional files remain optional. Rejected state
is reported and preserved; invalid configuration never proceeds to monitor inspection.

Validation: 239 Python tests and the exact-index privacy scan passed. The new subprocess
regression exercises a config FIFO, symlinked controls, a recovery directory and a dangling
menu heartbeat link, verifies error reporting without blocking, and checks file/target
preservation. Existing oversized-state tests passed. Native code was unchanged; no hardware
or installed services were exercised. This fix covers health JSON reads, not every possible
filesystem or helper wait. No configuration or recovery migration is needed.
