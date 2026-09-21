# UI and feature delivery review

Initial review covered source `c3e19ba` on 2026-09-21. See the delivery update below
before treating the original findings as open. This is the current priority order and
supersedes the delivery ordering in [the earlier follow-up](ui-feature-follow-up-2026-09-21.md).
This review changes documentation only; it does not install software or qualify hardware.

## Evidence

Current-run screenshots and accessibility inspection cover the isolated Percentage Review
demo at Largest text and a 600 × 480 main window. The demo predates the final percentage
dialog keyboard increment and availability-latch changes; current source was inspected
separately. It is not an exact-revision executable or evidence about the installed app.
All status was synthetic. Escape closed the percentage dialog without submitting a command.

Private screenshots are in the ignored `.local-only/ui-priority-review/` directory.

| Step | Capture | Finding |
| --- | --- | --- |
| 1. Controls | `01-controls.png` | Target, read, step and percentage actions are visible. The confirmed-value area starts below the viewport. Improve feedback placement. |
| 2. Percentage dialog | `02-percentage.png` | Target, requested value, Apply and Cancel fit at Largest. The arbitrary 50% proposal is clearly labeled, but increases accidental-change risk. |
| 3. Displays | `03-displays.png` | Refresh, Preview and Compare are visible. Two messages repeat the missing-snapshot explanation; there is no guided connection between comparison and choosing a size. |
| 4. Audio | `04-audio.png` | Selected output, Repair, Test and temporary preservation are visible. Resume and profile choices need scrolling. Contextual grouping would make the active override easier to understand. |

The extra scenario row is demo-only and consumes space; production does not have it.
Screenshots establish layout, not VoiceOver speech, light appearance, live focus retention,
notification delivery, sound, HDMI reliability, or monitor rotation speed. Those remain
separate checks. No claim that all features work correctly follows from this review.

## What already exists

Do not reimplement these as new features: enrolled-pair input detection, extended/mirror
profiles, audio preference and manual preservation, bounded recovery, sensor rotation,
failure notifications, private diagnostics and reviewed support summaries, transition
history, size previews with Keep/Revert, named presets, relative physical-size proposals,
comparison sample windows, monitor brightness/volume steps, explicit-Apply percentage
slider, and independent graphical setup. Source delivery and physical qualification differ.

Recent source work closed the previous Controls ordering, crowded global footer, setup
remedy text, process-observation, notification-preview privacy, duplicate size proposals,
and CLI percentage-control gaps. Remaining work should extend those implementations.

## Findings to fix first

### F1. Requested percentage is not initialized from known settings — high usability impact

`PercentChooser.swift` always constructs a 50% slider. `MonitorReadings` retains formatted
strings rather than typed observations. Changing Brightness to Volume keeps the same
numeric proposal, although these are unrelated settings. This is source-confirmed behavior,
not a report of an unintended physical write: Apply is explicit and backend guards remain.

Keep typed per-monitor/per-feature observations with their timestamps. Initialize from
the selected feature's last observation, explicitly labeled unrefreshed. Unknown values
must stay unknown; require deliberate selection before applying an arbitrary default.
Switching features must not carry a brightness target into volume. Add numeric entry for
precise keyboard control, using the same validated 0–100 target and single Apply action.

### F2. Current result is visually secondary to commands — medium usability impact

Step 1 shows actions ahead of confirmed values. Put a compact reading with age directly
below the monitor selector; keep detailed native values in disclosure. Show requested,
confirmed, waiting and failed states separately. Do not silently promote a previous reading
after a failure or target change. Keep active feedback visible without scrolling to the end.

### F3. Readability features are separate tools rather than one task — medium product gap

Step 3 has useful primitives, but Compare does not guide the user into a particular
qualified preview. Offer a single sequence: choose reference, compare identical samples,
choose larger/smaller for the other screen, inspect proposal, Keep/Revert, optionally name
the pair. Existing physical estimates remain useful; they are not visual calibration or
a promise of native sharpness at every scale.

### F4. Capability checks protect dispatch but do not fully explain the UI — medium gap

`monitorButtons` are enabled from ownership/readiness in `MenuApp.refresh`; newer commands
are additionally checked at dispatch. An older controller can therefore expose an action
that fails only after the user fills the dialog. Preserve the dispatch check, and add an
early capability-specific explanation. Distinguish unsupported, not checked, temporarily
unavailable, and unmanaged. A DDC read failure does not prove unsupported hardware.

### F5. Feature growth concentrates orchestration — maintainability risk

`MenuApp.swift` is 874 lines and `display-auto.py` is 991. Length alone does not prove a bug,
but additional per-feature state in either file would worsen reviewability. During F1/F2,
extract a cohesive monitor-controls presenter with typed readings and an action callback;
keep command execution and hardware authorization in their canonical layers. Move demo
fixtures out of production presentation when touching those boundaries. Avoid a generic
plugin framework or parallel controller state machine. Reformat touched logic for legibility.

### F6. Qualification trails feature delivery — release limitation

The [qualification document](../qualification.md) still excludes Mac B, concurrent
controllers, headset transitions and power-loss-safe installation. Do not label these
fixed by model tests. The percentage modal's sticky invalidation and timeout behavior need
isolated interaction tests; a heartbeat is not proof of a physical audio or display outcome.

## Implementation order and acceptance

| Order | Deliverable | Acceptance / failure behavior |
| --- | --- | --- |
| 1 | Typed readings, feature-specific percentage proposal, visible result | No cross-monitor or cross-feature leakage; unknown readings cannot masquerade as 50%; feature change discards unrelated intent; invalid numeric input cannot dispatch; one Apply writes at most once; stale or lost ownership blocks. Largest/minimum and keyboard tests. No persistence migration. |
| 2 | Capability-aware controls and contextual audio override | Unsupported actions explain why before opening a dialog; unknown support remains distinct; active preservation shows expiry and Resume next to it; headset choice remains preserved. Controller validation is unchanged. |
| 3 | Guided readable-size matching | Reuse existing qualified candidates and preview journal; preserve reference display; show current/proposed difference; rotation/input changes invalidate a proposal; Cancel/timeout restores safely. Save optional calibration only with identity and orientation binding. |
| 4 | Rotation timing and reliability qualification | Reuse existing phase status; measure observing, confirmation, layout and readback separately with monotonic durations. Report sample count and median/tail; optimize only an observed slow phase. No extra DDC polling for animation. Physical tests remain opt-in. |
| 5 | Local keyboard/Shortcuts actions | Wrap existing status, timed pause and named preset commands with typed results and explicit targets. No listener, automatic input switch or new mutation path. Explain that CLI timeout does not cancel work already accepted by the daemon. |

Each slice gets focused regression tests and `scripts/verify`; Swift changes additionally
get native verification and current-build UI captures. Exercise ready, stale, unknown input,
remote monitor, paused, recovery, malformed response and older-controller states. Test
keyboard navigation and VoiceOver separately, plus light/dark appearance. Do not equate
test quantity with qualification. Keep one implementation slice active at a time.

Rollback for presentation-only work is the prior coordinated menu/controller snapshot.
Any new calibration persistence needs schema validation, identity invalidation, damaged-file
preservation and a documented compatible rollback before activation. Preserve fixed 120 Hz,
HDR off and saved display sizes throughout review and ordinary testing.

## Features to borrow, adapt or defer

See the [fresh primary-source comparison](../research/display-feature-priorities-2026-09-21.md).
Borrow MonitorControl's direct target/value interaction, BetterDisplay's understandable
scale comparison, Display Pilot's model-specific capability presentation, and Lunar's
user-adjusted calibration concept. These are design recommendations, not compatible API
contracts or authorization to copy proprietary implementations.

Defer continuous drag writes until command latency and cancellation are measured; the
explicit-Apply slider already offers precision. Defer adaptive brightness, schedules and
application/Focus-triggered display changes because they could fight manual settings or
obscure this project's deterministic behavior. Virtual displays, PiP, HDR boosting and
undocumented MoonHalo control introduce larger scope or protocol uncertainty. Automatic
input switching, software disconnect and network control conflict with current invariants.

## Delivery update after `d4fa522`

Orders 1 and 2 have source implementations and isolated validation: typed, dated readings;
feature-specific numeric proposals; visible unconfirmed results; capability explanations;
and contextual audio preservation with expiry and Resume. These do not qualify live DDC
or headset behavior. The percentage dialog now rejects invalid text and latches lost
readiness. Preset names are also validated during editing, with submission validation retained.

Order 3 is partly delivered: comparison samples lead into the existing preview chooser;
reference filters preserve the selected monitor; Displays exposes Save current size; and
open choices latch readiness loss or a newer contradictory rotation readback. The chooser
has its own cohesive module. Saved visual calibration metadata remains unimplemented.
Named size presets already bind the selected mode pair to host, enrolled display identities,
DDC identities and orientation; a second store is not needed to remember a preferred pair.
Resolved presets now also expose the existing model-based physical-size estimate for preview
comparison. Extra visual calibration metadata should follow a demonstrated workflow need;
neither presets nor that estimate measure optical sharpness or viewing distance.

Primary product pages were reopened for this update: [BetterDisplay](https://github.com/waydabber/BetterDisplay),
[MonitorControl](https://github.com/MonitorControl/MonitorControl),
[Lunar](https://lunar.fyi/) and [Display Pilot 2](https://www.benq.com/en-us/monitor/software/display-pilot-2.html).
The useful design references remain readable scale selection, direct targeted controls,
user-adjusted calibration, and model-specific capabilities. Feature advertising is not
evidence of compatibility with this pair or a public implementation API.

### Remaining work after the current-build audit

The [nine-step UI audit](../ui-audit-2026-09-21.md) reviews `3d94e42` plus the existing
portrait/preset demo correction. It supersedes the earlier remaining-work table, not
its historical evidence. The [new comparison](../research/display-app-comparison-2026-09-21.md)
checks current upstream features and source availability. Most proposed baseline
features already exist; the next milestone improves daily decisions and verifies them.

| Order | Deliverable / boundary | Completion evidence |
| --- | --- | --- |
| 1 — source implemented; broader qualification pending | Compact two-monitor size decision; `SizeChooser.swift`, presentation tests | Both current/proposed monitor effects and Preview visible at Largest/minimum; technical detail expandable; preset estimate preserved; ordinary/reference/preset/empty/unknown choices; keyboard/Escape and stale-context rejection. Reuse existing preview journal, no new persistence. |
| 2 — source implemented; broader qualification pending | At-a-glance Overview and consistent recovery actions; status presenter and menu orchestration | Both ownership summaries and selected speaker visible in healthy state; active recovery remains first; Health/Repair wording matches action; stale/unknown/away/paused/manual/preview states, freshness and click-time revalidation. No hardware polling added. |
| 3 | Focused Controls/Audio/Displays cleanup | Single empty-state instruction; precise adjustment near readings; active audio profile near selected output; Largest/minimum and long-name checks; invalid/unknown percentage speech qualified; no cross-monitor or feature value leakage. |
| 4 | Accessibility and release qualification of the completed flows | Exact-build keyboard traversal, focus retention during refresh, modal cancellation, VoiceOver speech, light/dark and supported text sizes; record individual failures. Extract demo fixtures only to resolve the observed consistency risk; update all native builders. |
| 5 | Local Shortcuts, starting read-only | Status returns a typed outcome without GUI/hardware mutation. Then timed pause/resume with bounded arguments. Named preset preview is a separate slice using fresh fingerprint and existing Keep/Revert. Accepted/pending/completed/failed are distinct; caller timeout is not cancellation. No listener or arbitrary shell field. |
| Research gate | BenQ comfort-settings inspector | Document firmware/transport/protocol provenance first. No register sweep or undocumented writes. Distinguish unsupported, unverified, unreadable and confirmed; multiplexed values cannot masquerade as live reads. Ship OSD guidance if safe narrow inspection is unproven. |

Pair source work with two reliability gates: isolated interruption coverage for the
installer commit phase, and opt-in exact-revision physical rotation timing. Neither
blocks unrelated presentation work; neither is satisfied by a passing demo. Mac B,
concurrent-controller and headset qualification remain separate. Sleep testing remains
deferred under the user's stated workflow. No installation is part of this audit.

For orders 1–3, rollback is the prior compatible menu build; no configuration migration
or preset/journal deletion. Runtime changes require `scripts/verify`; Swift changes also
require native verification and current-build UI evidence. New Shortcuts integration
must preserve enrollment, ownership, busy serialization and capability checks through
the existing command boundary. Do not create a new state machine in the integration.

Defer a second visual-calibration store: existing named presets already remember an
identity- and orientation-bound pair. Defer live brightness sync, virtual displays,
HDR boosting, PiP and layout editing until there is a concrete unmet task. Preserve
fixed 120 Hz, HDR off and the accepted saved sizes. Unknown monitors remain unmanaged.

One slice is active at a time. The first implementation is the compact size decision
(U1), followed by its isolated UI verification; this document is the plan, not a claim
that those presentation changes are already implemented.


### Compact size decision delivered

The first slice now presents both monitor effects before physical estimates, with
technical detail/preset availability behind a keyboard-accessible checkbox. Preview
and Cancel share a row; preset management is separate. Current-build synthetic UI
inspection confirmed both monitor summaries at Largest/minimum, reference-preserving
comparison, detail disclosure by Tab/Space and Escape cancellation. Native verification
passed. This does not qualify VoiceOver, physical preview or deployment. See the
[delivery log](../log/compact-size-decision.md). The next source slice is Overview and
recovery clarity; preserve the outstanding qualification matrix.


### Overview and recovery clarity delivered

Healthy Overview now includes both ownership summaries and the selected speaker before
rotation detail. Empty recovery and duplicate ownership groups are hidden without
rebuilding views. When recovery is pending or status is stale/paused, recovery keeps
its earlier position and ownership stays labeled last-known. Exhausted audio recovery
has an adjacent read-only Health action; canonical repair eligibility is unchanged.
Largest/minimum synthetic ready, exhausted and stale views were inspected, and native
verification passed. See [validation](../log/overview-ownership-summary.md). The next
source slice is Controls/Audio/Displays cleanup; full accessibility and physical
qualification remain open.


### Controls and Displays cleanup delivered

Order 3 is partly delivered: precise adjustment is visible near readings, the redundant
healthy availability sentence is hidden, and Displays has one empty-state instruction.
Current-build Largest/minimum inspection confirmed the placement, stale blocking
message and disabled controls, and synthetic display refresh. Native checks passed.
See [validation](../log/controls-display-cleanup.md). Contextual Audio preferences and
percentage screen-reader feedback remain the next parts of this order.


### Contextual audio preference delivered

Audio now summarizes the saved preference for the reported arrangement near the selected
output. Unknown/malformed preferences are not inferred; stale arrangement and pause are
explicit. Routine repair guidance moved to accessible help, while blocking reasons and
listening responses remain inline. Largest/minimum ready and manual-preservation demos
were inspected and native verification passed. See [validation](../log/audio-profile-context.md).
Order 3's remaining work is percentage-entry accessibility feedback and its qualification.
