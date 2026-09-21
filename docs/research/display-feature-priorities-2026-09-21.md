# Display features: evidence and remaining priorities

Primary sources checked 2026-09-21 against source `c3e19ba`. This refresh complements
[the earlier comparison](display-competitor-refresh-2026-09-21.md), correcting two Lunar
claims and separating new work from features already delivered. No competitor was
installed, no hardware was changed, and no optical or audio outcome was tested.

## Material corrections

- **Lunar is not a completely rebuildable open-source replacement.** Its public repository
  carries an MIT license, but its README explicitly says paid-feature code is hidden and
  the application cannot be built from that repository. Publicly licensed components and
  a fully auditable distributed application are different claims.
  [Lunar repository](https://github.com/alin23/Lunar)
- **Lunar's free adjustment limit is version-dependent.** The product's Pro page still
  describes a 100-per-day brightness/contrast limit, while its official **7.0.0b1** notes
  remove that limit. The latter is a beta release note; this review does not establish
  which stable binary contains the change. Do not repeat an unconditional limit or
  describe the beta behavior as qualified stable behavior.
  [Pro page](https://lunar.fyi/pro),
  [7.0.0b1 notes](https://files.lunar.fyi/ReleaseNotes/Lunar-7.0.0b1.html)
- **Vendor HDMI generalizations are not universal hardware facts.** BenQ's software FAQ
  makes a broad M-series HDMI/DDC exclusion; MonitorControl documents narrower exclusions,
  and BetterDisplay documents additional HDMI support. These are different implementations
  and support statements. Preserve connection-specific tests instead of deriving capability
  from “M2” or “M4” alone. [BenQ FAQ](https://www.benq.com/en-us/monitor/software/display-pilot-2.html),
  [MonitorControl support](https://github.com/MonitorControl/MonitorControl),
  [BetterDisplay matrix](https://github.com/waydabber/BetterDisplay/wiki/List-of-free-and-Pro-features)

## What the products establish

| Product | Supported first-party claim | Useful lesson and qualification limit |
| --- | --- | --- |
| BetterDisplay 5 | Free mode offers mode/refresh selectors, visual arrangement and standard integrations. Pro adds flexible HiDPI, UI-scale matching, normalized brightness and configuration protection. The application is not open source; free-use terms include non-business conditions. | A readable per-display control surface and explicit matching workflow are relevant. A free CLI does not unlock Pro operations. BetterDisplay 5 requires macOS 26.3+, so its current implementation cannot establish compatibility with this project's macOS 13 baseline. [Feature matrix](https://github.com/waydabber/BetterDisplay/wiki/List-of-free-and-Pro-features) |
| MonitorControl | Free, MIT-licensed source with brightness/volume/contrast sliders and keyboard control. Native Apple media-key capture needs Accessibility permission; ordinary sliders do not. The README distinguishes hardware DDC from software dimming. | The strongest small direct-control reference. Retain an explicit monitor target and control method. Software dimming must not disguise failed DDC. The README reports limited native OSD percentage behavior on Tahoe; a custom confirmed-value display is safer than assuming Apple's HUD proves the value. [README and license](https://github.com/MonitorControl/MonitorControl) |
| Display Pilot 2 | The compatibility page lists RD280UG on macOS 13+; the model specification lists Auto Pivot, MoonHalo, PIP/PBP and Display Pilot 2. | Auto Pivot support is established, but these pages provide neither a public sensor protocol nor latency guarantee. Model-specific controls are a better lesson than cloning every advertised feature. Availability for BenQ does not imply ASUS support or an open-source license. [Software compatibility](https://www.benq.com/en-us/monitor/software/display-pilot-2/spec.html), [model specification](https://www.benq.com/en-us/monitor/programming/rd280ug/spec.html) |
| Lunar | Public documentation covers adaptive brightness, per-monitor limits, app presets and direct controls; published source is only part of the application. | Calibration and clear control bounds are useful ideas. Ambient/location automation would introduce new causes of visible change; it does not solve this deterministic handoff workflow. Do not treat MIT metadata as a security audit. [Repository](https://github.com/alin23/Lunar) |
| macOS | Apple distinguishes text-size controls, Hover Text, screen magnification and lower display resolution. It also warns that scaled modes can affect performance or make windows no longer fit. | These are complementary tools. The documentation does not promise that Accessibility text size enlarges every third-party app toolbar. Keep whole-interface readability previews and avoid claiming universal font scaling or perfect sharpness at arbitrary sizes. [Visibility options](https://support.apple.com/en-ph/guide/mac-help/mchlbc4c53ca/mac), [resolution behavior](https://support.apple.com/guide/mac-help/change-your-displays-resolution-mchl86d72b76/mac) |

BenQ also advertises Focus synchronization, color modes and MoonHalo adjustments. Its FAQ
says HDR can make other color modes unavailable. This supports exposing **why** an option is
unavailable, not adding unsolicited color automation. No reviewed source establishes writable
MoonHalo VCP commands or confirms every advertised software feature on RD280UG.
[Display Pilot 2](https://www.benq.com/en-us/monitor/software/display-pilot-2.html)

## Source features that no longer belong in a “missing” list

Current source already contains explicit-Apply percentage control
([PercentChooser.swift](../../native/menu/PercentChooser.swift)), paired readability sample
windows ([ReadabilitySamples.swift](../../native/menu/ReadabilitySamples.swift)), relative
physical-size proposals ([scaling_choices.py](../../scaling_choices.py)), and live controller
phase presentation. Setup, audio preference/recovery, notifications, diagnostics, timing,
named sizes and timed preview rollback also exist. See [usage](../usage.md).

These are source capabilities, not proof of installation or end-to-end hardware behavior.
The [qualification record](../qualification.md) remains authoritative about tested limits.

## Recommended implementation order

These are engineering judgments for this enrolled pair, not vendor claims.

1. **Finish the precise-control workflow.** The current slider starts at 50 even when a
   prior reading exists. Seed it from typed, dated data for the selected monitor and feature;
   distinguish previous, requested and confirmed values. Keep explicit Apply. Test feature
   switching, missing readings, stale ownership and hardware rounding. Measure DDC latency
   before considering continuous drag writes.
2. **Qualify keyboard and low-vision behavior before adding more panels.** Cover Largest
   text, supported minimum window size, light/dark appearance, focus retention on refresh,
   modal Escape/Apply and VoiceOver values. Prior captures and compilation are not this full
   matrix. Show one current unavailable reason close to the affected action.
3. **Complete visual size calibration.** Samples and relative proposals now exist; join
   them into a guided comparison that preserves a reference monitor and saves a confirmed
   preference by enrolled identity and orientation. Reuse the preview journal and rollback.
   Report a visual preference rather than measured millimeters or guaranteed native sharpness.
4. **Make capability evidence actionable.** Present Available, Unsupported, Temporarily
   unavailable and Not checked distinctly, with observation age and selected target. Reuse
   existing reports; do not poll extra hardware merely to fill a dashboard. An unrelated
   attached screen must remain unmanaged.
5. **Expose the slow phase, then optimize it.** Existing phase status needs an opt-in physical
   rotation timing sample tied to the installed revision. Separate sensor detection, confirmation,
   native layout and audio recovery. Software timestamps cannot measure a sensor event that was
   never observed. Optimize the demonstrated bottleneck without weakening ownership checks.
6. **Later, add local Shortcuts for existing actions.** Status, timed pause and a named preset
   can reuse the controller boundary. Return typed outcomes and explicit targets; cancellation
   of a caller must not falsely claim daemon work was cancelled. Avoid an HTTP listener or new
   global keyboard permissions for the first slice.

Defer virtual displays, arbitrary custom modes, PIP, HDR boosting, automatic color/brightness
adaptation and undocumented vendor writes. No reviewed tool establishes a drop-in, fully
qualified replacement for this pair's two-Mac ownership and audio recovery. Preserve fixed
120 Hz, HDR off, saved readable sizes, local-only runtime and independent enrollment on each
Mac. Open source improves inspectability; it does not itself prove security or compatibility.
