# Bound status reads on the menu thread

The menu now opens runtime state with no-follow/nonblocking flags, verifies that the opened
object is a regular file, and caps JSON input at 1 MiB before parsing. Oversized, malformed,
non-object, linked or non-regular inputs return no values. Unreadable health consequently uses
the existing unavailable-status presentation. Controller validation remains authoritative;
this does not add schema validation for every UI control field.

Validation: 210 Python tests and native builds/self-tests passed. New native coverage exercises
valid JSON, the size cap, malformed/non-object JSON, a symlink and a FIFO without waiting for a
writer. No state file is modified by the reader; no installed app or monitor settings changed.
