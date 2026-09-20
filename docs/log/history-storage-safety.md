# Keep damaged history from blocking or replacing evidence

Reproduced a malformed history file being silently replaced on the next record. The recorder
now preserves unreadable or non-list existing history and raises the error already handled
by the controller's best-effort logging wrapper. History inspection and recording use bounded,
nonblocking, no-follow regular-file reads. Missing history still starts normally.

New history is serialized and checked against the 1 MiB limit before writing, using finite
JSON values and a unique private temporary file followed by atomic replacement. Temporary
files are cleaned up. The existing 200-event retention and report schema are unchanged.

Validation: 244 Python tests and privacy checks passed. Tests cover malformed/non-list/null/
oversized history preservation, oversized new events, normal private writes, temporary-file
cleanup, and FIFO/symlink rejection in bounded subprocesses without target modification.
Native code and installed services were unchanged. No physical tests were run.
