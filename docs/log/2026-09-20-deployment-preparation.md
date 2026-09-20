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
