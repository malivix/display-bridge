# Validate monitor results before presentation

Observable result: invalid or mismatched CLI output never becomes a confirmed reading or a
zero default. Validate monitor-settings, monitor-adjust and brightness-apply against the
requested role/feature and monitor_controls.py contract in one typed menu boundary.
Require bounded integer raw values, positive maximum, consistent ties-to-even percent,
actual JSON booleans and consistent before/changed metadata. Allow additive report fields.

Render successful typed results; retain only one previous valid reading on failure, marked
not refreshed. Handle nonzero exit and malformed success without retrying hardware work.
Use a synthetic failure scenario for enlarged UI review. Isolated native regressions cover
missing/wrong fields, booleans masquerading as numbers, mismatched targets and bounds.

No backend policy or runtime schema changes. Rollback restores the menu build alongside a
compatible controller. No installation or physical display test is part of this source slice.
