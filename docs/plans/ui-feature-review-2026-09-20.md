# Current UI and feature review

Reviewed source `80cfb8d`, 2026-09-20. This supersedes the older roadmap's sequencing,
not its safety constraints. Scope: native window, command discovery, size workflow,
existing feature coverage, and competitor-informed delivery priorities. This is not a
complete code/security audit or physical hardware qualification.

## Evidence and verdict

The product already has substantial controller functionality. The next useful work is
making it readable, understandable, and verifiable. Adding many monitor features now
would multiply interaction and hardware failure paths before the current UI is qualified.

Fresh screenshots and accessibility trees were captured from the isolated synthetic demo.
It cannot change hardware. Captures remain private in the ignored audit directory, named
`01-overview.png`, `02-audio-largest.png`, `03-controls-largest.png`, `04-displays.png`.
They are intentionally absent from public Git. The demo binary exposes the current five
source tabs; this inspection does not establish installed-controller parity.

| Step | Observed result | Finding |
| --- | --- | --- |
| 1. Overview, Standard text | Grouped ownership, audio and recovery information; selectable text exposed in accessibility tree | Useful hierarchy. Measured display sizes are absent here. Footer reserves multiple rows for actions unrelated to the selected tab. |
| 2. Audio, Largest text | Explanations enlarge; four speaker selectors and their labels remain small | High-priority accessibility mismatch. The repair explanation falls below the visible area and requires scrolling. |
| 3. Controls, Largest text | Large explanatory text above small brightness/volume buttons; confirmed-value instructions below | Controls are readable only at the original system size. No values until a requested read; five vertically separated actions consume space. Group brightness and volume with their own confirmed value and action feedback. |
| 4. Displays, Largest text | Clear read-only instruction and Refresh action | Initially empty of mode facts. Preview is in the shared footer, while brightness is in a separate Controls tab. Display tasks are fragmented. |

Source evidence: `showPanel`, `applyTextSize`, `refresh`, `chooseSize` in
`native/display-menu.swift`. Text scaling updates selected text views/labels only.
Fixed frames remain in the footer; audio rows use fixed 190/250-point widths. Enlarging
fonts alone will cause layout pressure: use adaptive layout before expanding control text.
`refresh` still builds the long advanced menu with duplicated audio/monitor/report actions.
`chooseSize` remains a modal alert with resolution lists, not a comparison sheet.

No screenshot proves VoiceOver usability, keyboard traversal, light-mode contrast, physical
sound, optical sharpness, or hardware timing. Fault/away/preview UI states were source-read,
not visually exercised in this pass. The demo read/preview commands do not establish live
command completion. Latest GitHub verification for `80cfb8d` passed at review time.

## Existing versus missing

Implemented in source: command IDs/outcomes, stale status labels, bounded command execution,
failure notification deduplication, overview, mode snapshots, audio preferences, monitor
steps/readback, allowlisted support summary, single menu ownership, orientation-aware mode
health, reversible size preview, diagnostics, history, calibrated rotation.

Partial: accessible text sizing, per-monitor capability explanation, direct control feedback,
installation migration, physical qualification, brand consistency. Some window/menu labels
still say Display Auto. Diagnostic/report actions remain spread across the menu/footer.

Missing: named size presets, a dedicated size comparison sheet, guided setup, an integrated
recovery/history page, user-configured shortcuts, and manual comfort presets. Do not count
existing diagnostics or notifications as new feature proposals.

## Ordered implementation plan

### 1. Whole-interface readability and navigation

Observable result: the user can read and operate every frequent control using Largest size.
Use native adaptive stacks/grids and scrolling; scale labels, popups, action buttons and
status text coherently. Preserve keyboard focus and current tab during refresh. Consolidate
monitor details and adjustments under Displays; retain an Audio page and add Troubleshooting.
Keep the menu to status, monitor ownership, selected output, pause, open window, and quit;
retain infrequent actions under an Advanced submenu until equivalent window actions exist.

Acceptance: inspect Standard/Large/Largest at minimum and enlarged window sizes; light/dark;
keyboard-only traversal and VoiceOver names/values; no clipped controls or hidden-only fault
action. Capture healthy, stale, paused, away, preview and exhausted-recovery synthetic states.
Do not add hardware reads to the two-second UI refresh loop. Add explicit demo scenarios
so these states can be inspected without altering real monitor inputs.

Implementation boundaries: separate pure presentation/state descriptions from AppKit view
construction when touched; keep command execution and hardware policy unchanged. Avoid an
unrelated whole-file rewrite. Rollback is the prior menu binary; no config migration required.

### 2. Named readable-size presets and comparison sheet

Observable result: save a readable pair as “Reading” or “More space,” then safely preview it
again in the matching orientation. Present current/proposed logical dimensions, framebuffer,
refresh/HDR policy and estimated relative UI size. Clearly distinguish 2x rendering from
native panel pixel sharpness. Exact physical matching requires panel dimensions/calibration;
mode resolution alone does not establish equal perceived size.

Persist a bounded versioned local preset store, scoped to enrolled identities and orientation.
Store semantic dimensions/refresh, not reusable mode IDs. Names need length/count validation.
Resolve fresh inventories and reject missing/ambiguous modes, changed ownership, wrong
orientation or altered enrollment. Reuse `scaling_choices`, `scaling_proposal`, and the
journaled preview service; never add direct apply from the menu. Preview/Keep remains mandatory.

Acceptance: isolated tests for malformed store, unsupported schema, duplicate names,
concurrent save, unavailable mode, changed identities/rotation, stale option fingerprint,
restart during preview and menu termination before timeout. Saving one orientation preserves
the other. Atomic writes preserve the last valid store; corrupt originals are retained.
An old runtime ignores the additive store; rollback never deletes an unresolved preview journal.
Opt-in physical Keep/timeout/revert tests follow software checks on the exact installed revision.

### 3. Recovery and history that explain the next action

Show the failed phase, last observation, next retry or exhausted state, and one relevant action.
Keep a bounded local transition timeline with total time and phase timing. Separate DDC wait,
read retries, debounce, layout and audio recovery; show unavailable measurements as unknown.
Expose support-summary preview beside private diagnostics with clear sharing guidance.

Acceptance: no “fixed” claim from playback success alone; one notification per incident;
normal switching stays quiet; controller-unavailable and corrupt-state cases offer appropriate
inspection instead of blind repair. Do not infer total rotation latency from application time:
physical motion-to-detection still requires a timed physical observation.

### 4. Guided setup and capability preflight

Show which exact enrolled pair is supported, host role, ownership readability, mode metadata
availability, and conflicting running monitor-control apps. Distinguish unsupported from
unknown or temporarily unavailable. Do not stop other apps automatically. Explain disconnected
or replacement monitors without enrolling or writing them. Guide independent host enrollment,
calibration and read-only health before any opt-in physical test.

Acceptance: unfamiliar monitor untouched; no copying host-specific identities to Mac B;
interrupted setup preserves original configuration and has a tested rollback path. Document
settings-preserving uninstall and backup recovery. Mac B remains a separate test session.

### 5. Optional conveniences

Only after the above: explicit-target keyboard shortcuts with coalesced key repeats; manual
Day/Evening brightness presets; perceptual brightness calibration; optional listening test.
Explain Accessibility permission before global media keys and keep ordinary controls usable
without it. Fresh ownership checks and verified writes remain mandatory. Respect external
headsets and manual settings. Do not introduce automatic brightness schedules by default.

## Deliberately deferred

Virtual displays, arbitrary custom HiDPI injection, HDR enhancement, software dimming/color
filters, automatic input switching, network control, window management and unverified BenQ
MoonHalo/coding-mode writes. Their complexity or changed visual behavior does not address the
current highest-priority usability problems. A future HiDPI experiment must independently
prove compatibility, rollback and actual image quality before joining the runtime.

## Release and implementation gate

One slice at a time: source regression tests, native build/self-tests for UI changes, private
demo inspection, exact staged privacy review, conventional commit, CI. Deployment is separate:
check installed/source versions and preserve settings/backups. Public source must not contain
screenshots of real state, identifiers, raw diagnostic logs or personal paths.

Physical coverage still missing includes newer UI/preview flows, current-release switching,
headset preservation, Mac B/concurrent controllers and wake (deferred by user preference).
Earlier reported successful switching/audio is valuable but not proof of every later revision.
Use `docs/qualification.md` as the qualification record, not a blanket “all features work” claim.

Research: [current feature priorities](../research/display-feature-priorities-2026-09-20.md)
and [broader app comparison](../research/display-app-comparison-2026-09-20.md).
