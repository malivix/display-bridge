# Try relative physical interface sizes

Extended the existing matched-size proposals with targets for PG about 10% larger or
smaller than BenQ, and BenQ about 10% larger or smaller than PG. Each preserves the
reference monitor's current qualified mode and selects only from the other monitor's
already-qualified fixed-120-Hz, HDR-off HiDPI inventory. A choice must improve target
closeness and fall within five percentage points of the requested model estimate.
Missing choices are omitted rather than inventing custom modes.

The target is relative to the named reference: BenQ at 110% of PG is not PG at 90% of
BenQ. The reversed calculation is explicitly inverted. Zero-rounded ratios are rejected.
The existing native chooser consumes these proposals and reports the actual estimated
ratio; no new native command or independent mode-writing path was added.

Preview request validation accepts the four new identifiers. The service re-derives the
proposal from fresh inventory and checks its configuration fingerprint before applying.
Existing orientation/ownership checks, journaling, timed Keep/Revert and restart rollback
remain authoritative. To undo a kept choice, use a saved known-good size preset; source
rollback is a coordinated controller/menu rollback, not a rewrite of saved configuration.

Tests cover both reference directions and both relative targets, preserved reference modes,
invalid targets, degenerate ratios and service-level preview/restart rollback for larger-PG
and smaller-BenQ cases. These choices support visual experimentation but are not the planned
comparison ruler or a saved physical-calibration measurement. The user must still judge
readability and sharpness after eligible deployment. No live display changes occurred.

Validation: `scripts/verify` passed all 283 Python tests. Native sources were unchanged; no native build or physical qualification is claimed for this change.
