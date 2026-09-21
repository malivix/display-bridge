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
