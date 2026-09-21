# Explicit percentage intent and accessibility feedback

The slider retains a numeric position even when the text field has no valid request.
Previously its accessibility value could therefore suggest 50 or the last valid edit
without describing the absent/invalid intent. The chooser now exposes a human-readable
value description and changes the slider label when no valid request exists. Visible
feedback distinguishes empty, invalid and valid entries and wraps at the selected font
size. Text-field help carries the same feedback. Apply validation and hardware dispatch
are unchanged; the retained slider position is still not a hardware reading.

The implementation uses Apple's documented
[accessibility value description](https://developer.apple.com/documentation/appkit/nsaccessibilityprotocol/accessibilityvaluedescription%28%29)
for the raw numeric value's human-readable context. It does not replace the native
slider actions or force unsolicited speech announcements.

Validation: `scripts/verify --native` passed with 297 Python tests and native
builds/self-tests. New pure feedback checks cover blank, invalid bounds/formats and
valid boundary values. In the current Largest-text demo, the accessibility adapter
reported No percentage chosen for empty input, Invalid percentage for 101, and
Requested: 55% for corrected input. Apply stayed disabled for empty/invalid entries.
Changing to unread speaker volume cleared intent and its accessible description;
Escape returned to Controls without applying. The invalid feedback fit at Largest.
The private screenshot remains ignored. No hardware command, sound, notification,
clipboard action or installation occurred.

These checks establish exposed accessibility metadata and observed editing behavior,
not VoiceOver speech, every keyboard sequence or full accessibility compliance. Light
appearance and physical qualification remain pending; no new CI run is claimed.
