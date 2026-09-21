# Size chooser context validity

The size chooser now observes local readiness in its modal run loop. The first observed
unavailable reason invalidates its old choices until the dialog is reopened. Preview is
also checked at submission. Reference changes cannot clear invalidation; Cancel remains
available. This adds no DDC calls and does not replace backend ownership/fingerprint checks.
Short transitions missed between local status observations remain a backend responsibility.

Validation: `scripts/verify --native` passed (290 Python tests and native checks).
Native regressions verify a first failure stays latched through restored readiness and
later reasons, and a newly created context starts clean. An isolated AppKit fixture using
the real SizeChooser reported readiness loss at four seconds and restoration at eight.
The UI initially enabled Preview, then showed the reason and disabled it. After restoration
it remained disabled; Return did not submit, and Escape closed the fixture. Largest text
kept the warning and Cancel visible. No controller or hardware commands were connected.

The first standalone fixture timed out during UI observation because its startup sequence
was unsuitable; the corrected fixture used normal application launch before opening the
modal. Owned fixture processes were cleaned up. No installed software changed. Physical
input-switch timing, missed observations and other hardware scenarios remain unqualified.
