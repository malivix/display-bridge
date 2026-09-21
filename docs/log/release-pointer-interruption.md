# Abrupt termination at release-pointer replacement

An isolated subprocess now exercises `atomic_link` with SIGKILL immediately before and
after the actual filesystem replacement. Before replacement, the old release remains
reachable and the temporary link remains; afterward, the new release is reachable and the
temporary link is gone. Both cases preserve backup metadata, permit a retry, and restore
the old release from the saved snapshot without changing either release's contents.

The child runs only the pointer operation against temporary files. It does not run the
installer, launchctl, a controller, or a hardware helper. The injected failure is an
uncatchable process termination rather than an exception handled by installer cleanup.
`scripts/verify` passed all 294 Python tests and privacy checks. No runtime source changed;
native compilation was not repeated.

This establishes one pointer replacement boundary on the tested filesystem. It does not
establish power-loss durability, fsync guarantees, or atomicity across configuration,
LaunchAgents, menu installation and multiple executable links. Those remain qualification
gaps. Current Mac A software preflight passed, but fresh health still reported unrecognized
PG input, so no deployment or monitor changes were attempted.
