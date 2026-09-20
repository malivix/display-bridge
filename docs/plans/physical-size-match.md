# Physical-size matching through existing previews

First deliver an approximate model-based match with BenQ as the fixed reference. Choose only
an already qualified PG HiDPI mode within 5% of BenQ's physical length per logical point, and
only when it improves the current match by more than half a percentage point. Preserve BenQ's
current mode. Keep the existing fingerprint, ownership checks, 120-Hz/HDR-off qualification,
20/40-second confirmation and recovery journal. No new arbitrary mode IDs or hardware APIs.

Use ASUS's specified 919.68-mm active width and infer BenQ's long active dimension from its
28.2-inch diagonal and 3:2 aspect ratio. These are model estimates, not per-device calibration.
Compare long logical axes to handle portrait orientation. Record sources in usage/research.
Show current/proposed relative physical size in the chooser; unavailable fields remain unknown.
Later user calibration can improve the estimate, but do not claim calibrated matching now.

Tests cover both orientations, no close candidate, retained BenQ mode, malformed data and
unchanged existing relative choices. Route the new option through normal preview regeneration
and fingerprint checks. Inspect synthetic UI and run Python/native verification. Deployment
and physical readability checks remain separate; rollback uses the existing preview transaction.

Sources checked 2026-09-21:
- [ASUS PG42UQ specifications](https://rog.asus.com/ph/monitors/above-34-inches/rog-swift-oled-pg42uq-model/spec/): active area 919.68 × 517.32 mm.
- [BenQ RD280UG specifications](https://www.benq.com/en-us/monitor/programming/rd280ug/spec.html): 28.2-inch diagonal, 3:2 aspect ratio. Inferred long dimension is diagonal × 25.4 × 3 / sqrt(13), not a measured unit-specific width.

The reference can now be either monitor: match-benq keeps BenQ fixed; match-pg keeps PG fixed.
Both directions use the same selector, estimate and transaction. Changing BenQ also retains
the saved vertical center relationship through the existing layout proposal builder.
