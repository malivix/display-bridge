# Restore permissions and relative links

Added a regression for metadata that matters when restoring executable helpers and app
bundles. A temporary snapshot contains a helper with mode 0751, an app directory with mode
0750, a read-only executable with mode 0555, a relative launcher link, an internal bundle
link and a dangling relative link. After replacing their contents/types and permissions,
staged restore reproduces the saved modes and raw link targets. Valid links resolve to
the restored contents; the intentionally dangling link stays a symlink. No staging
directories remain after restoration.

All twelve deployment tests and the complete `scripts/verify` suite passed: 297 Python
tests plus privacy checks. No runtime or native source changed. This qualifies POSIX mode
bits and symlink behavior in the temporary fixture, not ownership, ACLs, every extended
attribute, code-signing behavior on a deployed app, or a whole-installation rollback.
No installed files, services or monitor settings changed.
