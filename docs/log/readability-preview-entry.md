# Size selection from comparison samples

Both readability sample windows now offer Choose a size to preview. The action delegates
to the menu app, brings Displays forward and requests the existing qualified options.
Samples stay open for comparison. The sample view owns no hardware command or mode choice;
existing preview fingerprints, journal and Keep/Revert behavior remain unchanged.

A shared readiness helper now governs the Displays preview button and sample callback,
rejecting busy, unreadable controls, stale, paused, non-ready and non-extended states.
The backend still performs authoritative fresh ownership checks before a preview.

Validation: `scripts/verify --native` passed (290 Python tests and native checks).
Native cases cover ready, busy, paused, unreadable, stale, away, one-local, recovering
and unknown-input states. A fresh demo showed the sample action at its default window
size; clicking it opened Compare display sizes with synthetic current/proposed modes
and confirmation time. Escape returned to Displays without starting a preview.
No hardware changes or installation. Physical readability, reference matching and
saved visual calibration still need their own qualification and implementation work.
