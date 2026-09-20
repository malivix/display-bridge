# Keep setup inspection responsive with damaged state

Reproduced a blocking health report with a FIFO at config.json in a disposable directory.
Open health-check JSON state with nonblocking/no-follow flags, then validate the opened
file descriptor as a regular file and enforce the existing 1 MiB bound before reading.
Missing optional files remain optional; dangling links and other unexpected file types
are errors. Never remove or rewrite the rejected state or query monitors after invalid config.

Regression runs the report in a bounded child process against pipes, links and directories,
asserts explicit errors and preserves target bytes. Existing report and native UI checks
continue to apply. This covers JSON state reads, not a blanket guarantee about arbitrary
helper executables or all hardware waits. Rollback restores the Python module; no migration.
