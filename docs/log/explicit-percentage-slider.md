# Set an explicit brightness or volume percentage

Controls now offers Set percentage for the selected monitor. The native dialog separates
the requested value from previous readback, allows brightness or monitor-speaker volume,
and sends a command only after Apply. It starts with a proposed 50%, explicitly not a
current reading. Cancel/Escape discards the proposal. A modal timer and Apply recheck
availability; an observed loss permanently invalidates that dialog, requiring reopening.
The caller rechecks again before dispatch and the backend retains its own hardware guards.

`monitor-set` is capability-probed before dispatch. Its response must match both the target
monitor/feature and the requested percentage rounded to the reported native maximum.
Malformed or mismatched responses do not become confirmed readings. Existing step buttons
remain available. No continuous DDC streaming or speculative write coalescing was added.

An isolated demo at Largest text rendered the complete dialog, changed the requested value
with the keyboard, cancelled with Escape and reached the demo's hardware-blocking alert on
explicit Apply. The native slider's fine-increment property and help text were subsequently
added and compiled; the Option-arrow interaction was not separately visually exercised.
Actual ownership changes during a modal session and hardware latency remain unqualified.

Regression checks cover new-command rejection by older controllers, matching percentage
readback, wrong target value and missing percentage. `scripts/verify --native` passed with
290 Python tests and native builds/self-tests. No live installation, DDC change or playback occurred.
