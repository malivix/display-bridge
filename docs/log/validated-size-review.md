# Validate size reports before opening previews

The reviewed menu accepted partial option dictionaries, displayed missing rotation
as Landscape and could silently close when a selected option lacked a fingerprint.
The new `SizeReview` boundary decodes and validates the report before presentation;
command construction uses validated relative/preset targets and fingerprints.

Validation covers orientation, read-only marker, known unique choices, both monitor
sizes and 2× framebuffer dimensions, digest shape, named preset identity/orientation,
availability and optional physical estimates. Missing historical preset/duration
fields remain supported; an explicitly malformed preset collection is rejected.
A damaged preset-store report preserves its explanation and valid ordinary options,
while save/removal stay disabled. Existing controller authorization remains decisive.
No state schema, hardware policy or installation behavior changed.

Moved the synthetic size report and focused tests out of the app orchestration.
The model-only refactor shrank the app from 976 to 954 lines before the subsequent
proportional-control correction. The malformed-report explanation uses the
existing scalable dialog and supports Escape. Tests also exposed an unrelated
self-test assumption that demo mode came only from a CLI flag; the assertion now
uses the same bundle-or-flag predicate as the app.

Validation:

- `scripts/verify --native` passed: 306 Python tests, all native builds, DDC/menu
  checks and normal/CLI-demo menu self-tests on the initial implementation.
- After the historical-response compatibility and demo-test corrections, the final
  size model passed ordinary executable, CLI-demo and bundle-demo self-tests.
  The final scalable-dialog build was compiled and its bundle-demo self-tests passed.
- In the isolated UI at Largest text, valid options opened the chooser; a missing
  orientation produced a readable rejection and Escape returned to Displays.
  Damaged presets left ordinary Preview available and Save/Remove disabled.
  Private captures were retained. No hardware request, sound or notification ran.
- The first private bundle self-test failed because of the CLI-only assertion above;
  it was not a controller failure. Its corrected test paths all passed.

This does not qualify actual display switching, restoration, audibility, VoiceOver
speech or production activation. Rollback remains the coordinated prior menu/controller
snapshot described in the priority plan. Direct saved-size access is next.
