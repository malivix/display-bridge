# Native named-size preset workflow

Preview size now opens a selector with the existing relative choices and available named
presets, paired logical dimensions, orientation, and unavailable reasons. A scrollable
comparison replaces an unbounded number of alert buttons. Selection submits the freshly
returned fingerprint through preview-start; timed Keep/Revert remains controller-owned.

Save current as preset opens a named save dialog with replacement unchecked. Copy explains
that it saves the currently displayed sizes, not the highlighted proposed choice. Successful
save feedback includes the saved name/orientation and states that display settings did not
change. The backend continues to validate ownership, qualification, names and replacement.

Validation: 201 Python tests and native builds/self-tests passed. Fresh hardware-free demo
inspection at Largest verified comparison/selector, unavailable orientation explanation,
name-field focus, and unchecked replacement. Submitting a demo name reached the blocked-action
message without issuing a backend command. Native alert headings/buttons retain system size;
full keyboard/VoiceOver and physical save/preview/rollback qualification remain outstanding.
No installed files or monitor settings were changed.
