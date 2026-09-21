# Compare readable sizes visually

Added Displays → Compare readability, opening two identical nonmodal sample windows.
Each contains 14-, 18- and 24-point text, an 18-point code sample and a 200 × 32 macOS-point
reference rectangle. Place one on each monitor to judge the physical relationship at
the normal viewing distance, then use existing size previews and Keep/Revert in the main
window. Fixed sample sizes intentionally ignore the main app's interface text preference.

`ReadabilitySamples` owns only AppKit windows. It reads no display identities or controller
state and issues no commands. It therefore remains available when automation is unavailable
and can safely be moved to an unfamiliar display without enrolling or managing it. It
retains at most two windows for the session, reopens closed samples and preserves their
positions. Closing samples does not change preview state or save a calibration.

The feature is a visual reference, not a millimeter ruler, Chrome replica, optical test or
automatic calibration. Existing model-based relative-size choices remain estimates. Saved
calibration tied to identity/orientation and a guided user comparison still remain open.

Validation: `scripts/verify --native` passed with 283 Python tests and native builds/self-tests.
The final sample scroll layout and removal of a deprecated NSBox property were separately
compiled, and the resulting menu executable's self-tests passed. In an isolated demo, both
samples rendered their identical contents, closed independently and reopened. The main
Displays action remained visible at Largest text and 600 × 480. A sample-window resize drag
did not change its dimensions through the UI adapter, so its minimum-size scrolling is not
visually qualified. Full VoiceOver, light appearance and physical cross-monitor comparison
remain unverified. No installation, display mutation or playback occurred.
