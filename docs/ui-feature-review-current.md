# Current UI and feature review

Reviewed source `17dc95b` on 2026-09-21. A newly compiled, separately identified
demo used the current menu source inventory and macOS 13 deployment target.
All state was synthetic; the demo prevents backend commands and notifications.
No installation, display setting, audio route or stored preference was changed.

## Result

Subsequent correction: the user's screenshot exposed disproportionate large fonts
and fixed-height controls that this review initially accepted. The implementation
now scales control geometry and navigation; see [the correction and its scope](log/proportional-controls.md).
The original screenshots below are historical evidence, not the corrected layout.


The earlier major layout findings are resolved in the inspected flows. Further
feature growth should first harden the size-review boundary, then make saved sizes
easier to reach. Rotation performance and release reliability still need physical
evidence. This is a scoped UI/source review, not approval of the entire controller.

## Captured flow

Screenshots were captured, saved and reopened during this run. The private illustrated
report is in the ignored `current-feature-review` audit directory. It contains only
synthetic UI but is not part of the public source. Main window: 600 × 480, Largest
text, dark appearance. Modal sizes are their own defaults, not 600 × 480.

| Step | State and result | Remaining concern |
| --- | --- | --- |
| 1 | Overview: both monitor owners and selected speaker are visible above the fold. | Rotation details require scrolling. This is acceptable for stable state; active waiting should earn higher priority. |
| 2 | Displays: one snapshot instruction and all four actions fit. | Saved presets are discoverable only through Preview size; no direct Saved sizes entry. An empty text region takes space before any snapshot exists. |
| 3 | Size chooser: both current/proposed sizes, physical estimate and Preview/Cancel are visible. Escape dismisses safely. | Default Current size still offers Preview despite showing unchanged effects. Consider disabling a verified no-op, but only after validating complete mode/rotation equality. This is a usability opportunity, not a demonstrated bad write. |
| 4 | Audio: current output, active-profile preference, preservation, repair and listening check fit. | Other profile selectors are below the fold; actual headset preservation and audible output were not exercised. |
| 5 | Controls: explicit monitor target, reading state, read, percentage and increment actions fit. | Brightness presets require scrolling. Keep common controls prominent; a new top-level feature panel is unnecessary. |
| 6 | Percentage with no reading: no proposal is claimed and Apply is disabled. | Slider has numeric AX value 50 but an explicit no-valid-request label/details. Actual VoiceOver speech must establish whether this is understandable. |
| 7 | Percentage 101: error is visible, accessible description changes and Apply remains disabled. Escape closes. | No invalid request was dispatched; demo isolation also blocks all backend requests. This does not exercise real DDC rounding. |
| 8 | Exhausted recovery: Check health and Repair audio appear before the long explanation. Command-1 selects Overview. | Remaining explanation scrolls. Notification delivery and actual retry/audio outcomes remain separate tests. |

Selected keyboard actions and accessible labels were observed. This run did not
test actual VoiceOver speech, high contrast, every modal, every stale/context-loss
transition, light appearance, setup GUI, real Shortcuts execution or hardware.
Earlier evidence for those surfaces is historical, not recaptured here.

## Source findings

### R1 — Size reports need a validated boundary before more entry points (medium)

Source fix delivered after this review; see [validation and limits](log/validated-size-review.md).
The finding below describes the reviewed revision.

`MenuApp.chooseSize` requires a JSON object with an `options` array, but then accepts
unvalidated option dictionaries. Missing/invalid rotation is presented as Landscape.
An empty option can receive the generic Size label and an enabled Preview button;
after submission, the missing fingerprint guard returns without an explanatory error.
These are source-confirmed paths, not failures observed from the normal controller
in this demo. Backend validation still guards mutations; no hardware safety bypass
was established.

Introduce one typed size-review parser shared by ordinary and named-preset entry
points. Validate read-only response marker, supported rotation, choice discriminator,
mode dimensions and fingerprint shape. Distinguish damaged preset storage from a
malformed response. Reject invalid choices before enabling a request, preserving a
clear reason. Do not default unknown values to a valid orientation or human label.

Acceptance fixtures: absent/boolean/unsupported rotation, empty/malformed option,
missing/invalid fingerprint, malformed available preset, missing current mode,
ordinary valid choices with a preserved preset error, and older compatible reports.
All invalid paths must explain why and dispatch zero writes. Retain final backend
identity, mode, orientation and ownership checks even after UI validation.

### R2 — Feature additions currently converge on a mixed command handler (medium)

`MenuApp.execute` handles UI-only prompts, synthetic response construction, notification
permission, process dispatch and feature-specific result routing. `chooseSize` also
assembles ad-hoc dictionaries and translates modal results into CLI arguments.
At 976 lines, the app is close to the strict review's decomposition threshold;
the important issue is mixed responsibilities, not the count itself.

Extract the size report/presentation boundary while fixing R1. Reuse it for menu and
Shortcuts review. Keep bounded command execution in `Commands.swift`, authorization
in the controller and reversible intent in the existing preview journal. Move the
affected synthetic response into a fixture builder using that same contract. Avoid
a generic plugin framework, extra event bus, or pending-state flags in unrelated paths.

### R3 — Delivery history was obscuring the current work (low, corrected here)

The priority table still asked to review and publish source already present in
`17dc95b`; many historical findings below it had since been fixed. Updated the
existing current-decision section and documentation index, retaining old evidence
as history. There should be one active priority list, not a new competing roadmap.

## Best features to add

The [fresh primary-source comparison](research/display-app-review-refresh.md)
checks BetterDisplay, Display Pilot 2, MonitorControl, Lunar and Apple guidance.

1. **Direct saved-size access.** Reuse the orientation-bound presets and readable
   before/after comparison. Borrow discoverability, not an unrelated scaling engine.
2. **Named preset review from Shortcuts.** Status and pause/resume already exist.
   Open the selected proposal, with explicit Preview and Keep/Revert. Do not silently
   make display changes permanent or equate request acceptance with completion.
3. **A clear rotation waiting explanation.** Surface the existing observed phase
   and age, then optimize the measured bottleneck. Do not invent progress percentages
   or promise a one-second hardware response without evidence.
4. **Model-specific comfort guidance.** Initially explain BenQ OSD checks and the
   fixed-refresh/HDR baseline. Automated inspection is research-only until the exact
   read protocol is established; another adaptive brightness loop is a poor default
   for a setup that previously pulsed.

These are product recommendations, not confirmed compatibility with vendor internals.
Free, open-source and buildable are distinct: MonitorControl is the clearest reference
for a fully open manual-control utility; neither it nor the vendor comparison proves
a drop-in replacement for this project's two-Mac ownership and recovery policy.

## Verification and implementation

Current menu compilation passed. `scripts/test` passed all 306 Python tests. Eight
saved screenshots were inspected and the interactions above exercised. No runtime
code changed in this review; the complete native helper suite was not rerun, and
remote CI was not requalified. Source tests do not establish audibility, optical
sharpness, latency or safe concurrent controllers.

The [current implementation plan](plans/ui-feature-priority-review-2026-09-21.md)
defines delivery order, failure cases and rollback. The next slice is R1, then direct
preset access and its Shortcuts entry. Release qualification remains explicit in
[qualification](qualification.md), including Mac B, headset transitions, additional
installer interruption boundaries and the declined sleep test.
