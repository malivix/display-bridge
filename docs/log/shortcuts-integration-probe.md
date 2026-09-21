# Establish the native Shortcuts build boundary

Added an opt-in synthetic App Intents probe and a
[production implementation plan](../plans/local-shortcuts.md). The probe is outside
the runtime source manifest and ordinary tests. It cannot read controller files
or issue display/audio commands. The builder leaves artifacts under `.local-only`
and does not open or install the app.

Validation on the available Apple-silicon Mac with Xcode 26.4.1:

- `./scripts/probe-shortcuts`: compiled with a macOS 13 target, generated the
  expected action and typed entity plus App Shortcut metadata, verified ad-hoc
  signing, and passed the direct intent-result and unknown-entity self-test.
- `./scripts/verify`: exited 0; 297 Python tests and index publication checks passed.
- Production runtime/native sources and installed services were unchanged.

The exploratory compiler invocation first rejected the object-shaped protocol
manifest; extracting its protocol list resolved that. The driver output-path flag
alone emitted no constants; passing the output path to the frontend produced the
required file. These findings are encoded in the probe rather than left as manual
build instructions. All exploratory artifacts remain ignored.

An earlier private synthetic app was opened for discovery testing. Shortcuts did
not open an editor through the available New Shortcut actions, so neither action
discovery nor execution within Shortcuts was verified. Direct invocation and
metadata inspection are narrower evidence. No existing shortcut was edited or run.
Do not describe this commit as delivering the production status action.
