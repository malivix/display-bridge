# Accessible preset forms

Replaced Save/Remove NSAlert forms with adaptive resizable native panels. Instructions,
input/selector, replacement checkbox, errors and buttons share the selected interface
font. Invalid names remain editable in place; focus returns to the field and an
accessibility value-change notification accompanies the error. Validation follows the
backend's code-point count, whitespace and ASCII control-character rules. No truncation
or silent trimming occurs. Removal sends the selected name/orientation/revision through
the existing command boundary, with an explicit action rather than a Return shortcut.

This continues milestone 2; no persistence, schema, dependency or hardware-policy change.
The original revision checks, enrollment checks and atomic writes remain authoritative.
Rollback uses a compatible prior menu binary; presets and preview journals are preserved.
Backend command errors still use existing feedback and do not reopen the draft form.

Validation: 210 Python tests and native builds/self-tests passed. New pure regressions
cover 48/49 code points, leading/trailing whitespace, controls, combined accents and emoji.
After compacting the panel dimensions, rebuilt and reran native menu self-tests. Demo
inspection at Largest verified both forms, retained invalid text, correction reaching
the blocked demo command boundary, final empty-name error layout, portrait selection and
explicit removal reaching the same blocked boundary. No real presets or hardware changed.
Full VoiceOver, light appearance and physical preview qualification remain pending.
Not installed.
