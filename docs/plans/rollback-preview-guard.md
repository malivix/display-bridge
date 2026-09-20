# Shared preview guard for installation and rollback

Rollback must reject queued preview requests before service inspection, shutdown, undo
snapshot creation or restoration. Move the existing installer guard into deployment.py
and use it from both entry points under the installation lock. Keep the installer's early
pre-directory check. Existing unresolved/corrupt journal behavior remains unchanged.

Regression first: a valid coordinated backup plus a queued or dangling request must
preserve the current app, agent, request and backup inventory without calling service
commands or restore. Existing rollback success/undo tests remain required. No persistent
schema or runtime feature changes; rollback of this change is source-only.
