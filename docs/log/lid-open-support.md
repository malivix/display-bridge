# The enrolled built-in display mirrors the landscape external

Any third online display used to idle automation with `Saved PG and BenQ pair is not the
active two-monitor setup`. Opening the laptop lid is the ordinary way that happens. macOS then
mirrored the built-in display onto whichever external it last used, which on this enrollment
is the portrait BenQ.

`install.py <host> --capture-lid`, run with the lid open, records the identity CoreGraphics
reports as built-in (`CGDisplayIsBuiltin`, now in `display-layout status`) as `builtin` in the
configuration. It refuses an absent or ambiguous answer, a display already enrolled as an
external, and a host with no enrollment. The last check runs before the installer changes
anything. It captures no baseline, so capture's exactly-two requirement still holds for
the monitors. Saved baselines leave the `builtin` report out, because it identifies a panel
and is not layout intent.

The identity is top-level instead of the planned `keys.builtin`. About a dozen readers
across six modules treat `keys` as exactly the two externals, rotation validation among
them, and adding a third key would have made a valid configuration fail at startup.

With `builtin` enrolled, the controller accepts the online set of the pair plus the lid,
and still idles on any other extra display, on a missing external, or on duplicate
identities. While the lid is online, the derived baseline adds one mirrored row, built like
any other mirrored row. It mirrors the PG in `extended` and `pg`, because the PG never
rotates. It mirrors the BenQ in `benq`. In `away` nothing is applied. The externals' rows are
identical with and without the lid. The rotation helper takes the built-in key as an
optional fourth argument and allows that display, and only that display, to be mirroring.
The controller no longer releases mirroring before a rotation just because the lid is
mirroring, and still does when an external is mirrored. Doctor reports `Lid enrollment` as
`ok` or as `info` with the enrollment command.

Tests cover the lid target per profile including the PG-away fallback and portrait
geometry, the lid's row only while it is online, no row when not enrolled, topology
acceptance and rejection, `builtin_key`, the enrollment guard leaving the home directory
untouched, `validate_config`, rotation with a mirroring lid, and the doctor check. The Swift
self-test asserts `builtin` never affects layout equality.

Physical, Mac B, lid closed: installation succeeded, all four `test-layouts` transitions
passed (1.10 s, 1.28 s, 1.52 s, 1.75 s), there was no readback failure, doctor reported `ok`
with `Lid enrollment` as `info`, and the controller returned to `ready extended`.

Physical, Mac B, lid open. Before enrollment, macOS had mirrored the built-in onto the BenQ
and made the BenQ main, at (0, 0) with the PG at (1280, 0), and automation was idle. The
first `--capture-lid` enrolled the panel, but the installer's one-shot check failed with
`Layout readback differs: … position differs` for both externals, and the installer rolled
back. The mirror had been applied. The arrangement came back shifted by 1280 so that the
BenQ stayed main: CoreGraphics keeps the current main display at the origin when one
transaction changes mirroring and origins together. With the lid closed the PG was always
already main, so this never showed. A transaction of origins alone does move the main
display, so apply now re-positions the sources that way when they are still off. Reproduced
from the same state: lid mirroring the BenQ, BenQ main. The fixed helper printed
`{"changed":true}` and left the PG at the origin, the BenQ at (-1280, 0) and the lid
mirroring the PG, and a second apply printed `{"changed":false}`.

After that fix, enrollment succeeded. `test-layouts` passed `pg` in 1.65 s, `extended` in
2.00 s, `benq` in 2.04 s and `extended` in 2.43 s, each verified by the helper's own readback,
including the lid's target. The controller returned to `ready extended` with the built-in
mirroring the PG at 2048 × 1152. Doctor reported `ok`, with `Lid enrollment` as `ok`.

Not yet exercised: a BenQ rotation with the lid open, and opening or closing the lid while
the controller runs. Size previews still require the lid closed.
