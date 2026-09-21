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

## Read-only graphical outcome inspection

Expose `installation-status` before configuration loading and hardware/maintenance locks. It
reads the latest attempt on this Mac and labels the recorded host; it does not infer ownership
or authorize a new install. Keep explicit host filtering for the checkout CLI. Ship the reader
in the runtime inventory and capability-probe the new command before menu dispatch.

Add Last installation to Details and the menu. Use an allowlisted, typed formatter, showing
phase/outcome/recovery separately and hiding raw IDs/errors/extra fields. Missing or malformed
reports stay unavailable; a stored running record with a missing PID stays outcome unknown.
Cancellation of the view cannot cancel the installer. Rollback is a coordinated release; old
controllers must decline the new command gracefully.

## Independent setup application

`setup_gui.py` now builds a separate AppKit setup app from a committed source snapshot; real
builds require a clean trusted checkout. Archive extraction rejects traversal, links and special
files. The window requires an explicit role, validated software preflight and monitor-preparation
confirmation. Role changes invalidate the prior review. Installation uses the existing installer
as a subprocess with private regular-file output, preserving the installer as sole mutation owner.

The setup app holds ordinary Close/Quit during its owned task. It correlates progress by process
ID, host and attempt start time, and never substitutes an older record for a new attempt. This is
not forced-termination or power-loss recovery. There is no timeout that kills an active installer.
An unresponsive child requires investigation, not automatic restart. The recorded outcome and
private log remain the handoff; physical qualification is still required.

Demo mode never launches the installer and provides a bounded active-state simulation. Verify
Largest text, role invalidation, prerequisite gating, Close/Quit and completion in the isolated
window. Ordinary verification compiles the setup executable and runs model tests without UI or
hardware. A real bundled build must be checked after committing the source; do not activate it
while the live input prerequisite is unresolved.
