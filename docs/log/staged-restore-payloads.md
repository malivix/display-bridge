# Preserve current payloads when restore copying fails

Restore deleted each current file or app bundle before copying its backup. Injecting a
write failure left an incomplete file or removed the current bundle. Existing payloads
are now staged in a private temporary directory on the destination filesystem. Only a
completed copy replaces the destination; failed copies are cleaned up. Symlinks are also
staged, while intentionally absent backup entries still remove the destination.

The file and bundle regressions both failed before the change and pass afterward. They
assert preservation of current contents, cleanup and successful retry. Existing release
pointer interruption and coordinated rollback tests pass. `scripts/verify` passed all
295 Python tests and privacy checks. Interruption tests were then grouped under their
own test class; all ten deployment tests passed again after that organization-only change.

This is per-payload protection. Earlier entries and the current-release pointer may already
have changed when a later copy fails. Nonempty directory replacement still has a remove/
rename interruption window. Whole-restore atomicity and power-loss durability remain
unqualified. No real installation, service or hardware was changed.
