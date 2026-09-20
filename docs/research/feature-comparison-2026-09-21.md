# Feature comparison and next useful work

Reviewed 2026-09-21; reconciled with source `bfce4a4` after the `native/menu/` source split.
This refresh updates the [earlier comparison](display-app-comparison-2026-09-20.md)
and [product roadmap](../plans/product-ui-roadmap.md). Vendor documentation establishes
advertised capabilities, not compatibility with this pair or a security certification.
Recommendations below are project judgments. No competitor was installed or given access.

## Verified comparison

| Application | Useful verified capabilities | Licensing and compatibility limits | Lesson for Display Bridge |
| --- | --- | --- | --- |
| BetterDisplay | Its v5 matrix lists per-display mode/refresh selection, visual arrangement, DDC capability detection, diagnostics and basic shortcuts as free. Flexible HiDPI, UI-scale matching, advanced layout protection and advanced image adjustments require Pro. | Closed source. Free use is restricted to non-business use by its terms. Integration entry points being free does not make Pro operations free. Hardware/connection support varies. | Make existing controls easy to find and explain their availability. Improve readable-size comparisons; a resolution picker alone is not equivalent to flexible HiDPI. [Official matrix](https://github.com/waydabber/BetterDisplay/wiki/List-of-free-and-Pro-features), [license terms](https://betterdisplay.pro/license/) |
| MonitorControl | Native menu sliders, brightness/volume/contrast, keyboard controls, OSD, brightness synchronization and hardware/software dimming. Accessibility permission is only needed for its native Apple brightness/media-key handling. | Free app with an MIT license. Its README excludes DDC on specific built-in HDMI paths, including entry-level M2 Mac mini; “M2” alone is insufficient compatibility information. | Direct adjustment with an obvious target and visible result is valuable. Do not copy software dimming as an implicit fallback or request global-key permissions for ordinary UI use. [Official README](https://github.com/MonitorControl/MonitorControl#readme), [license](https://github.com/MonitorControl/MonitorControl/blob/main/License.txt) |
| Lunar | Adaptive brightness through source-display synchronization, sensors, location and schedules. It adjusts its mapping from manual changes rather than treating equal brightness percentages as equal perceived luminance. | Repository source is MIT; distributed free/Pro tiers are separate. Free manual brightness/contrast is limited to 100 adjustments daily; Pro removes the limit. Location mode documents IP geolocation fallback when location access is unavailable. | Borrow explicit targeting and user calibration, but prioritize stable manual presets here. Adaptive behavior and location services do not fit the current local-only, predictable workflow. [Pro behavior and tier limits](https://lunar.fyi/pro), [source license](https://github.com/alin23/Lunar/blob/master/LICENSE) |
| BenQ Display Pilot 2 | Quick monitor controls, Focus integration and MoonHalo controls are advertised, with features explicitly varying by monitor series. RD280UG is listed for macOS 13+. | Official download pages were found; no open-source license was established. RD280UG inclusion does not establish every advertised capability on that model, and does not imply ASUS support. No public writable MoonHalo or orientation-sensor API was established in this refresh. | Show model-specific capability reasons and calibration status. Keep unsupported vendor controls out of the UI. [Product page](https://www.benq.com/en-us/monitor/software/display-pilot-2.html), [supported models](https://www.benq.com/en-us/monitor/software/display-pilot-2/spec.html) |

BenQ's broad M-series HDMI statement and the more specific BetterDisplay/MonitorControl
support statements have different scopes. Resolve support by exact model, port, adapter and
read-only qualification; do not infer that all M2/M4 HDMI paths work or fail. Open source
permits inspection; it does not by itself establish secure binaries, safe hardware behavior
or dependency quality. A replacement dependency would need its own pinned-source review.

## Already implemented: improve and qualify, do not duplicate

The [usage guide](../usage.md) and [menu sources](../../native/menu/) already contain:

- A resizable, enlarged-text dashboard with Overview, Displays, Audio, Details and Controls.
- Guarded size previews, orientation-scoped named sizes, current/selected comparisons,
  brightness presets, monitor readbacks and availability reasons.
- Per-profile audio preference, manual preservation, recovery explanations/actions,
  failure notifications, command phase deadlines and retained outcomes.
- Read-only setup readiness, advisory detection of other display apps, a logical mirroring
  schematic, status freshness, timing summaries and reviewed local support-summary copying.
- Window-scoped tab/refresh shortcuts without global keyboard interception.

These are source capabilities. [Qualification](../qualification.md) records the installed
revision and physical gaps; source tests do not certify current installation or optical,
audible, VoiceOver or concurrent-Mac behavior. The native source split is complete in this source revision; it is not a new user-facing feature.

## Prioritized next slices

| Priority | Observable improvement | Small implementation and acceptance boundary |
| --- | --- | --- |
| First | Finish accessibility of existing workflows | Inspect keyboard traversal, focus preservation, VoiceOver names/values, light/dark appearance and Largest text in every preset/recovery dialog. Fix observed defects before adding controls. Existing snapshots cover only part of this matrix; no blanket accessibility claim. |
| High | More time to judge a size preview | Offer a bounded 20/40/60-second choice before preview, keeping 20 as default. This is a proposal: the controller currently starts a 20-second confirmation window and the UI clamps it to 20. Persist the selected deadline in the existing transaction, retain a hard maximum, and test restart, expired Keep, ownership changes and automatic restoration. Never implement this as UI copy alone. |
| High | Guided enrollment and rotation calibration | Extend the implemented read-only checklist with one reviewed capture/calibration flow using existing installer validation and backups. Show which enrolled role is being configured and why a step is waiting. Interruption must preserve the last valid configuration. Each Mac enrolls independently; unknown screens remain unmanaged. This is new mutable setup work, not an already implemented wizard. |
| Medium | Faster deliberate brightness adjustment | Add one selected-monitor slider with keyboard steps, desired versus confirmed values and age. Coalesce changes before the existing serialized write; recheck ownership immediately before dispatch. A failed or remote target must never receive queued retries. First measure write/lock latency; do not promise a smooth animation from delayed DDC. Existing buttons and presets remain the reliable baseline. |
| Medium | Explain slow switching with a recent-event view | Existing timing already shows counts, median/p95/max and phase breakdown. Add a bounded recent-transition list with outcome, missing-phase labels and a selectable detail. Sensor detection delay before the first valid read is still unmeasured: report that gap rather than attributing it to layout/audio. Use existing local data; no new polling or uploaded telemetry. |
| Later | Calibrated physical-size matching | Build on saved size pairs: show an approximate physical UI-size comparison, then let the user visually calibrate a match through the existing preview. Do not rely on EDID dimensions alone or promise native sharpness at arbitrary scales. Preserve the user's known-good sizes; no custom-mode injection in this slice. |

The integrated [implementation plan](../plans/ui-feature-review-2026-09-21.md) places the
concrete monitor-response validation defect before this feature backlog, then accessibility
and longer previews. These rows are not simultaneous implementation promises. A mutable slice requires a short plan,
focused regression coverage, native verification where applicable, and an opt-in physical
check tied to the installed revision.

## Fixes and exclusions

The current [menu presentation](../../native/menu/Presentation.swift) parses multiple
untyped JSON reports and [app orchestration](../../native/menu/MenuApp.swift) dispatches
results through a long command-specific chain. These are maintainability risks, not proven
hardware faults. Strengthen typed response boundaries as the affected workflow changes;
keep malformed/unknown values visibly unknown and controller checks authoritative.

Consolidate roadmap status so shipped source features are not repeatedly listed as missing.
Preserve historical observations while pointing readers to one current delivery sequence.

Do not expand this plan into virtual displays, capture/PIP, window tiling, arbitrary color
filters, remote APIs, automatic input switching, software disconnection or adaptive
brightness. These add failure paths without improving the enrolled-pair handoff. Vendor
MoonHalo/color writes require model-specific protocol evidence; no blind writable-VCP
probing. Shortcuts/App Intents may later wrap the existing guarded commands, but global
media keys and their target/permission rules deserve their own bounded design.
