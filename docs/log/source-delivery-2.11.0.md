# Source milestone 2.11.0

The source version and companion bundle build now distinguish this milestone from
2.10.2. The controller and bundle continue to share the canonical release manifest;
source fingerprints identify exact revisions within a version.

Changes since the preceding published source:

- Recovery actions preserve keyboard focus when disappearing, Overview stays at
  the top after recovery, and keyboard-focused controls scroll into view.
- Native Shortcuts can read typed local status and submit bounded timed-pause or
  resume requests through the existing CLI. Demo entry points share isolation.
- Optional explicitly signed builds extract and validate metadata; the standard
  ad-hoc installer remains supported without native Shortcuts metadata.
- Private integration checks cover typed results, relevant failed submissions,
  companion cold launch and duplicate ownership. Control outcomes return directly
  after a dialog wait was found and removed.

The source release does not assert installed deployment or all-device qualification.
Production activation, Mac B, headset transitions, VoiceOver speech and high-contrast
coverage remain open as documented in the current plan. No tag, binary distribution,
notarization or public signed artifact is created by this source milestone.

The full staged/history privacy scan passed before this milestone. Local native
verification of the feature source passed with 305 Python tests; version consistency
is rechecked after the manifest update. Remote CI is a separate post-push gate.
