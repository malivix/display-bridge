# UI and feature delivery review

Reviewed source `c3e19ba` on 2026-09-21. This is the current priority order and
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

The next implementation item is order 1, not another broad feature expansion. This report
does not change the active installation, confirm CI on a new revision, or approve a release.
