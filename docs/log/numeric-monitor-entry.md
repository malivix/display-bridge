# Numeric monitor percentage entry

The percentage dialog accepts an exact whole number from 0 to 100. The field is the
canonical proposal: valid edits update the slider; slider interaction updates the field;
blank or malformed text disables Apply. Feature changes use that feature's dated reading
or clear the field. Editing never dispatches a hardware command. The panel is taller to
keep the added field and actions visible at Largest text.

Validation: `scripts/verify --native` passed (290 Python tests and native checks).
Parser regressions reject empty text, whitespace, signs, fractions, exponent notation,
percent suffixes, non-ASCII digits and out-of-range values, while accepting boundaries.
A newly compiled isolated demo at Largest text showed typed 75 updating the slider and
enabling Apply, exact 101 disabling Apply, and deletion to empty keeping Apply disabled.
Escape closed without applying. No hardware setting changed.

Follow-up observed during inspection: Command–A did not select the field contents in the
panel. Investigate native edit-command routing before claiming complete keyboard editing
support. Numeric input and Backspace worked. VoiceOver speech and physical readback were
not tested. No installed release was changed.
