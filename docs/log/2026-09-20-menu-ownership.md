# Single-owner menu and upgrade guard

The live namespace migration exposed an unmanaged old menu process surviving launchctl
bootout. Added an activation regression that failed against the old implementation. Menu
activation now waits for both the service registration and processes at the exact app
executable path to disappear before renaming files. A timeout leaves app files untouched
and restores the prior managed service state. Unrelated applications are not terminated.
Process-list inspection failure also stays inside the rollback boundary.

The native app now holds a per-user file lock for its lifetime before creating status UI,
notifications, or heartbeat writes. Duplicate starts exit and activate an existing app with
the same bundle identifier. Demo mode remains isolated and bypasses the runtime lock. The
lock file is never unlinked by normal execution; process exit releases kernel ownership.
Old builds do not honor this lock, which is why the install-time process guard is also needed.

Tests cover blocked replacement/restored service, exclusive native ownership, and ownership
release. This does not make installation power-loss atomic. Rollback is the prior app/source;
controller and display/audio journals are untouched by these changes.

Validation passed: 188 Python tests, native builds, DDC/menu ownership self-tests, and staged
privacy checks. Previous published revision CI also completed successfully.

The menu-only update was installed on Mac A after a validated private app/agent snapshot.
Live checks confirmed exactly one menu process and an exclusively held menu lock. Both
heartbeats were fresh at 2.10.2. During this check PG reported an unconfigured input, so the
controller reported waiting-for-known-input and held layout changes; no input mapping was
guessed or altered. Physical ownership clarification is pending. Controller code/settings
were not changed by this menu update. Added plain-language wording for this held state.
