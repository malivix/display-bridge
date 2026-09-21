# Display product comparison refresh

Primary sources checked 2026-09-21. Local baseline: `1f30912`, including the working
README, usage guide, implementation entry points and feature logs. No competitor was
installed, no hardware command was issued, and this research does not qualify a release.
This updates the interpretation of [earlier priorities](display-product-priorities.md);
several previously recommended additions now exist in source.

## Current evidence

| Product | Relevant first-party evidence | Limits and lesson for Display Bridge |
| --- | --- | --- |
| BetterDisplay 5 | Free mode includes mode/refresh selection, visual arrangement, DDC discovery, diagnostics and basic integrations. Pro includes flexible HiDPI, UI-scale matching, brightness normalization and advanced layout protection. | Closed source. Free use is subject to license conditions, including non-business use; free CLI access does not unlock Pro operations. Version 5 requires macOS 26.3+, unlike Display Bridge's macOS 13 baseline. DDC depends on the precise connection. Adopt clear size comparisons and capability reporting, not a dependency on BetterDisplay. [Official matrix](https://github.com/waydabber/BetterDisplay/wiki/List-of-free-and-Pro-features) |
| BenQ Display Pilot 2 | RD280UG appears in the supported macOS models; the compatibility page specifies macOS 13+. Its product page advertises Focus synchronization and MoonHalo controls. The RD280UG specification explicitly lists Auto Pivot, MoonHalo and Display Pilot 2 support. | Vendor download availability does not establish an open-source license. No ASUS compatibility or public rotation/MoonHalo protocol was established. General software marketing does not prove every feature on this model or connection, nor rotation latency. Prefer model-specific capability states and a useful explanation of rotation waits. [Compatibility](https://www.benq.com/en-us/monitor/software/display-pilot-2/spec.html), [software](https://www.benq.com/en-us/monitor/software/display-pilot-2.html), [RD280UG](https://www.benq.com/en-us/monitor/programming/rd280ug/spec.html) |
| MonitorControl | Brightness, volume and contrast sliders, keyboard control, OSD and synchronization form a compact direct-control experience. Native Apple media keys need Accessibility permission; menu sliders do not. | Free with [MIT source](https://github.com/MonitorControl/MonitorControl/blob/main/License.txt). Its documented hardware-DDC exclusions include built-in HDMI on M1 Macs and entry-level M2 Mac mini, and DisplayLink paths. Software dimming is a separate fallback, not proof of a hardware write. Its README also describes current native-OSD limitations. Adopt target clarity and keyboard-adjustable controls. [Official README](https://github.com/MonitorControl/MonitorControl) |
| Lunar | Adaptive mappings learn from manual corrections; sensor mode can use supported Apple ambient sensors or an external network sensor. Free brightness/contrast control is limited to 100 adjustments daily; Pro lifts this limit. | The repository has an [MIT license](https://github.com/alin23/Lunar/blob/master/LICENSE); that is distinct from distributed-product Pro access. The useful lesson is user calibration, because equal percentages need not look equal. Network sensing and ongoing adaptive changes add little to this deterministic local workflow. [Official behavior](https://lunar.fyi/pro) |

These sources do not establish that any alternative reproduces the enrolled two-Mac,
input-ownership, mirroring and audio-recovery workflow. Feature availability is not proof
of performance on this pair. Any future source reuse requires a pinned code/license review
and preserved notices; this refresh copies no competitor code.

## Existing source, not new backlog

- **Reversible size matching in both directions:** `physical_match` in
  [scaling_choices.py](../../scaling_choices.py) preserves either reference monitor and
  selects a qualified close mode for the other. Named orientation presets and timed
  Keep/Revert previews already exist. These are model estimates, not visual calibration.
  See [reference selection](../log/physical-match-reference.md).
- **Independent graphical setup:** [setup_gui.py](../../setup_gui.py) and the
  [setup model](../../native/setup/SetupModel.swift) provide a separate host review and
  explicit installation flow. The old plan's statement that mutable graphical setup is
  absent is stale; current [README](../../README.md) documents it.
- **Explicit listening check:** [menu implementation](../../native/menu/MenuApp.swift)
  offers Test selected output and a subsequent user response. Playback completion does
  not assert audibility. See [behavior and limits](../log/audio-listening-check.md).
- **Rotation freshness and wait reasons:** observation age, confirmation and blocking
  states are already presented. Polling and safety gates were preserved; detailed
  in-flight phases and physical latency measurements remain open.
  See [implementation record](../log/rotation-observation-status.md).
- **Direct controls and diagnostics:** brightness buttons/presets, volume, local reports,
  recovery and build-agreement reporting are existing baseline features, described in
  [usage](../usage.md). A continuous brightness slider remains deferred.

## Highest-value remaining work

The following ordering is an engineering recommendation, not a vendor claim.

1. **Visual size calibration.** Extend the existing matching preview with a simple
   comparison target and explicit reference choice. Preserve the reference mode and
   existing transaction/rollback boundary. Let the user judge the relationship in both
   orientations; never promise arbitrary-scale native-pixel sharpness.
2. **A responsive, explicitly targeted brightness slider.** First measure command
   latency, then coalesce changes to the latest intent through the controller. Show
   desired versus confirmed value and reading age. Discard pending changes on ownership
   loss; keep keyboard steps and current buttons usable. Do not silently substitute
   software dimming when DDC fails.
3. **Qualify the features already built.** Exercise graphical setup interruption,
   actual listening responses, rotation in both directions and matching previews on the
   exact installed revision. Mac B, simultaneous controllers, headset transitions and
   sleep/wake remain explicit [qualification gaps](../qualification.md). Measure rotation
   phases before changing debounce or polling; app timings alone exclude unknown physical
   sensor delay.

Defer Focus-driven color changes, HDR boosting, virtual displays, PIP, network control and
undocumented MoonHalo writes. They do not resolve the immediate readability/control gaps.
Physical input switching and automatic disconnection contradict the current
[controller invariants](../../AGENTS.md). Keep fixed 120 Hz/HDR off and the local runtime
boundary when adapting any competitor idea.
