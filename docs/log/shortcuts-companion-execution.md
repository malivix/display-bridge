# Shortcuts execution through the companion process

An isolated build of source `d597793` passed actual Shortcuts discovery and
execution on the development Mac. This advances the integration gate beyond the
previous minimal synthetic app and direct `perform()`/reader tests.

## Isolation and scope

The probe compiled the real menu sources, startup, ownership lock, status entity
and App Intent. Private source copies changed only the fixed state root and CLI
path; the bundle received a private identifier/name and an existing local
development signature. The CLI stub recorded arguments and returned synthetic
capabilities. Controller files and command logs were disposable. No demo flag was
set, so ordinary companion startup and locking actually ran.

The first fixture location under Documents stalled in `open` during menu refresh,
as shown by a process sample. No permission was granted. Moving only disposable
fixtures and the command stub to a temporary directory allowed startup. This is
not evidence of a production state-reader defect or a confirmed permission cause.
The initial probe registration was removed narrowly; no system registry reset.

## Observed results

- Native action appeared in Shortcuts after launching/registering the private app.
- Warm execution returned distinct fresh and stale entity descriptions.
- All six typed fields appeared in Shortcuts. A following Get Text from Input
  action consumed observation freshness as `Stale`, `Unavailable` for malformed
  JSON, then `Fresh` after a valid current observation was restored.
- A duplicate executable exited successfully with the ownership-lock message;
  the original process retained the menu heartbeat. This covers an ordinary
  duplicate launch, not simultaneous distributed requests.
- After the original process was verified stopped, Shortcuts cold-launched the
  expected private bundle and returned the stale observation. The new process
  owned the heartbeat. Subsequent typed-field execution passed in that process.
- The stub received exactly two calls, both `capabilities`: one per owner startup.
  Status action invocations did not call the stub. No monitor/audio command ran.
- The probe's heartbeat reported denied notification authorization. Notification
  delivery and the first permission prompt were not qualified. Normal startup
  still writes its menu heartbeat and checks capabilities; the action itself is
  a read-only status projection.

Private AX captures, build manifest, process sample and argument log remain
ignored. The test shortcut contains only the private status action and text
consumer. The probe was stopped afterward and its synthetic health left
unavailable. No installed service, user monitor configuration or clipboard changed.

## Remaining boundaries

This is one development-signed private bundle with redirected paths, not activation
of the production bundle, public distribution qualification, all-macOS coverage or
Mac B testing. Missing files, oversized files and special-file rejection have
native regression coverage; only malformed/fresh/stale cases were exercised through
Shortcuts here. Discovery after production replacement and installed rollback remain
separate checks. Preserve those distinctions when adding bounded pause/resume.
