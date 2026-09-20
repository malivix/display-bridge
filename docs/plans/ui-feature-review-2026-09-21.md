# Current UI review and implementation plan

Reviewed 2026-09-21 against source `8971f96` plus the existing uncommitted enrollment-review
UI. This is the single current delivery order; older plans and logs remain historical.
The review inspected source and the isolated synthetic app in dark appearance with Largest
text, including Overview, Displays, Audio, Controls and exhausted recovery. No physical
monitor, audio route, installed controller or service was changed. A demo observation is
not a finding that the installed controller behaved incorrectly.

## Decision

Finish the existing recovery and setup experience, then add calibrated physical-size matching.
That directly serves readable interfaces across this monitor pair. Brightness sliders and
Shortcuts are useful subsequent conveniences. Automatic handoff, audio repair and rotation
remain the core; a broader feature count does not establish reliability.

First-party comparison and product judgments: [current research](../research/display-product-priorities.md).

## What already exists and what is actually verified

| Capability | Source state | Remaining evidence or usability gap |
| --- | --- | --- |
| Ownership-aware extended/mirrored desktops | Implemented with identity and input guards | Earlier physical return-order tests passed on one setup; new-source and simultaneous Mac B qualification remain separate. |
| Speaker preferences, manual preservation, bounded repair | Implemented | Earlier monitor listening tests passed; headset transitions and the complete latest release need qualification. Selection/readback cannot prove sound. |
| BenQ sensor rotation | Implemented, with calibrated orientation profiles and an accelerated stable-input path | End-to-end sensor latency is not fully measured; no fixed-latency promise. |
| Size previews and named orientation presets | Implemented, with 20/40-second confirmation and recovery journals | Native sharpness at arbitrary scale is impossible to promise; physical cross-monitor matching is not implemented. |
| Brightness/volume and brightness presets | Implemented, with typed result validation | Continuous adjustment and physical pacing remain unqualified. |
| Enlarged interface, window shortcuts, contextual repair | Implemented | Partial keyboard/visual checks; no complete VoiceOver, appearance or state matrix. |
| Failure notifications, history, diagnostics, reviewed copy | Implemented | Notification delivery and incident lifecycle need installed-session qualification; raw diagnostics remain private. |
| Setup readiness and prospective enrollment | Read-only CLI implemented; native host-choice review exists in the working tree | Mutable graphical setup is not implemented. This review does not mark the uncommitted UI shipped. |

See [qualification](../qualification.md) for exact historical deployment evidence. A source
build, an installed heartbeat and a physically usable/audible outcome are different results.

## Findings to fix first

| Priority | Reproduced or source evidence | Required fix |
| --- | --- | --- |
| High | Largest-text demo Overview shows “Recovery needs attention” but the explanation and Repair audio action are below the initial viewport. `MenuApp.showPanel` creates Recovery after both monitors and Audio. | Put the current incident, reason and safe next action directly after the summary. Keep the same controller guard and one authoritative incident presentation. Long secondary details may scroll. |
| High | Audio preferences occupy the initial viewport; repair/manual controls are below all four profile selectors. Inspected visually and in the accessibility tree. | Place current output, current policy/override and relevant action first, followed by profile preferences. Scrolling for secondary preferences is acceptable; hiding the immediate recovery action is not. |
| Medium | A fresh demo `display-info` always uses PG-local/BenQ-away data while the ready Overview reports both local. Refresh immediately reports changed inputs. The fixture is hardcoded in `MenuApp.execute`. | Derive demo snapshots from the selected scenario. Cover extended, single-local, away and unknown without making up measurements. Preserve a separate intentional stale-snapshot scenario. This is a demo defect, not demonstrated live state corruption. |
| Medium | Details exposes Review enrollment as a report followed by a generic Refresh button, although it opens a host-choice dialog. Source and accessibility inspection. | Give setup a clear Review this Mac action; distinguish read-only inspection from Save enrollment/Install before adding mutation. Do not make first-time users infer an action from a report refresh. |
| Medium | Native window is branded Display Bridge, but launcher and notification guidance still refer to Display Auto. `docs/usage.md` and `MenuApp.execute`. | Align visible names and explain the legacy installed app name. A bundle/LaunchAgent migration is a coordinated deployment change, not a cosmetic rename or new duplicate service. |
| Medium | Feature support, reports and results still use several command-specific dispatch branches. Some reports already have typed decoders. | Deepen the affected response boundary as each workflow changes. Keep invalid values unknown; move shared demo state into one fixture provider. Avoid a speculative rewrite of the whole controller. |
| High release gate | Current-source features outpace installed qualification; full accessibility and Mac B tests are absent. | Show app/controller compatibility and deployment readiness together. Do not label compiled source activated or all features verified. |

These are usability/review priorities, not severity claims about a security exploit. Screenshots
contain synthetic data and remain local; the evidence above records the scenario and source seam.

## Ordered implementation slices

### 1. Recovery-first interface — next code change

Reorder Overview by current incident priority and bring Audio's current route/action ahead of
preferences. Use existing `recoveryAction`/availability decisions; presentation must not start
repair automatically. Show pending retry versus exhausted failure, last-known output versus
fresh readback, and manual preservation separately. Avoid moving keyboard focus on heartbeat
refresh or repeatedly announcing the same incident.

Acceptance: at Largest and the supported minimum window size, the reason and a relevant action
(or precise unavailable reason) are initially visible in exhausted recovery. Verify ready,
waiting, unknown-input, stale, manual-audio and preview-restoration states; Tab/Shift-Tab,
Return/Escape and action focus remain usable. Old incident notification clicks cannot repair a
new incident. No new mutation endpoint or journal schema. Rollback is the coordinated release.

### 2. Trustworthy UI qualification and setup entry

Fix the scenario-inconsistent snapshot; keep demo fixtures hardware-free. Finish and review
the existing enrollment-review work without treating its report as authorization. Consolidate
Setup readiness, explicit host choice, app/controller compatibility and the next step in one
entry point. After the read-only flow is verified, separately implement guided capture and
activation using existing installer backups and fresh checks.

Acceptance: no role preselected, unsupported controller dispatch blocked, wrong-host/malformed
reports rejected, cancellation leaves configuration/services alone. Extra monitors remain
unmanaged. Mutable activation must independently revalidate identity, ownership, fixed refresh,
HDR policy and pending previews; interruption preserves a usable prior installation. Never copy
Mac A identifiers to Mac B. Compatibility does not substitute for physical Mac B testing.

### 3. Calibrated physical-size matching — highest-value new feature

Add “Match interface size” to the size-preview flow. Compare physical length per logical point,
using orientation-correct panel dimensions only when trustworthy. Let the user visually compare
a ruler or sample panel and adjust the estimate. Show the predicted size difference between
monitors, not just a resolution pair. Retain the known-good saved pair and offer qualified HiDPI
modes through the existing transaction, with 20/40-second Keep/Revert.

Acceptance: missing/unreliable dimensions produce “estimate unavailable,” not false precision.
Portrait/landscape use correct axes. No invented mode IDs or arbitrary custom-mode injection.
Ownership/orientation changes and expired confirmation preserve rollback. Label resampling
tradeoffs: a 2× framebuffer is not necessarily native panel-pixel sharpness. Native resolution
and uniform application UI enlargement are separate limitations; Chrome page zoom does not
scale its tabs/toolbars. Judge readability and optical results with the user after deployment.

### 4. Explain and then reduce rotation/switching latency

Existing history includes settling, rotation check, layout, input confirmation and audio phases.
`total` starts after state confirmation; it does not include the unseen time before the first
valid input/sensor observation. Failed attempts currently omit successful-phase durations.
Add explicit first-observed-to-ready timing and bounded partial failure phases, keeping unknown
pre-observation delay labeled unmeasured. Expose sensor state, requested orientation and measured
orientation distinctly, then optimize the measured bottleneck.

Acceptance: monotonic durations, missing phases remain missing, overlapping aggregates are not
summed, failed attempts retain useful completed phases. Compare bounded local samples before
and after. Do not reduce ownership checks or flood DDC to make a benchmark smaller. No promise
that a faster native rotation call fixes physical sensor reporting or panel handshake delays.

### 5. Explicit speaker listening check

Add a user-started quiet, bounded sample for the current selected output and a Heard it / No
sound response. Show this separately from software route verification. Do not select another
output or override a headset merely to perform the check. The response is a local observation
for this session, not a permanent certification of that device.

Acceptance: playback timeout/error never means audible; no sample during automatic switching,
no repeated recovery loop, and no public export of raw device identifiers. Recheck ownership
before any monitor-targeted action. A command completion alone must not produce “sound works.”

### 6. Faster manual brightness adjustment

Add a selected-monitor slider with keyboard steps, desired/confirmed values and readback age.
Coalesce unsent intent through the existing serialized controller boundary; define cancellation
when the selected target, ownership or app lifecycle changes. Start with one monitor at a time.

Acceptance: delayed/error responses never overwrite a newer intent or show unconfirmed values
as successful. An input switch invalidates unsent work. No automatic write retries to a remote
monitor. Measure DDC latency before choosing a debounce interval. Existing step buttons and
presets remain available. Equal percentages do not imply equal physical brightness.

### 7. Optional local Shortcuts

Wrap existing read-only status, timed pause and an explicitly selected preset in bounded local
commands. Keep display target and result obvious. Start without a network listener, global key
hook or new Accessibility permission. Return unsupported/unsafe/unavailable reasons; shortcuts
must pass exactly the same identity, ownership and preview gates as the app.

## Explicitly deferred

Ambient/location/schedule brightness, automatic HDR/Focus changes, MoonHalo writes, overlays,
virtual displays, PIP, window management and arbitrary custom modes need a separate demonstrated
need and protocol/platform investigation. Do not copy licensed implementation code from vendor
binaries. No automatic physical-input switching, software disconnection, cloud sync or remote
control in this roadmap. These conflict with deterministic local ownership or add unnecessary
access for the current workflow.

## Verification and stopping criteria

Each slice gets focused regressions, `scripts/verify`, native checks when applicable, and a
staged privacy review. UI inspection covers keyboard and visible layout; VoiceOver spoken output
must be checked separately. Use the existing synthetic scenarios for safe inspection, not an
assertion that they simulate real deadlines, hardware, permissions or sound.

Before deployment, recheck the actual enrolled inputs and coordinated installer preconditions.
Do not infer a new mapping from an unexpected value. Keep the user's current display sizes,
fixed 120 Hz and HDR-off policy. Mac B remains a later independent qualification session.
Publish only sanitized evidence and specific passing cases. Finish one slice before starting
the next; a feature comparison is not a commitment to implement every competing feature.
