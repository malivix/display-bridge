# Display app comparison and feature priorities

Research date: 2026-09-20. This is a product-planning comparison, not a security audit or a hardware compatibility certification. Vendor pages change; versions and connection support must be checked again before adopting an integration.

## Recommendation

Make the existing two-Mac handoff understandable, recoverable, and easy to configure before expanding into a general monitor utility. Display Bridge already provides ownership-aware layouts, audio recovery, calibrated rotation, brightness/volume steps, timed pauses, diagnostics, transition history, and reversible size previews. These should be polished rather than counted as missing features. See [usage](../usage.md), [qualification](../qualification.md), and the menu implementation in [display-menu.swift](../../native/display-menu.swift).

The highest-value additions are a clear per-monitor status panel, an acknowledged command lifecycle, saved readable-size presets, capability explanations, and guided enrollment/calibration. These recommendations are product judgments from the comparison below, not vendor claims.

## What other tools provide

| Tool | Licensing and useful capabilities | Implication for Display Bridge |
| --- | --- | --- |
| BetterDisplay | Current v5 comparison distinguishes free controls from paid flexible HiDPI, UI-size matching, advanced layout protection, and image filters. DDC, basic shortcuts, mode selection, diagnostics, and integration access are listed free; invoking Pro functionality still needs Pro. BetterDisplay is not open source. Free use has license conditions, including non-business restrictions. | Borrow clear per-display controls, capability discovery, size matching, and accessible diagnostics. Do not assume every documented feature exists on older supported macOS versions. [Official feature matrix](https://github.com/waydabber/BetterDisplay/wiki/List-of-free-and-Pro-features) |
| Lunar | Source is MIT licensed; the distributed app also has free and paid tiers. Free manual brightness/contrast adjustments have a documented 100-per-day limit. Pro adds adaptive brightness using synchronization, sensors, schedules, and location. | The useful pattern is calibration to perceived brightness and explicit manual overrides. Automatic brightness is optional future work, especially after earlier pulsing complaints. [Source/license](https://github.com/alin23/Lunar), [Pro guide](https://lunar.fyi/pro) |
| MonitorControl | Free MIT app focused on hardware brightness/contrast/volume, keyboard controls, OSD feedback, smooth transitions, and brightness synchronization. It documents limitations for some built-in HDMI ports and DisplayLink paths. | Best small-scope example for brightness/volume interaction. It is not a complete replacement for ownership-aware mirroring and audio-stream recovery. [Official repository](https://github.com/MonitorControl/MonitorControl) |
| BenQ Display Pilot 2 | Vendor software bundled for supported monitors; no open-source license or source release was established here. RD280UG is explicitly on its compatibility list. Features vary by model; the site shows quick controls, window partitions, Focus integration, and MoonHalo controls. | Borrow guided, model-aware controls. Do not assume features demonstrated for PD/MA displays apply to RD280UG or ASUS. [Compatibility](https://www.benq.com/en-us/monitor/software/display-pilot-2/spec.html), [Product page](https://www.benq.com/en-us/monitor/software/display-pilot-2.html) |
| displayplacer | MIT CLI for resolution, refresh rate, rotation, arrangement, and mirroring. Its own documentation warns about changing display IDs, invalid modes falling back, and disabled screens sometimes needing an unplug/replug. | Useful reference and manual troubleshooting tool, not a drop-in controller. Preserve identity checks and never introduce screen disabling into the normal workflow. [Official repository](https://github.com/jakehilborn/displayplacer) |

BetterDisplay's current README also documents distinct releases for different macOS generations. Its broader feature set includes virtual screens and PIP/streaming, but those expand capture permissions, rendering complexity, and maintenance. They are lower priority for this project's physical-monitor handoff. [Official README](https://github.com/waydabber/BetterDisplay)

## BenQ rotation and connection details

BenQ explicitly lists **Auto Pivot**, Display Pilot 2, 3840 × 2560, and 120 Hz for **RD280UG**. Its launch announcement ties automatic pivot to the rotating hinge. This is model-specific evidence; it must not be inferred from similarly named RD280U/RD280UA models. [RD280UG specifications](https://www.benq.com/en-us/monitor/programming/rd280ug/spec.html), [BenQ launch announcement](https://www.benq.com/en-us/news/monitor/best-coding-monitor-for-programmers.html)

These pages do not establish a public sensor API, a guaranteed DDC register, polling latency, or support on arbitrary replacement stands. Display Bridge's own calibrated readings and opt-in physical tests remain the relevant evidence for its implementation. Improve timing by separating sensor detection, stable-orientation confirmation, and layout application measurements before reducing safety checks.

BenQ's general software page contains broad HDMI limitations, while BetterDisplay and MonitorControl describe different hardware coverage. Treat these as tool-specific compatibility statements, not proof that DDC is universally impossible over Apple-silicon HDMI. Chip name alone is insufficient: record Mac model, port, adapter category, and actual successful reads locally. [BenQ FAQ on product page](https://www.benq.com/en-us/monitor/software/display-pilot-2.html), [MonitorControl connection limitations](https://github.com/MonitorControl/MonitorControl)

## Prioritized implementation candidates

| Priority | Deliverable | Observable acceptance |
| --- | --- | --- |
| First | Per-monitor dashboard showing ownership, current versus saved mode, rotation, selected audio, and status age | Unknown ownership never appears local; stale state is visibly stale; unknown monitors have no active mutation controls. Keyboard and VoiceOver users can reach every action. |
| First | Command progress and outcome | A request has an identifier and queued/running/succeeded/failed state. A CLI timeout is distinguishable from daemon failure. Reopening the menu shows the actual result without duplicate submission. |
| First | Guided enrollment and rotation calibration | Explain supported topology, identify both screens, capture each host independently, preview the change, and restore on failure. Show calibration validity and why automatic rotation is unavailable. |
| Next | Named size presets and physical-size matching | Use currently enumerated HiDPI modes with explicit logical size, framebuffer size, refresh, and orientation. Reuse timed preview/rollback. Save separate portrait/landscape presets. A synthetic size-matching calculation is verified independently of display mode IDs. |
| Next | Capability-aware brightness/volume controls | Show unsupported versus temporarily unavailable distinctly; coalesce rapid steps; preserve fresh ownership checks at execution. Media keys are opt-in with a clear target rule and an explanation of any permission. |
| Next | Diagnostic sharing preview | Keep full diagnostics private. Generate a separate allowlisted summary with synthetic display labels, preview it, and explain omissions; never automatically upload. Test serials, UUIDs, paths, and audio names for leakage. |
| Later | Optional named comfort presets | Explicit Day/Evening settings before sensor/location automation. Preserve manual overrides and ownership checks. Equal percentages must not be labeled equal luminance. |

Physical-size matching is not arbitrary per-application UI scaling or a guarantee of native-pixel sharpness. A preview must let the user compare readable size and rendering quality. Full custom HiDPI/virtual-display work deserves a separate feasibility experiment with rollback before entering the controller.

## Improvements that come before feature expansion

The [qualification document](../qualification.md) still defers Mac B, simultaneous controllers, headset transitions, sleep/wake, and cable/firmware combinations. Preserve these gaps visibly. Add a small repeatable qualification matrix tied to a source revision; unit checks cannot prove optical quality or audibility.

Avoid adding automatic input switching, software disconnect, cloud synchronization, HTTP control, or a general window manager to the initial roadmap. They do not solve the current handoff problem and increase the authority or failure surface. MoonHalo/color-mode controls should wait for a documented or independently validated model-specific protocol; do not probe unknown writable VCP values.

Open source permits inspection; it does not establish security by itself. Any reused implementation still needs license/attribution review, dependency review, and isolation behind the existing serialized command boundary. Running multiple tools that write the same monitor settings should be an explicit user choice with overlapping features disabled, rather than an automatic integration default.
