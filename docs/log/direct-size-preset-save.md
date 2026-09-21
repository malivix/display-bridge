# Save the current size from Displays

Displays now exposes Save current size directly, reusing the existing preset name dialog
and command. Eligibility checks require local ready extended state, readable controls,
no current command and reported preset-save support; the prompt rechecks on entry.
The backend still validates the saved snapshot and preset name at submission. The dialog
text now works from either entry point without referring to a highlighted preview choice.

Validation: final `scripts/verify --native` passed (290 Python tests and native checks).
Native cases cover supported, unsupported, unverified and busy presentation. A fresh demo
at Largest text and minimum window showed the new action with the other Displays actions;
it opened the existing name dialog and Escape returned without saving. The final wording
change followed that inspection and was compiled in final verification. No preset, display
setting, installed service or audio route was changed. Physical save/restore remains a
separate qualification; this change adds navigation, not a second persistence path.
