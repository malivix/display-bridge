# Layout intent lives in the baseline, and only Swift compares it

Before this change, what a profile should look like was split three ways. The baseline held
modes, the third argument to `display-layout apply` held the mirroring rule, and the helper
turned that argument into five conditionals. Python's `matches` then re-derived the same
comparison to decide whether to call the helper and whether it had worked. The preview
verifier called `matches` too.

Now `derive_baseline` in the controller writes the whole intent for a profile to
`rotation-active.json`. A screen that keeps its own desktop carries its saved mode. A screen
that mirrors names its master in `mirrorOf` and carries the master's geometry, which is never
compared or applied. `display-layout apply BASELINE.json` takes no source argument. It
compares the live layout first and prints `{"changed":false}` without touching anything when
they already agree. Otherwise it mode-sets the sources, positions them, mirrors the rest,
reads the result back and prints `{"changed":true}`, or fails with `Layout readback
differs:` and the mismatches. `display-layout check BASELINE.json` runs the same comparison
read-only, and the preview verifier uses it. Python has no layout comparison left.

The file keeps its old name because the preview snapshot and restore payloads refer to it.
It is now written on every apply, including when rotation is not enrolled, and it is still
written by no read-only command.

The topology guard is set equality between the online and saved keys, plus a check that
saved keys are distinct, instead of a hardcoded count of two. A saved `mirrorOf` must name a
non-mirrored screen in the same baseline. Rotation and field validation apply only to
screens that keep their own desktop.

This change preserves behavior. The lid is not supported yet: any third display still idles
automation.

Tests: `display-layout --self-test` now runs in `./scripts/verify --native`. It covers
topology, mirroring in both directions, rotation alone, position, strict mode IDs, masters
missing from the baseline, mirror chains and the usage contract. Python tests cover the
derived baseline for each profile, the mirrored row's inherited geometry, and the helper
invocation with its `changed` result. The tests that asserted on `matches` now assert on
the derived intent, whose comparison moved into the self-test.

Physical, Mac B, lid closed, both monitors on this Mac: `check` and `apply` against a
baseline built from the live layout returned `matches:true` and `changed:false` with no
visible change. A 1-pixel offset was reported as `position differs`. With the controller
stopped, `test-layouts` passed `pg` in 1.12 s, `extended` in 1.29 s, `benq` in 1.56 s and
`extended` in 1.71 s. After restart, doctor reported `ok`, the log had no `Layout readback
differs`, and the layout was back to 2048 × 1152 and 1280 × 853 at 120 Hz, extended.
