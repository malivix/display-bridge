# Display feature priorities after competitor review

Reviewed 2026-09-20 against first-party pages. This supplements [the app comparison](display-app-comparison-2026-09-20.md); it does not certify hardware compatibility, accessibility, or production readiness. Vendor claims below are distinguished from project recommendations. No competitor was installed or exercised for this review.

## Decision

Make readable desktop sizes easy to save and recover, then make enrollment understandable. Keep one implementation outcome active. The enrolled two-Mac/two-monitor handoff remains the product boundary: no automatic input switching, cloud account, network listener, or general window manager.

The earlier comparison's status panel, acknowledged requests, manual controls, and sharing-preview recommendations now overlap features documented in [usage](../usage.md). That document describes scalable status text, Controls readbacks, persistent request outcomes, reversible size previews, and an allowlisted support-summary preview. Treat these as existing documented functionality requiring validation, not new backlog items. [Qualification](../qualification.md) still explicitly leaves Mac B, concurrent controllers, sleep/wake, and headset transitions unresolved.

## Current evidence and limits

| Product | Confirmed first-party evidence | Free/paid and uncertainty | Useful lesson |
| --- | --- | --- | --- |
| BetterDisplay | Version 5 matrix lists free mode/refresh selection, DDC controls, basic shortcuts, diagnostics, and visual arrangement. Flexible HiDPI, UI-size matching, normalized brightness synchronization, advanced layout protection, and expanded image filters require Pro. | Free use is conditional under its license, including non-business terms. Integration access is free, but Pro operations remain licensed. Version 5 requires macOS 26.3 or later. The matrix is vendor-authored; compatibility is hardware-dependent. | Borrow mode clarity and deliberate size matching. Existing enumerated modes offer a smaller initial scope than a custom scaling engine. [Feature matrix](https://github.com/waydabber/BetterDisplay/wiki/List-of-free-and-Pro-features) |
| MonitorControl | Free MIT app provides brightness/contrast/volume, keyboard control, software dimming, synchronization, and OSD feedback. Its setup makes Accessibility permission necessary only for native Apple brightness/media keys. It warns that Tahoe's native OSD percentage does not show/update. | README names connection limitations, including specific built-in HDMI implementations and DisplayLink DDC. These are this app's limitations, not universal protocol laws. Its feature list is not a VoiceOver audit. | Offer ordinary controls without a global-key permission requirement. Keep confirmed values inline; do not depend on a transient system OSD. [Repository and setup](https://github.com/MonitorControl/MonitorControl) |
| Lunar | Site distinguishes manual brightness control and CLI from adaptive Pro features. Pro documentation explains per-monitor curves and perceived-brightness adjustment. Clock transitions may apply values every 30 seconds and prevent manual changes from persisting. | The distributed free app lists 100 manual adjustments and 100 Shortcuts action calls per day; Pro is advertised at $23 lifetime with a 14-day trial. Checkout taxes/conditions were not verified. Location mode can fall back to IP geolocation; external sensors can use network services. | Start with explicit local comfort presets and preserve manual choices. Do not import location/sensor infrastructure or continuously reapply values. [App tiers](https://lunar.fyi/), [Adaptive behavior](https://lunar.fyi/pro) |
| BenQ Display Pilot 2 | General page shows quick brightness/volume/color controls, window partitions, Focus integration, and MoonHalo controls, while warning features depend on monitor series. Specifications explicitly list RD280UG and macOS 13+. | Official pages provide downloads; no separate paid upgrade was established. That does not establish an open-source license. No public MoonHalo or orientation-sensor API was established. General PD/MA capabilities cannot be assigned to RD280UG or ASUS. | Model-aware explanations are useful; copying every vendor panel is not. Preserve a capability boundary and avoid probing unknown writable VCP codes. [Product page](https://www.benq.com/en-us/monitor/software/display-pilot-2.html), [Compatibility](https://www.benq.com/en-us/monitor/software/display-pilot-2/spec.html) |
| displayplacer | MIT CLI enumerates modes and applies rotation, arrangement, and mirroring. Documentation says mode enumeration is orientation-specific, some listed modes fall back, and persistent display IDs can change during wake races. Disabling a screen can require cable reconnection. | Open-source tool with no paid tier described. Its CLI behavior is not a guarantee that a chosen mode renders correctly. | Store desired mode properties and validate actual readback; do not blindly replay old mode numbers. Keep screens enabled. [Repository](https://github.com/jakehilborn/displayplacer) |

The BenQ page's broad M-series HDMI statement conflicts in scope with BetterDisplay's explicitly advertised HDMI support. Record actual Mac/port/adapter/software combinations locally; do not turn either vendor's claim into a universal rule.

## Narrow delivery order

This ranks new capabilities only. The fresh [UI review](../plans/ui-feature-review-2026-09-20.md)
places whole-interface readability ahead of them because the current Large/Largest setting
does not enlarge action buttons or selectors. Its combined delivery order is authoritative.

These priorities and acceptance criteria are project judgments, not claims made by the cited vendors.

| Order | Observable user result | Acceptance boundary |
| --- | --- | --- |
| 1 | Named readable-size presets for each orientation, building on existing timed preview | User can save and recall a larger-text choice without memorizing resolution numbers. Show logical/framebuffer size and refresh. Resolve against fresh enumerated modes; unavailable choices explain why. Retain Keep/Revert, recovery journal, topology and ownership checks. A successful API call alone is not a successful visual preview. |
| 2 | Guided enrollment and rotation calibration | Identify the enrolled screens clearly, explain each host's independent configuration, and show calibration validity. Preserve a known-good configuration on interruption or failure. Unknown displays never gain controls merely by matching a model name. |
| 3 | Explicit per-monitor comfort presets | Save chosen brightness values with user labels such as Reading or Evening. Apply only to freshly owned enrolled displays through the serialized controller. Manual adjustment persists; no periodic schedule overwrites it. Do not label equal percentages as equal luminance. |
| Optional follow-up | Keyboard access to the same bounded controls | Select a stable target explicitly and explain it in the UI. Global media keys remain opt-in with permission explanation and collision handling. No permission is requested just to open status. |

Physical-size matching is a later extension of readable presets. It needs trustworthy physical dimensions or user calibration and an observable text comparison. An approximate match must be labeled approximate; it cannot guarantee equivalent sharpness, visual comfort, or clinical benefit.

## Low-vision acceptance applies to every increment

Use the existing Large/Largest status text as a baseline. Verify keyboard navigation, visible focus, VoiceOver labels and values, and scrolling without clipped actions. Ownership, failure, and pending restoration need words as well as color. Keep/Revert must remain reachable and legible during the preview; provide an explicit keyboard revert action. Consider an adjustable preview duration for users who need more time while retaining automatic rollback.

Show the latest confirmed control value and its age separately from an intended value. Keep a stable result on screen after changes; brief OSDs and notifications alone are insufficient. Distinguish unsupported capability, stale reading, another host owning the monitor, and temporary communication failure. These are design requirements awaiting interaction testing, not statements of current accessibility conformance.

## Boundaries and stopping point

Do not add PIP/capture, virtual screens, arbitrary image filters, screen disabling, automatic input switching, remote APIs, window tiling, or location-driven brightness to this work. MoonHalo and color-mode writes require separately established model-specific protocol evidence. Existing controller safety rules still govern every shortcut and preset.

Finish one coherent preset workflow with automated state/rollback checks and a recorded physical visual preview before expanding. The physical matrix must separately cover both Macs, portrait/landscape, ownership changes during preview, wake, and recovery; outstanding cases stay explicitly unqualified. Readback is evidence of software state, not optical quality or audible sound.
