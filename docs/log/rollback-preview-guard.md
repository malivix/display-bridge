# Rollback preserves queued preview requests

A regression test reproduced rollback continuing to service inspection while a preview
request was pending. Installation and rollback now share `require_idle_preview` in the
deployment module. Rollback checks under the exclusive installation lock before service
inspection, stopping services, creating an undo snapshot or restoring files. The installer
retains both its preliminary and locked checks. No recovery evidence is consumed or reset.

Validation: the new test failed before the fix for both a malformed queued request and a
dangling request symlink. `scripts/verify` then passed 232 tests, including preservation of
current app/agent/request bytes and backup inventory, existing rollback success/undo cases,
and installer completed-preview and lock-race regressions. Native checks were not repeated
for this Python-only deployment change. No actual rollback, service or hardware action ran.
