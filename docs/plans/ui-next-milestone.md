# UI review and next implementation milestone

Reviewed source `f82e182` on 2026-09-20. This is the current sequencing addendum to
[the earlier review](ui-feature-review-2026-09-20.md), whose missing-feature list is
historical. No runtime or monitor settings changed in this review.

## Evidence and coverage

Rebuilt the isolated native demo from this revision with the macOS 13 arm64 target.
Captured and reopened three screenshots and inspected their accessibility trees.
Private images remain in the ignored local UI review directory; they contain synthetic
state. This covers the Overview, size chooser and exhausted-recovery path, not all UI.

1. **Overview, healthy:** usable grouping, readable ownership and selected speaker.
   Current/saved size and mirror-source relationships are not summarized here. The
   persistent multi-row footer consumes space even when its actions are unrelated to
   the tab. Evidence: `01-overview.png`; `statusSections` and `showPanel`.
2. **Size chooser:** usable selection and explicit preview/Save/Remove/Cancel actions.
   It presents raw logical dimensions and separate availability text, rather than a
   selected current-versus-proposed comparison. Native dialog headings and action
   buttons remain small relative to its content. Identical preset names in different
   orientations need their orientation attached in the comparison. Evidence:
   `02-size-chooser.png`; `chooseSize`, `savePresetPrompt`, `removePresetPrompt`.
3. **Exhausted recovery:** explains the three-attempt limit and correctly avoids claiming
   audible sound. Finding the prescribed Repair audio action requires another tab or
   menu; it is absent beside the explanation. Recovery is below the initial viewport
   and needs scrolling. Evidence: `03-recovery.png`; `recoverySummary`, `showPanel`.

The demo uses fixtures and blocks mutations. Captures establish visual/structural facts,
not controller results. Keyboard focus was visible, but complete keyboard traversal,
VoiceOver speech, light appearance and all Large/Largest dialogs remain unqualified.
The existing installed app is not asserted to match this source. Previous physical
reports are recorded in [qualification](../qualification.md), not repeated as new tests.

## Existing features: preserve and qualify

Built: enrolled-pair ownership guards; profile/mirroring reconciliation; targeted audio
recovery; calibrated rotation; fixed-refresh/HDR policy; timed reversible size preview;
orientation-scoped named presets; pause/manual audio controls; monitor brightness/volume
steps; incident notifications; private diagnostics and allowlisted support summaries;
retained report views and phase timing; stale-state and unreadable-controls handling.

Do not create second implementations of these. The shortcomings are discoverability,
comparison quality, capability explanation and qualification. Current source still uses
one large native file for presentation, commands and view construction. Extract pure
presentation models and cohesive views only as affected workflows change; avoid a
whole-file rewrite competing with user-visible improvements.

## Delivery order

### 1. Recovery action beside the explanation — source implemented

Source implementation and current validation: [recovery action log](../log/contextual-recovery-action.md).
Physical and full accessibility qualification remain pending.

Outcome: a user can reach the appropriate inspection or recovery request without
searching another tab. Select one action from fresh health/control state:

| Situation | Action |
| --- | --- |
| Missing/stale status, unreadable controls or state-error | Check health |
| Size restoration needs repair with a fresh token | Retry size restoration |
| Exhausted audio recovery and existing audio guard allows it | Repair audio |
| Repair blocked by manual override/paused policy | Show reason and appropriate navigation; no implicit policy override |
| Ordinary settling, retries or ownership wait | Explain waiting; no repeated-repair prompt |
| Healthy | No recovery action necessary |

Implement a pure action description, render an adaptive button inside the Recovery group,
and submit through `execute`. Re-evaluate on click; retain backend authorization and
fresh preview token checks. Never infer a generic reset from an error string. Busy state
must not permit duplicate submission. An expired request should report rejection clearly.

Acceptance: table-driven state cases, stale-on-click, missing token, preserved manual
headset policy, keyboard focus through refresh, minimum window at Largest. No new DDC
polling from UI refresh. Rollback replaces the menu only when command compatibility is
preserved; no state migration or journal deletion.

### 2. Accessible size comparison — comparison panel implemented

[Implementation and validation](../log/accessible-size-comparison.md). Preset-management
dialog accessibility and physical qualification remain open.

Outcome: choose a readable size based on what changes, then Keep or Revert confidently.
Use an adaptive comparison sheet with Current and Selected columns per monitor. Show
logical dimensions, framebuffer, refresh/HDR policy, orientation and estimated UI-size
change. For unchanged physical panel width, use old logical width / proposed logical
width as the horizontal size estimate; do not equate it with cross-monitor physical
matching or native pixel sharpness. Explain unavailable presets alongside their names.
Separate preset management from preview confirmation and preserve focus on validation
errors. All text and controls must follow interface size, including dialogs.

Keep the existing 20-second deadline initially. A longer optional accessible timeout is
a separate controller/UI change: `scaling_preview.py` owns keep_until and the hard
lifetime; `previewRemaining` currently caps the UI at 20. Changing copy alone is incorrect.

Acceptance: orientation mismatch, unsupported modes, stale fingerprint, corrupt presets,
Largest/minimum window, keyboard/Escape/VoiceOver, Keep/timeout/revert, menu termination
and controller restart. Physical optical/readability comparison remains opt-in.
Rollback retains original preview journals and preset schema.

### 3. Guided setup and capability review

Outcome: prepare Mac B and explain unmanaged monitors without editing JSON. Begin with a
read-only checklist using enrolled identity categories, role/input mapping, calibration
presence, mode availability, installed helper agreement and explicit unknown states.
Show exact next steps and distinguish unsupported from temporarily unavailable.
Detecting another control app should be advisory, never terminate it automatically.

A later enrollment step needs an explicit review, backup, atomic validated write and
interruption recovery. Never copy Mac A identities, presets or runtime journals to Mac B.
Unknown monitors remain untouched. Qualification requires fresh independent enrollment,
both return orders and simultaneous-controller tests on Mac B; do not claim this from
Mac A unit tests. Rollback restores the prior configuration through existing mechanisms.

### 4. Deliberate brightness presets and keyboard access

Outcome: one explicit Reading/Evening choice or focused-window shortcut, with visible
monitor target and confirmed hardware value. Save brightness separately from size presets;
no automatic schedule, gamma fallback or replay on every refresh. Report partial results
per monitor and preserve subsequent manual changes. Equal percentages do not mean equal
luminance. Handle disconnect/ownership change between writes without touching remote
monitors. Window shortcuts need no global key interception; global keys remain optional
and permission-explicit. Scope and regression tests precede adding persistence.

### 5. Read-only layout diagram

Show ownership, source/destination of mirroring, rotation and current/saved size, together
with textual accessible equivalents. This improves understanding before considering a
layout editor. Physical-size matching needs trusted dimensions or user calibration.
Any later editing must reuse reversible transactions rather than direct CoreGraphics calls.

## Reliability work paired with delivery

- Add explicit installed-command capability/version negotiation before exposing commands
  absent from an older runtime. Same version labels can conceal different source builds;
  inspect existing helper-hash checks before introducing another identity mechanism.
- Exercise parseable-but-invalid control fields and old/mixed health schemas, not only
  unreadable JSON. Backend validation remains authoritative; UI defaults must not suggest
  certainty when configuration is invalid. This is a review target, not a proven exploit.
- Distinguish command timeout from queued-operation failure; a CLI deadline does not cancel
  daemon work. Retain command IDs and guide inspection before retrying.
- Keep status/report snapshots separate and show unavailable metrics explicitly. Measure
  sensor detection separately from apply latency before promising faster rotation.
- Consolidate overlapping roadmap status after each delivered slice. Keep original audit
  evidence historical and link to current implementation rather than rewriting history.

For each runtime slice: focused regression coverage, native build/self-tests, demo
inspection, staged privacy checks and Conventional Commit. Deployment uses a coordinated
settings-preserving install and exact-revision checks; no unrelated physical test is
silently performed. This review is planning, not a production-ready certification.

## Competitor-informed boundaries

See [fresh primary-source comparison](../research/display-tools-next-features.md).
Borrow BetterDisplay's understandable layout/scale workflows, MonitorControl's direct
hardware feedback, Lunar's explicit targeting, and Display Pilot's model capability
explanations. Do not add vendor-specific MoonHalo/color writes without protocol evidence,
auto-input switching, arbitrary virtual displays, cloud control or adaptive visual effects
as part of this milestone. These introduce new failure paths unrelated to reliable handoff.
