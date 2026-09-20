# Next features from display-tool research

Reviewed 2026-09-20. This is an addendum to [the earlier priorities](display-feature-priorities-2026-09-20.md), using freshly opened first-party pages. No competitor was installed, audited for security, or tested on the enrolled hardware. Recommendations below are project judgments, not vendor guarantees.

Named orientation-specific size presets, timed previews, inline reports, timing summaries, and scalable controls already exist in source. They should be qualified, not counted again as new features. See [usage](../usage.md) and [qualification](../qualification.md); source availability does not establish installed or physical behavior.

## What the other tools actually contribute

| Tool | Verified distinction | Relevant lesson |
| --- | --- | --- |
| BetterDisplay | Its version 5 matrix lists visual arrangement, basic shortcuts, and integration access as free, while UI-scale matching and adaptive layout protection require Pro. It explicitly marks the app as not open source; free use has license conditions. | A graphical explanation of the current layout and deliberate size comparison are more valuable here than copying its entire feature catalogue. [Vendor matrix](https://github.com/waydabber/BetterDisplay/wiki/List-of-free-and-Pro-features) |
| MonitorControl | MIT, free; brightness/volume controls, synchronization, keyboard shortcuts, and multiple dimming methods. Accessibility permission is needed for native Apple media/brightness keys, not basic menu controls. | Offer local keyboard access first, with a visible target and persistent readback. Global key interception can remain optional. [Repository](https://github.com/MonitorControl/MonitorControl) |
| Lunar | Repository identifies MIT licensing, while the distributed application has free/Pro tiers; its site limits free manual adjustments and Shortcuts calls to 100/day. Source licensing and the packaged commercial offering are distinct. | Explicit comfort choices fit this project better than adaptive brightness. Its gamma fallback changes rendered colors rather than hardware brightness, so a fallback must never silently masquerade as a working DDC write. [Source](https://github.com/alin23/Lunar), [Product and tiers](https://lunar.fyi/) |
| BenQ Display Pilot 2 | Offers quick brightness/volume/color controls and series-dependent features, including Focus integration and MoonHalo controls. RD280UG is listed for macOS 13+. Public download availability does not establish an open-source license; none was established in this review. | Explain capabilities per enrolled model. The general product page does not establish an RD280UG control protocol or grant those features to ASUS. [Product](https://www.benq.com/en-us/monitor/software/display-pilot-2.html), [Compatibility](https://www.benq.com/en-us/monitor/software/display-pilot-2/spec.html) |
| displayplacer | MIT CLI for arrangement, resolution, rotation, and mirroring. It documents orientation-specific modes, mode fallback, and identifier changes during wake races. | A visual layout editor must preview semantic mode properties and verify the result, rather than blindly replaying mode numbers or assuming identifiers never change. [Repository](https://github.com/jakehilborn/displayplacer) |

BetterDisplay's settings-transfer guide explicitly warns that identifiers differ between Macs and that importing replaces settings. This supports an independently enrolled Mac B workflow, not copying Mac A's entire runtime directory. The guide describes version 4.0.3; it is evidence of the identity problem, not a verified version 5 migration procedure. [Settings guide](https://github.com/waydabber/BetterDisplay/wiki/Export-and-import-app-settings)

## Ranked work worth implementing

Complete one outcome at a time. These are additions or improvements to existing workflows, not requests to replace working automation.

| Priority | User outcome | Smallest useful implementation and acceptance |
| --- | --- | --- |
| 1 | Understand why automation is waiting and reach the appropriate action | Put a context-sensitive action next to the recovery explanation: read-only health check for unavailable state, retry restoration for a pending size rollback, audio repair only when existing guards permit it. No repair button during an ordinary transition. Refresh authorization on click; stale UI must never bypass backend guards. |
| 2 | Set up Mac B without editing machine-specific files | A guided enrollment checklist first: detected identities, configured input map, missing calibration, controller/menu versions, and exact next step. Show a read-only review before any later enrollment mutation. Interrupted setup preserves the current configuration. Unknown monitors remain unmanaged. |
| 3 | Adjust readable size without racing a small dialog | Finish keyboard and VoiceOver qualification of current previews; keep Revert reachable at the largest UI size. Consider a user-selected longer preview period only after updating the controller deadline, restart recovery, and UI together. Test expiry, ownership loss, and process exit. This is an improvement to previews, not another preset system. |
| 4 | Apply a deliberate Reading or Evening brightness choice | Save per-monitor hardware brightness values, then apply once through the controller after fresh ownership checks. Show requested versus confirmed value and any partial result. Preserve subsequent manual changes. Do not schedule repeated writes or promise equal luminance from equal percentages. |
| 5 | Reach common actions without opening several menus | Window-scoped key equivalents for status, preview/revert, and selected-monitor brightness. Announce the target and disabled reason. Later Shortcuts support should submit the same bounded commands, never call hardware directly or introduce an HTTP listener. |
| 6 | Understand physical layout and approximate size matching | Start with a read-only two-monitor diagram showing ownership, mirroring source, rotation, and saved/current size. Add editing only through reversible transactions. Physical-size matching needs trustworthy dimensions or user calibration; label estimates and let the user compare text. |

## Reliability and scope decisions

- Validate recent UI changes against malformed and stale state, interrupted commands, and mixed source/installed versions before adding another hardware feature. Read-only reports should remain usable when controls are unavailable.
- Treat public-source availability as reviewability, not a security certification. This review does not recommend adding a runtime dependency, copying code, granting new permissions, or running competing controllers together.
- Defer MoonHalo, vendor color modes, automatic Focus changes, adaptive brightness, gamma overlays, and temporal-dithering controls until there is a specific need and verified model-specific behavior. They can alter the image or create competing policies; marketing descriptions do not supply safe write commands.
- Keep automatic input switching, screen disconnection, network control, arbitrary virtual displays, and window tiling outside this project. They expand the failure surface without improving its defining handoff workflow.
- Qualify Mac B, both return orders, ownership changes during preview, and headset preservation separately. No software report can certify audibility, sharpness, or absence of flicker.

The next feature milestone should be a user completing a guided setup and recovery path without Terminal, with existing desktop and audio behavior preserved. A longer feature list is not the acceptance test.
