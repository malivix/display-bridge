# UI and feature follow-up

Historical review: several slices below have since shipped in source. Use the
[current priority review](ui-feature-priority-review-2026-09-21.md) for remaining work.

Reviewed source `1f30912` on 2026-09-21. This is the current delivery order, superseding
the remaining priorities in the [earlier review](ui-feature-review-2026-09-21.md).
This turn is research, UI inspection and planning; it does not activate new software.

## Evidence and limits

Current-run captures inspected the existing isolated menu demo in dark appearance at
Largest text, plus the real setup app built from `1f30912`. The demo bundle has no source
fingerprint; its layout was cross-checked against current `MenuApp.swift`, but it is not
claimed to be an exact-HEAD executable. All menu data was synthetic. Setup was opened,
its text enlarged, and closed without review or installation. Its strict code-signature
verification passed after this inspection. This does not qualify installer execution.

Private captures: `01-overview.png`, `02-controls-minimum.png`, `03-audio-minimum.png`,
`04-setup.png`, under the ignored local UI review directory. No screenshots or machine
configuration belong in a public commit. VoiceOver speech, light appearance, every modal,
real audio, rotation, HDMI behavior and concurrent Mac controllers were not tested here.

| Step | Observed state | Assessment |
| --- | --- | --- |
| 1. Overview | Stale controller, Largest, ordinary demo window | Good: dated state and Check health appear early. Monitor and audio detail requires scrolling. |
| 2. Controls | Stale controller, Largest, minimum 600 × 480 window | Needs improvement: support prose, a disabled support-check button and presets fill the viewport; actual adjustment controls and the current unavailable reason are below it. |
| 3. Audio | Same minimum window | Partly good: last-known output, Repair and unavailable reason are visible. Listening check is clipped at the bottom; manual override requires scrolling. |
| 4. Setup | No role selected, Largest, default window | Good guard: Install disabled and no role assumed. Needs clearer steps: preparation is one broad checkbox and developer-oriented source information competes with task instructions. |

The demo-only scenario row consumes additional vertical space. Do not attribute all of
the compact-window crowding to the production app; its persistent three-row footer and
Controls content ordering are independently present in source.

## Existing feature inventory

Implemented source already includes guarded mirroring/extended layouts, profile audio
preferences, manual output preservation, bounded recovery, sensor rotation, freshness
and transition timing, failure notifications, local diagnostics and reviewed support
copy, brightness/volume steps and presets, reversible size previews, named size presets,
bidirectional model-estimated physical-size matching, explicit listening checks,
enrollment review, installation reports and an independent setup app.

These are not all newly physically qualified. Consult [qualification](../qualification.md).
Do not describe them as missing or implement parallel versions of their state machines.
The [competitor refresh](../research/display-competitor-refresh-2026-09-21.md) provides
primary-source comparisons; recommendations below are product/engineering judgments.

## High-confidence findings

1. **Controls prioritizes implementation detail over the task.** `MenuApp.showPanel`
   constructs support prose and preset capability actions before availability, reads
   and adjustments. Move selected monitor, availability and confirmed settings first;
   put compatibility details behind disclosure. This is a usability defect, not evidence
   that the controller writes to the wrong monitor.
2. **Persistent actions compete with readable content.** The footer includes global
   size-preview, More controls, Health and Diagnostics on every tab. Put diagnostics
   under Details and ordinary size selection under Displays; keep active Keep/Revert
   and the pause state prominent. Preserve shortcuts and focus. Avoid removing safeguards
   just to reduce text, and measure the real app without the demo row.
3. **Setup failures lack actionable explanations.** `SetupModel.setupReview` intentionally
   discards arbitrary details and renders only check names/status. A failed Build tools
   or Service namespace check therefore tells the user what failed without a tailored
   remedy. Add allowlisted reason codes and static safe actions; never display raw
   commands/errors as trusted instructions. Keep role, software review, hardware checks,
   activation and outcome distinct. A checkbox is not hardware verification.
4. **New features will compound orchestration complexity.** `MenuApp.swift` is 835 lines,
   mixing view construction, live updates, dispatch, demo fixtures and response decoding;
   `display-auto.py` is 979 lines. Size alone is not a bug, but adding slider state or
   calibration branches here would make ownership harder to follow. Extract the monitor
   controls view/presenter with a typed snapshot and action callback during that feature;
   move synthetic response generation to one fixture provider. Preserve a single controller
   mutation boundary. Do not create a generic plugin framework or duplicate state engine.
5. **Qualification is behind source delivery.** Setup activation/interruption, notification
   lifecycle, headset transitions and full keyboard/VoiceOver behavior still need explicit
   evidence. Compilation and software readbacks cannot close these gaps. Keep source revision,
   installed agreement, latest observations and user-confirmed outcomes separate.

## Implementation sequence and acceptance

### 1. Make daily controls accessible before adding controls

Change only native presentation and its models: task-first Controls ordering, less crowded
footer, contextual unavailable reason, and consistent Display Bridge naming. Keep recovery
and active preview actions directly reachable. Use the existing command capability checks.

Acceptance: Largest text at supported minimum size exposes target, current availability and
the relevant next action; ready, stale, away, unknown-input, pending and exhausted recovery
remain distinguishable. Keyboard-only navigation reaches every action with visible focus.
Refresh must preserve focus and scroll position. Inspect light/dark and VoiceOver separately.
No new hardware commands. Rollback: coordinated prior controller/menu snapshot.

### 2. Finish setup reliability and explanations

Reuse the independent installer front end. Add a concise numbered progression, safe reason
codes, explicit current attempt age and a clear last-report versus current-attempt distinction.
Put revision and detailed software checks behind a details control. Preserve ordinary upgrades'
saved identities, modes and rotation profiles. Do not automatically re-enroll unexpected inputs.

Acceptance: isolated subprocess tests for failure before first report, duplicate launch,
stalled child, stale/malformed report, failed activation and failed recovery; no false success.
Verify committed app resource seal before and after software review and bundled tests with
bytecode writes disabled. Test actual process lifetime separately from pure selection-model
tests. Forced termination/power loss remain explicit limits until demonstrated recovery exists.
Real activation requires eligible enrolled hardware; Mac B remains separately qualified later.

### 3. Visual calibration for readable matching sizes

Extend existing size preview rather than create a new HiDPI driver. Present identical sample
tabs/text and a reference ruler on the enrolled monitors; let the user adjust the perceived
match, then choose the nearest qualified pair of modes. Show current versus proposed size and
estimated difference, plus one clear larger/smaller control. Preserve a named known-good pair.

Acceptance: calibration metadata is local and tied to enrolled identity and orientation;
changing displays invalidates it. Missing dimensions never produce false precision. Keep/Revert
uses the existing 20/40-second journal and ownership gates; timeout, rotation or input change
cannot commit an obsolete proposal. Pixel scaling may resample; never promise native optical
sharpness at every size. The user must judge readability at their actual viewing distance.

### 4. Explain in-flight rotation, then optimize the measured slow phase

Sensor age and observed-to-outcome timing already exist. Add a bounded phase enum, start age
and waiting reason to the existing status snapshot: observing, confirming, applying layout,
checking result, recovering. Do not show invented completion percentages. Preserve last-known
orientation when new evidence is unavailable, labeling it as dated.

Acceptance: use monotonic durations; stale phase/status expires; no extra DDC reads just to
animate progress. Collect opt-in samples in both rotation directions, report sample count and
phase median/tail, and optimize only the demonstrated bottleneck. Unknown inputs still defer.
Do not lower ownership checks or promise a one-second physical response from software tests.

### 5. Brightness/volume slider through the serialized controller

Take MonitorControl's direct target-and-control approach. Start with one selected monitor,
keyboard increments, a requested value and separately confirmed value/read age. Measure command
latency first. Coalesce unsent drag requests; attach a target/context generation so a response
cannot overwrite newer intent or execute after the display becomes remote. Keep step buttons.

Acceptance: bounded queue, latest-intent behavior, stale/error feedback, cancellation on target
or ownership change, and no retry to a remote monitor. Slider persistence must not fight
another app or OSD changes. Do not equate brightness percentages with equal luminance or silently
substitute software dimming for failed hardware DDC. Physical smoothness is an opt-in test.

### 6. Optional local Shortcuts and capability presentation

Expose existing status, timed pause and a named preset with explicit target and typed result;
no network listener. Present which capabilities are available, unsupported or temporarily
unavailable for each enrolled monitor. This is especially useful when moving the Mac.

Acceptance: unfamiliar displays remain unmanaged; no model-name-only authorization. Shortcuts
must pass the same identity, freshness, preview and recovery checks as the menu. Cancelled or
timed-out commands do not mean queued controller work was cancelled. Avoid new permissions
unless an actual feature requires them.

## Defer

Virtual displays, PiP, window management, arbitrary custom mode injection, HDR boosting,
ambient/scheduled brightness, Focus-driven modes and MoonHalo control have weaker value for
this user's current needs or lack qualified protocols. Automatic physical-input switching,
software disconnection and network control conflict with current invariants. Keep fixed 120 Hz,
HDR off and the user's saved sizes. A competing application's feature is not authorization to
change that policy or proof of a secure, compatible replacement.

## Delivery discipline

One slice at a time. Focused regressions and `scripts/verify`; native verification for Swift
changes; screenshot and keyboard inspection for UI; physical checks only as separate opt-in
qualification. Record exact source and installed revisions. Run staged privacy checks before
commit and history checks before publication. Do not publish private screenshots or logs.
The first implementation item is slice 1, not another broad infrastructure rewrite.
