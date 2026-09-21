# Guided setup and coordinated activation

The installed menu cannot safely own the upgrade subprocess: the coordinated installer replaces
that same app. A future graphical activation flow needs a separate setup process, an explicitly
selected trusted checkout and host, preflight and hardware review, durable progress/outcome, and
an installer-owned recovery boundary. Closing the review must not install; closing a progress
window must not silently kill an active transaction. Do not treat a previously reviewed snapshot
as permission to skip fresh ownership, mode or pending-preview checks.

Before adding that entry point, fix the observed stop-service gap: the current installer issues
its first bootout before entering its rollback handler. A failed or timed-out stop may already
have stopped the service. Move that operation inside the existing recovery boundary, preserving
original files before activation and attempting the prior service restart. Test both stop error
and timeout with isolated synthetic subprocesses; do not stop live services during verification.

This slice does not add graphical activation or claim cancellation/crash safety. SIGTERM,
progress ownership, menu replacement and interrupted-process recovery require separate review
before the setup UI can offer installation. Rollback remains the existing snapshot/restart path.

## Installer progress contract

Record the latest attempt under the installation lock in private `install-progress.json`, using
an atomic replacement and restrictive file mode. Begin reporting only after pre-mutation guards
pass; failure before that point leaves the previous attempt's report intact. Include a unique
attempt ID, process ID, host, timestamps, named phase, outcome and recovery observation. Do not
include raw exception text, monitor identities or filesystem paths. This is observational data,
not an execution journal, permission to install or automatic crash recovery.

Initial report creation must succeed before builds/service changes. Later reporting failures
must not prevent rollback; warn once and preserve the real command outcome. Successful rollback
commands are labeled completed-unverified, not physically qualified. A missing process for a
stored running attempt means only that its process was not found; never fabricate success or
resume it. SIGKILL/power loss can leave the last phase recorded. Read-only `--status` must not
create state or run hardware commands and must reject malformed/wrong-host reports.
