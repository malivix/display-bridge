# Direct monitor controls

Added a Controls tab with monitor selection, readback, and explicit brightness/volume steps.
Actions use the existing serialized controller/DDC boundary. Buttons disable while busy,
paused, stale, unsettled, or when the selected monitor is away. A shared availability helper
keeps adjustment gating consistent with the advanced menu. The backend still rechecks fresh
identity/input ownership before and after writes; the UI gate is not hardware authorization.

Readback now appears inline, including monitor and confirmation context, instead of a modal
after every successful adjustment. Advanced-menu actions navigate to the same result and
monitor selection. Switching the selector clears the previous monitor's result. Invalid
adjustment percentages are no longer presented as a successful zero value. Commands are
serialized, not queued on every pointer movement; a continuous slider remains deferred until
coalescing and physical pacing are qualified.

Native tests cover local/away selection, stale status, paused state, and busy state. The
hardware-free demo Controls tab was visually inspected and its accessibility tree exposes
selector and action names. No live brightness/volume adjustment was made; the outstanding
physical-input question remains pending. Demo screenshots stay ignored locally.

Validation passed: 191 Python tests, native builds/self-tests, whitespace and privacy checks.
The previous support-summary commit passed GitHub CI. This menu change is source-only until
its matching controller can be deployed; the installed unknown-input hold is unchanged.
