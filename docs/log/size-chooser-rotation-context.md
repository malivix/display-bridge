# Rotation changes while selecting a size

An open size chooser now rejects a newer macOS rotation readback that differs from the
orientation of its inspected choices, even if controller status is ready again. The
existing modal validity latch keeps Preview disabled until fresh choices are opened.
Readbacks older than chooser construction cannot override its inspection. The check
uses existing local status only, validates native angle values and rejects boolean angles.
No new DDC or layout request was added.

Validation: `scripts/verify --native` passed, including 290 Python tests and native checks.
Native regressions cover contradictory newer readback, unchanged orientation, old readback
and invalid boolean values. No physical rotation or new UI timing test ran this turn;
modal latching was exercised separately in the preceding timed fixture. Missing rotation
status, events before chooser construction and changes missed by status observation still
rely on authoritative backend preview validation. No installed software changed.
