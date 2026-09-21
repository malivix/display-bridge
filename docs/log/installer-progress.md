# Record installer stages and outcomes

The coordinated installer now records its latest attempt under install.lock, after initial
guards pass. The private report uses atomic replacement and mode 0600, with an attempt ID,
host/process/timing metadata, named phase, status and a distinct recovery observation.
It excludes raw exceptions, monitor identities and filesystem paths. It is not a recovery
journal: nothing resumes or retries based on this file.

Initial report creation must succeed before builds or service changes. Later write errors warn
once and cannot mask the original failure or interrupt rollback, even if stderr is closed.
Successful rollback commands are recorded as completed-unverified. Forced termination or lost
writes can leave the last running phase; neither a stored status nor PID presence proves live
progress. An explicit success marker is required for a completed outcome.

`python3 install.py A --status` reads and validates the latest report without creating state or
contacting hardware. Exit zero means report available, not installation succeeded. Wrong-host,
malformed, oversized/symlink-backed or excessively nested data cannot establish an outcome.
The report and temporary artifacts are ignored and rejected by publication checks.

Validation: 275 Python tests passed, including actual installer failure paths with synthetic
subprocesses, independent status inspection, preserved prior files, failed progress writes and
malformed reports. Staged privacy checks passed. Native code and installed services were not
changed. Graphical activation, process lifecycle and forced-termination recovery remain open.
