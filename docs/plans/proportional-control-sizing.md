# Make control geometry follow interface text size

The user's screenshot contradicts the earlier usability verdict: 24-point text was
placed in native fixed-height controls, with a small checkbox and an oversized plain
text comparison. Passing accessibility labels did not establish balanced geometry.

Use native flexible button bezels, larger native control sizes and minimum target
heights derived from text size. Share this sizing rule between the main controls,
size chooser and reusable text dialog. Replace the fixed tab strip with a native
segmented selector while retaining NSTabView as the single selection/content owner.
Shorten the visible comparison; keep complete estimates and limitations in details.
Keep Preview/Cancel and preset operations distinct and preserve keyboard behavior.

Check Standard/Large/Largest, minimum windows, keyboard section changes, Escape,
expanded details and failure states using a single isolated demo. Watch for clipped
labels, excess whitespace, constraint failures, and focus regressions. Do not lower
chosen text size to disguise layout failure. Capture images before acceptance.

No persisted schema or hardware policy changes. Roll back the coordinated menu and
controller snapshot if installed later. Do not install this review build as part of
visual checks. Other modal layouts still need their own proportional-sizing pass.
