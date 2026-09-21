# Keep Overview at the top after recovery

The recovery-to-ready demo exposed a blank region above Overview after recovery
sections collapsed. An isolated AppKit probe reproduced a 140-point top gap when
a non-flipped document became shorter than its 440-point viewport; the flipped
document had a zero-point gap under the same geometry.

Overview now uses a top-down stack document. This fixes the document coordinate
system without forcing a scroll on every status refresh. Recovery authorization,
polling and the preceding keyboard-focus fix are unchanged.

Validation:

- `./scripts/verify --native` exited 0: 297 Python tests, publication checks,
  native builds and isolated self-tests passed.
- A permanent native regression checks real clip/document coordinates while the
  document shrinks, grows and shrinks again.
- The current-source private demo began in recovery and changed to ready after
  Repair received keyboard focus. The resulting screenshot shows Overview at the
  top; accessibility inspection and the visible ring show focus on Overview.
- Capture `25-overview-top-after-recovery.png` remains in the ignored UI audit
  directory. Probe-only transition instrumentation is not in production source.

This checks Standard-text synthetic recovery-to-ready behavior. It does not prove
all scroll positions, VoiceOver speech, physical recovery, or installed behavior.
No installation or hardware command was performed.
