# Accessible size comparison

Replaced the size chooser alert with a resizable native modal panel. Instructions,
selector, comparison and action buttons use the selected interface font. The comparison
updates when the choice changes, showing current/selected logical dimensions, framebuffer
dimensions and a per-monitor size estimate. Missing or invalid dimensions produce an
unavailable estimate. Unavailable presets include their orientation. The existing request
fingerprint and preview service remain the only apply path; the timeout is unchanged.

Scope follows milestone 2 in ui-next-milestone.md. The panel uses an isolated presentation
class and pure comparison function. No backend, dependency, persistence or schema change.
Rollback is the compatible prior menu binary; preview journals remain untouched.
Separate Save/Remove preset dialogs still use native alerts and need further accessibility
work; this does not claim completion of the full size-workflow milestone.

Validation: the initial native self-test caught Swift integer-versus-JSON numeric bridging;
fixed conversion and rejection of non-finite/non-integral/out-of-range dimensions. Final
210 Python tests and all native builds/self-tests passed. Regression checks cover larger,
smaller, unchanged, missing values, non-finite values and framebuffer presentation.
The isolated demo uses differing synthetic choices. Visually confirmed immediate 25%
comparison updates at Largest text, minimum 600×620 window with visible action buttons
and scrollable content, and Escape returning to Overview without an apply request.
Full VoiceOver, light-mode and physical preview qualification remain pending. Not installed.
