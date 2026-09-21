# Light appearance and focused refresh qualification

Built an isolated demo from clean source `e766f284a8dc363906b723160811018ab7aa3e80`.
Only its private Info.plist opts into light appearance with NSRequiresAquaSystemAppearance;
production source and the Mac's system appearance were not changed. This uses Apple's
[documented application appearance mechanism](https://developer.apple.com/documentation/AppKit/choosing-a-specific-appearance-for-your-macos-app).
The demo blocks backend commands and does not install or play audio.

Observed at Largest text, with the main window at its 600 × 480 minimum:

| Step | Capture | Observation |
| --- | --- | --- |
| 1. Overview | `19-light-overview.png` | Both monitor owners and selected output fit; text and controls remain visible. |
| 2. Audio | `20-light-audio.png` | Selected output, current preference and audio actions fit. |
| 3. Focused refresh | `21-light-focus.png` | Tab focused Preserve output. Command-R refreshed local demo status; the accessibility tree and visible ring retained that button's focus. No button was activated. |
| 4. Invalid percentage | `22-light-percentage.png` | 101 produced wrapped invalid feedback, disabled Apply and the expected accessible value description. Escape cancelled. |
| 5. Size chooser | `23-light-size.png` | Both monitor comparisons and actions visible at the dialog's default size. Command-Shift-P did not open the main menu while modal; Escape returned to Displays. |

These current-run screenshots remain under the ignored local UI review folder. The
inspection found no new layout defect in these cases. It did not measure contrast
ratios, test VoiceOver speech, inspect all failure states, exercise every key sequence,
or verify focus when a recovery action disappears. The size dialog minimum was tested
in the earlier dark-appearance slice; this run used its default size. High-contrast
appearance and live system-appearance transitions remain unqualified.

The exact source revision already passed published CI and native verification. This
run rebuilt the demo but did not repeat unchanged unit tests. Documentation updates
receive whitespace and staged privacy checks. No physical settings, clipboard,
notification, installation or controller command was issued.
