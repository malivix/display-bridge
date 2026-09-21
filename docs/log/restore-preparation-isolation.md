# Prepare all restore copies before mutation

Per-payload staging protected the failing destination, but an earlier payload and the
release pointer could already have changed. Restore now stages all existing backup
entries under one cleanup scope before switching the pointer or touching destinations.
Entries marked absent are also left intact until copying completes.

A regression injects failure while preparing the second file, after an entry that will
eventually be removed. It failed before the change and now confirms that the pointer,
both current files and the removal candidate remain unchanged; all staging directories
are cleaned up. A subsequent retry restores both files and the pointer and removes the
intentionally absent entry. `scripts/verify` passed all 296 Python tests and privacy checks.

The improvement requires space for all prepared replacements at once. Copy failure occurs
before live mutation. The replacement phase is still not atomic across entries, and a
directory removal/rename gap remains. Existing snapshots are compatible; no schema or
installed state changed. No hardware or real service commands ran.
