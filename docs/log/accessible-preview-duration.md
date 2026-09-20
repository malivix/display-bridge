# More time to inspect readable display size

The size chooser now offers 20 seconds (default) or 40 seconds before starting a preview.
The options response advertises supported durations; older responses expose only 20 and
default requests omit the new CLI flag. CLI users can add --preview-seconds 40 to preview-start.
Both enqueue and daemon validate the choice before preparation; the journal persists it.
Confirmation begins after verified apply and cannot exceed the existing 120-second total
lifetime. Controller restart still restores, and older journals retain their default behavior.
The menu renders the controller's countdown instead of clamping it to 20 seconds.

Keyboard inspection found Tab stayed on the initial size selector. Recalculating the native
key-view loop before showing the modal fixed it. In the rebuilt Largest demo, Tab reached
the duration selector, arrow keys selected 40, further traversal reached the comparison,
scroll control, Preview and Cancel, and Escape returned to the main window. The picker and
all actions were visible without horizontal clipping. No preview was applied to hardware.

Validation: new journal tests failed first with the unsupported duration argument. Final
suite: 238 Python tests and all native builds/self-tests passed; the demo was rebuilt after
the focus-order correction. Coverage includes missing/invalid duration, legacy journals,
40-second persistence, late-but-valid Keep eligibility, expiry, hard cap, restarted service
restoration, options propagation and invalid requests rejected before preparation. Native
checks cover advertised duration parsing, old-controller fallback and the longer countdown.
Full VoiceOver/light-appearance and physical countdown/restore qualification remain pending.
No installed services or monitor configuration changed. Preserve journals during coordinated
upgrade or rollback; this is an additive field, not permission to reset recovery state.
