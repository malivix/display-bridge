# Ownership and speaker summary in Overview

Healthy Overview previously required scrolling past an empty Recovery group to find
BenQ ownership and the selected speaker. Fresh ready status with no recovery now
places both owners and the selected output beside the desktop summary. Rotation and
audio policy remain separate. Non-ready, paused, stale and pending-recovery states
retain recovery before last-known ownership; no fresh observation is inferred from
the layout change. Empty groups are hidden in the existing view hierarchy.

Exhausted audio recovery now includes Check health beside Repair audio, matching the
existing instruction. The read-only action uses the existing doctor command boundary.
Repair still uses its click-time validation, and busy disables both actions. Stale
status presents the original single Health action without an extra Repair shortcut.

Validation: `scripts/verify --native` passed, including 297 Python tests and native
builds/self-tests. Presentation cases cover ready ownership, selected/missing output,
pending journals, paused and multiple non-ready states. The current synthetic demo
was inspected at Largest text and the 600 × 480 minimum main window: both ownership
summaries and selected output fit; switching to exhausted recovery exposed both
Health/Repair; switching to stale exposed only Health and last-known labels. Private
screenshots remain ignored. No hardware, audio, notification or clipboard command was
submitted; no software was installed.

Full VoiceOver, light appearance, long-name layout, all preview transitions and actual
hardware behavior remain unqualified. Existing repair-policy tests passed; screenshots
do not establish command completion or audible sound. No new CI result is claimed.
