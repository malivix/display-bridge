# Product lessons for Display Bridge

Researched 2026-09-21 against primary sources. Read alongside the existing
[comparison](feature-comparison-2026-09-21.md) and
[delivery plan](../plans/ui-feature-review-2026-09-21.md). This note refines product choices;
it is not another implementation backlog. Source baseline inspected: `8971f96`.
No competing application was installed and no hardware commands were run.

## What the alternatives establish

| Product | Relevant advertised capability | License, scope and lesson |
| --- | --- | --- |
| BetterDisplay 5 | Mode/refresh selection, arrangement guides, diagnostics, DDC capability discovery and basic integration are free features. Flexible HiDPI, physical UI-scale matching, and advanced layout protection are Pro. | Closed source; its matrix conditions free use on non-business license terms. Learn from an explicit current-versus-requested size comparison and understandable layout protection. Do not assume that a free CLI makes Pro operations free. [Official feature matrix](https://github.com/waydabber/BetterDisplay/wiki/List-of-free-and-Pro-features) |
| BenQ Display Pilot 2 | Model-specific quick controls, Focus integration and MoonHalo settings. RD280UG is listed for macOS 13 onward; the RD280UG specification explicitly says Auto Pivot is supported. | Vendor download availability is not an open-source license; none was established here. ASUS support is not established. Model Auto Pivot support does not document its sensor protocol, connection prerequisites or latency. Use explicit capability and calibration states, not generic controls on every screen. [Product](https://www.benq.com/en-us/monitor/software/display-pilot-2.html), [compatibility](https://www.benq.com/en-us/monitor/software/display-pilot-2/spec.html), [RD280UG specification](https://www.benq.com/en-us/monitor/programming/rd280ug/spec.html) |
| MonitorControl | Compact brightness/volume/contrast controls, keyboard integration, OSD and brightness synchronization. | Free, MIT source. Native Apple media-key interception needs Accessibility permission; ordinary menu controls can skip it. Specific built-in HDMI paths, including entry-level M2 Mac mini, lack hardware DDC support in this app. Borrow direct targeting and keyboard usability; avoid making software dimming an invisible substitute for a failed hardware write. [README](https://github.com/MonitorControl/MonitorControl), [license](https://github.com/MonitorControl/MonitorControl/blob/main/License.txt) |
| Lunar | Adaptive brightness mappings learned from manual correction, plus sensor/location/schedule modes. | MIT repository source and the distributed free/Pro product are distinct: free brightness/contrast adjustments have a daily limit. Location mode documents an IP-geolocation fallback. Learn from visual calibration rather than equating two percentage values; ambient automation and network sensor integration do not fit the current deterministic, local-only scope. [Product behavior](https://lunar.fyi/pro), [source license](https://github.com/alin23/Lunar/blob/master/LICENSE) |

These sources do not establish a drop-in replacement for this project's input-ownership,
mirroring, audio-recovery and rotation workflow. The safest comparison is by capability,
not by counting checkmarks. Open source allows inspection; it does not certify release
binaries, dependency behavior or hardware compatibility. Any reused code needs license
attribution and a pinned-source review. BenQ's broad HDMI FAQ differs from the narrower
MonitorControl exceptions and BetterDisplay support claims; exact Mac model, port and
adapter matter. The chip names alone cannot settle compatibility.

## Improvements with the highest practical return

These are engineering recommendations inferred from the user's workflow and the existing
source, not vendor promises. Work through the current delivery plan sequentially.

1. **Make availability and the next action obvious.** Put installed app/controller agreement,
   ownership freshness and the blocking reason together. A fresh unknown input must remain
   unknown, with a cable/input check as the next action. Do not offer enrollment as an
   automatic remedy for transient DDC failure. Existing recovery and enrollment-review
   commands should be discoverable by their task names, with no need to understand the
   Details report selector. Acceptance: keyboard-only users can find the safe next step in
   healthy, stale, unsupported-controller and unknown-input scenarios at Largest text.
2. **Finish independent guided setup before adding more settings.** The read-only CLI review
   now exists; mutable activation remains a separate transaction. Show host role, local input
   map and fixed-120/HDR-off policy before capture. Revalidate immediately before activation,
   preserve backups and block when a preview/recovery is pending. Extra or replacement
   displays stay unmanaged. Acceptance includes interrupted setup and an older controller;
   successful source tests must not imply Mac B physical qualification.
3. **Explain rotation delay before reducing safety margins.** Show sensor observation age,
   candidate orientation, debounce/ownership wait and last applied orientation. Separate
   time until the first valid sensor observation from layout and audio work. Measure an
   opt-in turn in each direction before optimizing polling. Acceptance: a stale sensor never
   triggers rotation; remote ownership cancels or defers it; reported timing names only phases
   actually measured. Auto Pivot marketing is not evidence for a faster safe polling rate.
4. **Help choose readable matching sizes.** Build on existing orientation-specific presets
   and 20/40-second previews with a visual size comparison and a user-calibrated match.
   Label panel-dimension estimates as approximate; viewing distance also affects comfort.
   Keep current known-good sizes one action away. Acceptance: both orientations preserve the
   intended physical relationship, unavailable modes are rejected, rollback works, and the
   user judges readability. Arbitrary HiDPI output cannot be advertised as native-pixel
   sharpness, and macOS accessibility text size does not enlarge every Chrome control.
5. **Make sound verification distinct from routing status.** Existing profile preferences,
   manual preservation and repair are the baseline. A small explicit listening check could
   explain selected output versus confirmed audible output, play a bounded quiet sample,
   then record the user's response locally. It must never run unsolicited during switching
   or overwrite a manually selected headset. Acceptance: timeout/error is not success;
   repairs preserve the original preference and never loop indefinitely.
6. **Add a brightness slider only after measuring command latency.** Show the selected
   monitor, desired value, confirmed value and reading age. Coalesce a drag to the latest
   intent through the controller; discard queued intent when ownership changes. Existing
   buttons/presets remain usable. Acceptance: dragging cannot flood DDC or apply a stale
   value to a now-remote screen. Do not promise smooth physical transitions before testing.

Recent attempts, timing summaries, failure notifications, profile audio preferences,
brightness presets, size previews and local diagnostics already exist in source. Their
remaining work is usability and qualification, not duplicate implementation. The
[qualification record](../qualification.md) still distinguishes old physical observations,
installed revisions, source tests and untested concurrent-Mac behavior.

## Defer deliberately

Shortcuts/App Intents can later expose the existing guarded commands without a server;
start read-only and use explicit targets for mutations. Window arrangement, PIP/capture,
virtual displays, HDR boosting, arbitrary color filters and automatic Focus/color changes
have less direct value here. Input switching, software disconnection and network control
conflict with current ownership and locality rules. MoonHalo writes need a documented or
carefully qualified model-specific protocol; product screenshots do not justify VCP probing.

For the earlier flicker concern, retain the user's fixed-refresh/HDR-off policy and avoid
reintroducing adaptive behavior merely because another app offers it. A software mode
readback does not prove absence of flicker, improved text sharpness or audibility. New
physical claims require an opt-in test tied to the exact installed revision.
