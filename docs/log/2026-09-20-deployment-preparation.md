# Deployment preparation

Pinned installer and verifier compiler environments to macOS 13.0, matching the documented
minimum and existing Swift/rotation/mode-helper targets. This prevents unpinned audio/DDC
builds from inheriting a newer compiler default. Explicit child environments are preserved.

Validation: 186 Python tests, native builds/self-tests, and privacy checks passed. The current
Mac A installation was inspected read-only: older source version, both displays local, fresh
ready heartbeat, no active pause or pending preview/audio recovery. It uses the earlier service
namespace, so migration requires a private backup and coordinated stop/move before installation.
No new physical qualification is claimed by this preparation commit.

The first migration attempt stopped before runtime replacement because an unrelated malformed
LaunchAgent raised XML ExpatError during namespace scanning. The verified private backup was
restored and previous services restarted. Added a failing regression, then extended the
existing malformed-plist handling to include the XML parser exception. The unrelated plist
is preserved. All 187 Python tests passed after the fix; no namespace checks were bypassed.

Mac A was subsequently upgraded from source revision 3dd6809 to installed version 2.10.2.
The private migration snapshot was validated before stopping/moving the earlier services.
Post-install comparison confirmed baseline, rotation profiles, audio mappings, enrolled keys,
and DDC identifiers were unchanged. Controller startup verification and fresh health passed.
The read-only doctor reported configuration, installed hashes, inputs, and both mode checks OK.
The new display-info command returned both local modes with fixed 120 Hz and HDR preference off.
These remain readback observations, not optical or audible qualification.

An older manually launched menu process survived service migration and raced the new menu's
heartbeat. Its exact executable was checked, then only that superseded process was stopped.
The managed menu subsequently reported fresh 2.10.2 status. This exposes an installer follow-up:
account for manually launched companion instances before replacing the app. UI automation still
resolved the old bundle identifier after registration refresh, so installed-window visual
verification could not be completed; the identical source UI was previously checked in demo.
No physical input-switch, rotation, or listening tests were performed in this upgrade session.
