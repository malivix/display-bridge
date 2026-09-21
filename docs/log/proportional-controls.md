# Scale controls with their text

The user's screenshot exposed a real flaw in the previous visual review: enlarging
fonts alone left native bezels and the tab strip cramped, a checkbox undersized,
and the size comparison unnecessarily tall. The earlier claim that controls fit
was too weak to establish usable proportions.

`ControlSizing.swift` now applies a shared font, native size and minimum target
height to main-window controls, the size chooser and the reusable text dialog.
Flexible native button bezels accommodate taller content; the older enum spelling
retains the deployment target. This follows Apple's [flexible push-button guidance](https://developer.apple.com/documentation/AppKit/NSButton/BezelStyle-swift.enum/flexiblePush).
The native segmented navigation mirrors the existing NSTabView selection, including
keyboard and programmatic changes; it does not own another navigation state.

The main window's minimum height follows Standard/Large/Largest. Displays puts its
controls below the snapshot instruction instead of stranding them at the bottom of
an empty region. The size chooser's initial height follows text size. Its short
comparison keeps both monitor effects and the selected estimated ratio; full ratios,
framebuffer data and limitations remain in Show details. That disclosure is a padded
toggle with an explicit Hide details state. Action labels are shorter; Preview and
Cancel stay together, with preset management separately below.

Scope: the main window, size chooser and reusable text dialog. Other modal layouts,
localization and actual VoiceOver speech still need separate qualification. No
monitor, audio, persisted preference or hardware authorization behavior changed.

Validation of the final source: `scripts/verify --native` passed all 306 Python tests,
privacy checks, native helper/menu/setup builds, DDC checks and both normal and
CLI-demo self-tests. Final demo captures cover Standard/Large/Largest main windows
at their minimum sizes and each chooser at its initial size. Both monitor effects
and the selected estimate fit in each captured chooser. Expanded details, Escape,
Command-4 selection and Right-then-Space section activation passed. Captures remain
private. This is not installed or physical display qualification.
