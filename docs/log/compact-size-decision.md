# Compact display-size decision

The chooser previously placed a long physical-ratio explanation and framebuffer data
before the second monitor. It now presents each monitor's current/selected dimensions
and interface effect first. A checkbox reveals framebuffer detail and unavailable
preset reasons. Physical comparisons say larger/smaller instead of requiring the user
to interpret a ratio. Estimates still do not measure optical sharpness or distance.
Preview/Cancel share a row, separate from save/remove. Preview dispatch, reference
filtering, eligibility latch, durations and persisted journals are unchanged.

Included the existing demo fixture correction: portrait health and preview modes now
agree, and the synthetic named preset includes the physical estimate. This avoids a
fixture invalidating its own choices without changing production controller policy.

Validation: `scripts/verify --native` passed, including 297 Python tests and native
builds/self-tests. Presentation assertions cover larger/smaller/same effects, invalid
estimates, and framebuffer detail inclusion/exclusion. The isolated current-build demo
was inspected at Largest with the chooser resized to its minimum size. Both monitor
summaries and Preview/Cancel were visible; reference filtering kept BenQ unchanged;
Tab reached the details checkbox and Space disclosed the framebuffer and unavailable
preset reason. Escape returned to Displays without submitting a command. Private
screenshots remain ignored. No installation, monitor write or sound test occurred.

Full VoiceOver/light appearance, all modal context transitions, physical preview and
Mac B remain unqualified. The existing validity tests passed; this UI session did not
simulate ownership changing while the dialog was open. No new CI run is claimed.
