# Product and interface review: implementation plan

Reviewed 2026-09-20 against source `b50cd91` (2.10.2, unreleased). Live UI observed
2.10.1; the checkout was not installed. This document is a plan, not a claim that the
features below have been implemented or physically qualified.

## Implementation progress

The first source changes add command progress, per-group last-known labels, status age,
and default notification-click routing. Controller request IDs and bounded durable outcomes now distinguish policy acknowledgement
from reconciliation. Incident-specific deduplication, a resizable window, and three status-text sizes are now
implemented. A hardware-free demo was inspected at the largest size and a smaller window.
The grouped Overview/Details dashboard and direct Pause control are now implemented.
Largest-text scrolling and accessibility-tree values were checked in a hardware-free demo.
A read-only Displays tab now presents measured/saved mode snapshots.
An Audio tab now exposes profile preferences and manual/repair controls with availability reasons.
The separate allowlisted support-summary preview is implemented and tested in source.
Direct monitor controls now show readbacks inline and explain availability; continuous
slider/coalescing and physical pacing qualification remain deferred.
Larger controls, further advanced-menu simplification, and complete
accessibility qualification remain. Live deployment
and UI qualification remain separate.

## Decision

Make the existing handoff clear, readable, and recoverable first. The next work item is
**command feedback and trustworthy status**, followed by a readable per-monitor dashboard.
Do not build a general BetterDisplay clone. Competitor evidence and licensing distinctions
are in the [source-cited comparison](../research/display-app-comparison-2026-09-20.md).

## What exists already

Ownership-aware extended/mirrored layouts, bounded audio recovery, external-headset
preservation, per-profile speaker preferences, calibrated BenQ rotation, timed pause,
manual audio preservation, hardware brightness/volume steps, failure alerts, local health
checks, private diagnostics, transition timing/DDC history, qualified HiDPI choices, and
journaled size previews already exist. Improve these rather than reimplementing them.

## Live inspection and limitations

1. **Status window — usable, weak hierarchy.** Captured a ready state with both monitors
   local and no recovery pending. One flat text area holds nearly all information. There
   is no current logical resolution, HiDPI, refresh, HDR preference, or status age on this
   screen. Fixed-size window, 14-point body, and persistent disabled Keep/Revert controls
   waste useful space. A selectable text area is useful for copying but does not provide
   separate semantic groups for monitors, audio, and recovery.
2. **Controls — discoverable but crowded.** Inspected the accessibility tree: status rows,
   pause, rotation, audio overrides, four speaker-preference submenus, size controls,
   monitor controls, reports, notification setup, and quit share a single menu. Raw names
   such as `extended` and `ready` appear. The tool could not capture this menu as an image;
   menu findings are tree/source observations, not a visual-layout verdict.
3. **Size options — blocked in installed version.** Invoked only the read-only options
   action. The status window stayed busy with disabled actions and no visible progress;
   a later process inventory showed no command child. No size choice or preview was
   submitted. Restarting only the menu restored enabled controls. The exact cause is not
   proven by this observation; source 2.10.2 already bounds command time/output, while the
   inspected 2.10.1 does not have that fix. Qualify this exact flow after deployment.

Private screenshots are retained under the ignored `.local-only/` audit folder. Do not
publish raw captures. No input, resolution, brightness, sound, or rotation was changed.
The Python suite passed 172 tests during this review. This does not validate physical
sound, optical quality, notifications, VoiceOver, or concurrent Macs. Error, away, preview,
and recovery screens were source-reviewed, not induced on the user's live desktop.

## Findings to fix

| Priority | Evidence | Change and acceptance |
| --- | --- | --- |
| High | Live step 3; `runMenuCommand` and `execute` | Qualify 2.10.2 command timeout fix; show operation name, elapsed time, and outcome. A slow read never leaves controls permanently disabled. Timeout says whether daemon work may remain queued. |
| High | `control_command` returns “requested”; UI discards normal success output | Add acknowledged command results. Distinguish preference saved, controller accepted, applying, verified, deferred, and failed. Never equate CLI exit zero with completed hardware work. |
| High | `refresh` keeps profile/speaker rows when heartbeat is stale; dashboard adds only a general disclaimer | Mark each stale group as last known with age. Gate mutation actions consistently; backend still rechecks ownership. Test future timestamps, missing heartbeat, paused, away, unknown input, and reconnect. |
| High | Notification callback handles only `repair`/`inspect` | Default notification-body click must open status. Route action by failure type. Deduplicate by incident, not a single global sent flag, so a distinct failure is not silently hidden until Ready. |
| High | Live step 1; fixed frames and fixed fonts in `showPanel` | Resizable window, app-owned text-size preference, semantic groups, keyboard navigation, VoiceOver labels, focus restoration. Test large text and smallest supported window without clipping. Do not claim macOS accessibility text settings enlarge every app. |
| Medium | Monitor adjustments each trigger a modal alert; two-second settling under DDC lock | Inline result plus pending/confirmed value; coalesce user edits. Preserve readback and ownership checks, and measure lock wait before shortening settling. A slider must not enqueue a write for every mouse movement. |
| Medium | `chooseSize` exposes mode dimensions through alert buttons; pairing uses relative change from saved match | Dedicated size sheet with readable-size comparison, current mark, orientation, and verified properties. Reuse existing rollback. Do not label 2× framebuffer rendering native pixel sharpness. |
| Medium | Recovery display shows attempt counts without distinguishing all journal states | Present cause, last attempted phase, next retry or exhausted state, and one applicable action. Explain why repair is disabled. Software verification never says sound is audible. |
| Medium | App branding remains Display Auto; version header shows controller version | Display Bridge name and separate app/controller versions. Plan migration of bundle, defaults, notifications, and LaunchAgent; preserve old installation paths until a verified migration exists. |
| Medium | Diagnostics preserve raw IDs, names, logs, malformed bytes | Keep full report private. Add separate allowlisted support summary with preview; exclude raw logs, raw bytes, paths, and stable identifiers by construction. No upload button initially. |

These are scoped findings, not a claim that every feature has been tested. Apple recommends
supporting enlarged text and accessible controls; use an app-specific sizing option for this
AppKit interface. Organize frequent actions separately from configuration and diagnostic
commands. [Apple accessibility guidance](https://developer.apple.com/design/human-interface-guidelines/accessibility),
[typography guidance](https://developer.apple.com/design/human-interface-guidelines/typography),
[menu guidance](https://developer.apple.com/design/human-interface-guidelines/menus).

## Proposed interface

Keep the menu compact: current status, two monitor summaries, selected speaker, Pause/Resume,
Open Display Bridge, and Quit menu. Put configuration and troubleshooting in the window.
Use existing native AppKit controls and system appearance, not a separate web UI.

The main window should provide:

- **Overview:** monitor ownership, saved versus observed mode, orientation, freshness;
  selected speaker versus preference; only the current operation or fault.
- **Displays:** qualified size choices, named presets, refresh/HDR policy status, and
  hardware controls with availability explanations.
- **Audio:** four existing profile preferences, manual-override expiry, actual output,
  targeted repair, and an explicitly requested listening test.
- **Troubleshooting:** health results, recent transitions, recovery details, private
  diagnostics, and reviewed support summary.

Show Keep/Revert and an obvious countdown only during an active preview. Keep countdown
updates separate from replacing the entire status text every two seconds. A hidden or closed
window must never own rollback timing. Show the last verified state while an action runs.

## Delivery sequence

### 1. Trustworthy status and command feedback — next active work item

Scope: `native/display-menu.swift`, control command boundary in `display-auto.py`, validated
command result state, manifest inventory if a new module is needed, isolated tests.

Start with reproducible menu tests for default notification click and busy-state feedback.
Add operation identifiers and bounded durable results to controller-applied requests;
preserve newest desired settings and explicitly mark superseded requests. Define expiry,
restart recovery, duplicate IDs, and outcome retention. The menu observes results rather
than retrying automatically. Read-only commands stay direct; they need deadlines and progress,
not a persistent queue. Monitor writes continue using their existing serialized boundary.

Acceptance: slow/failed commands recover UI; request success is distinct from completion;
stale data never appears current; app restart reveals pending/completed result; duplicate
submissions do not repeat recovery; unknown/away monitor cannot be adjusted. Regression
fixtures cover notification body/action, two separate incidents, and denied notifications.

Rollback: additive versioned state, old reader tolerance documented; never remove recovery
journals. Revert UI separately if needed. Qualify the installed 2.10.2 read-only options flow
before any live mutation tests. No release claim until installed source/version agree.

### 2. Readable dashboard and capability-aware controls

Refactor the large menu source into presentation model, command client, notification policy,
and native views only where needed for the new interface. Keep hardware policy in Python.
Represent capabilities as supported, unsupported, unknown, or temporarily unavailable with
reason and last observation. Initially cover only existing safe read operations; do not
probe unknown writable VCP codes. Preserve manual overrides.

Acceptance: no clipping at enlarged text sizes; keyboard-only navigation; VoiceOver order
and names verified manually; light/dark contrast checked; healthy/stale/paused/inactive/
recovery/preview fixtures captured. Current value and pending value are visibly distinct.
Coalesced brightness edits recheck identity/input immediately before write and verify after.

### 3. Named readable-size presets

Save larger-text and more-space choices separately for portrait and landscape. Start from
currently enumerated HiDPI modes and existing timed preview transactions. Show expected
relative UI size, not just pixel counts. A physical matching score can compare logical
points per physical inch using known panel dimensions, rotation, and current mode; EDID
size can be wrong, so support a user-calibrated match and label estimates.

Acceptance: mode IDs are re-resolved on this host; stale inventories rejected; preview
rollback survives menu termination; rotation/input changes defer safely; mismatched or
missing modes do not silently substitute; saving one orientation does not overwrite another.
Do not promise arbitrary Chrome UI zoom or native sharpness at every size.

### 4. Guided setup and qualification

Build a read-only preflight first: prerequisites, enrolled pair, independent host capture,
DDC availability, and conflicts with other control apps. Then guide enrollment/calibration
using existing installer paths, explicit preview, and rollback. Explain unsupported extra
screens without offering broad control over them. Add an uninstall flow that stops only
owned services and offers to preserve configuration/backups.

Acceptance: replacement/unrelated monitor stays untouched; interrupted setup resumes or
restores; captures never transfer device IDs between hosts. Mac B installation/concurrent
controller qualification remains a separate physical session. User does not use sleep;
keep wake tests deferred and documented rather than forcing them into routine work.

### 5. Convenience after reliability

Optional shortcuts/media keys with explicit target policy and repeat coalescing; manual
Day/Evening brightness presets; allowlisted support export; a readable history timeline
with count, median, p95, and phase boundaries. Record command queue wait and DDC-lock wait
separately from operation time. Rotation detection latency requires physical timestamps;
existing application timings exclude the interval before the first valid sensor/input read.

## Defer deliberately

Virtual displays/custom mode injection need a separate feasibility prototype. No automatic
input switching, software disconnect, cloud syncing, network control, broad window manager,
or automatic HDR/VRR/color-mode changes in this roadmap. Adaptive brightness is optional
later because stability matters more here. Unknown BenQ MoonHalo/coding-mode writes need
validated model-specific protocol evidence before implementation.

## Release gate

For each slice: isolated regression tests, `scripts/verify`, native build/self-tests when
app/helpers change, staged privacy review, and a small opt-in physical test tied to exact
revision. Use fault fixtures for stale state, expired requests, process death, and mode
changes. Never perform destructive hardware fault tests as ordinary CI.

Physical checklist: both local; each monitor alone; both away then each return order;
audio departure/return and headset preservation; both BenQ orientations; preview keep,
automatic revert, and interrupted recovery. Unit success is separate from audibility and
optical results. Keep Mac B, wake, and cable/firmware gaps visible in qualification.
