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

Not yet exercised: lid enrollment itself, each profile with the lid open, a rotation with the
lid open, and opening or closing the lid while the controller runs. Size previews still
require the lid closed.
