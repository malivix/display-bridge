# Timed pause from the main window

The main Pause button previously requested an indefinite pause immediately; the timed
option was only in Advanced. Pause now opens explicit 15-, 30- and 60-minute choices and
Pause until resumed. The ellipsis and help text indicate a choice rather than immediate
execution. Resume remains direct. The compact menu's indefinite action is labeled explicitly.

All choices use the existing pause-for/pause/resume commands. No controller semantics,
configuration schema, permissions or hardware path changed. Existing timed-pause tests cover
expiry, clearing a timer with indefinite pause, Resume and invalid duration rejection.

`scripts/verify --native` passed, including 293 Python tests and native self-tests. A new
signed demo at Largest/minimum window size exposed all four choices in its accessibility
tree. Selecting 30 minutes reached the hardware-free command block; no pause was saved.
The paused scenario showed the direct Resume button and updated help. Popup screenshot
capture was unavailable, so this is accessibility/interaction evidence rather than pixel
qualification of that menu. No installed service or monitor settings changed.
