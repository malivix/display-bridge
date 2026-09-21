# Mirror the built-in display when the lid is open

Observed: any third online display makes automation idle with `Saved PG and BenQ pair is not
the active two-monitor setup`. Opening the laptop lid is the ordinary way that happens, so the
controller stops reconciling for as long as the lid is open, and macOS mirrors the built-in
onto whichever external it last used. On this enrollment that is the BenQ, which is portrait,
so the built-in shows a portrait desktop letterboxed onto a landscape panel.

Wanted: the built-in mirrors the landscape external while the lid is open, and the controller
keeps reconciling in both lid states.

## Intended behavior

With `E = {pg, benq}` enrolled and `L` the enrolled built-in:

| Online set | Behavior |
| --- | --- |
| `E` | unchanged from today |
| `E ∪ {L}` | the profile's layout, plus `L` mirroring its target |
| anything else | idle, as today |

Mirror target by profile:

| Profile | PG | BenQ | Built-in |
| --- | --- | --- | --- |
| `extended` | own desktop | own desktop | mirrors PG |
| `pg` | own desktop | mirrors PG | mirrors PG |
| `benq` | away | own desktop | mirrors BenQ |
| `away` | away | away | untouched |

The PG is the target whenever it is present because it never rotates, so the rule is a
constant rather than a function of live rotation. The BenQ is the target only when the PG is
away. When both are away nothing is applied and the built-in keeps its own desktop.

## Stage A: one source of truth for layout intent

Behavior-preserving. No lid support, no user-visible change.

Intent is currently split three ways. The baseline holds modes, the `apply` source argument
holds the mirroring rule, `display-layout.swift` derives mirroring from that argument in five
conditionals, and `matches` in `display-auto.py` re-derives the same comparison in Python.

Make `mirrorOf` in the baseline the single description of intent. A screen with a mode keeps
its own desktop; a screen with `mirrorOf` is mirrored onto that key and needs no mode, origin,
rotation or refresh of its own, because a mirrored display adopts its master's. Python derives
the baseline for the current profile and rotation; Swift applies and verifies it.

- Drop the `source` argument from `display-layout apply` and the conditionals it causes.
  The baseline fully describes the result, so the argument carries no remaining information.
- `apply` becomes idempotent and self-verifying: compare, report `{"changed": false}` and
  touch nothing when the live layout already matches, otherwise apply, re-read, verify and
  report `{"changed": true}`. Failure to reach the requested layout still throws.
- Delete `matches` and the readback loop in `apply`. Its only consumer is `apply` itself,
  before the call and inside the loop, so the comparison moves wholly into Swift and is
  shared by the apply and verify paths.
- Relax `saved.mirrorOf == nil` so a saved screen may name a master, which must be another
  key in the same baseline. Apply the rotation equality check only to non-mirrored screens.
- Replace `ids.count == 2 && baseline.screens.count == 2` with the set equality that already
  follows it. Requiring the online set to equal the enrolled set is strictly as strong and
  does not hardcode a count.

The derived baseline becomes the file that is always applied, because `mirrorOf` is what now
encodes the profile. Today it is written only when rotation is enabled and `apply` otherwise
falls back to `baseline.json`; after this stage `baseline.json` is the saved enrollment and the
derived file is the applied intent. Two consequences: the preview snapshot and restore payloads
in `scaling_preview.py` and `preview_service.py` will always include it rather than sometimes
recording it absent, and the existing guard that read-only commands never write it must be
preserved, since `apply` alone writes it.

The installed Python and the native helper are staged from one release and both hashed in the
manifest, so they cannot disagree about the contract.

## Stage B: enroll and mirror the lid

`config.keys` gains `builtin`, holding the built-in panel's `vendor:model:serial`. Every
mutation stays gated on a saved identity.

- New installer step `install.py <host> --capture-lid`, run once with the lid open. It records
  `keys.builtin` only. It does not re-capture the baseline, so it never meets the exactly-two
  requirement that ordinary capture enforces and needs no mode validation.
- The installer requires `CGDisplayIsBuiltin` for the candidate before saving, so another
  display cannot be enrolled as the lid. `display-layout status` gains a `builtin` field.
- Absent `keys.builtin` means lid support is not enrolled and behavior is exactly today's.
  No migration, and an existing install keeps working untouched.
- The derived baseline appends `{key, mirrorOf}` for the built-in when it is online, composed
  after the rotation profile is selected. Rotation and lid stay two saved baselines, not four.
- `validate_config` accepts `{pg, benq}` or `{pg, benq, builtin}` and rejects a `builtin`
  value equal to either external. Baseline screens stay two.
- `doctor` reports lid enrollment, and whether the built-in is online and correctly mirrored.

## Decisions

The derived file keeps the name `rotation-active.json`. It is referenced by name in
`scaling_preview.py`, `scaling_proposal.py`, `preview_service.py` and `observability.py`,
including the preview snapshot and restore payloads. The name becomes imprecise once the file
also carries a lid row, which a comment records; renaming it would touch the reversible
preview machinery for no functional gain.

`--capture-lid` is separate from `--capture-rotation` rather than folded into it. Rotation
capture requires the enrolled pair alone and the lid closed; lid capture requires the lid open.
One command cannot ask for both.

## Tests

Stage A: existing coverage must pass unchanged, since there is no behavioral change. Add Swift
self-tests for a baseline whose screen names a master, for `mirrorOf` naming a key absent from
the baseline, and for the idempotent no-change report. Add Python tests for baseline derivation
per profile.

Stage B: topology classification for `E`, `E ∪ {L}` and an unenrolled third display; mirror
target per profile including the PG-away fallback; derivation with rotation and the lid
together; rejection of a non-built-in display at `--capture-lid`; `validate_config` acceptance
and rejection.

Physical, on this host: the installer's `test-layouts` sweep for Stage A, then lid open and
closed in each profile, and a rotation change with the lid open.

## Rollback

Each stage is one commit and independently revertable. Reverting Stage B leaves Stage A's
unification in place. Reverting Stage A restores the `source` argument and `matches`. No stored
format changes in Stage A; Stage B adds one optional key that older code ignores.

## Out of scope

Sleep and wake with the lid, which is already unqualified. Clamshell docking with a display
other than the enrolled pair, which stays idle. Giving the built-in its own desktop in an
extended arrangement: it mirrors or it is left alone.
