# Display app comparison and remaining product priorities

Researched 2026-09-21 against primary project and vendor pages. Repository baseline:
`3d94e42`, plus source inspection of the current working tree. This is a research
report, not a hardware compatibility test, security certification, or installation.
Recommendations below are engineering judgments; linked upstream descriptions are
evidence of advertised behavior, not proof that another app works on this monitor pair.

## Current alternatives

| Application | Useful reference | Availability and limits |
| --- | --- | --- |
| BetterDisplay | Flexible HiDPI selection, automatic UI scale matching, visual arrangement guides, configuration protection and detailed connection diagnostics. | Current app source is private; an early MIT version is not the current product. Free features have non-business-use conditions; advanced scaling and synchronization require Pro. Release choice depends on macOS. Native connection, GPU limits and DDC transport still matter. [Product](https://github.com/waydabber/BetterDisplay), [feature matrix](https://github.com/waydabber/BetterDisplay/wiki/List-of-free-and-Pro-features), [maintainer's source explanation](https://github.com/waydabber/BetterDisplay/discussions/4837). |
| BenQ Display Pilot 2 | Model-specific presentation of monitor controls; RD-series MoonHalo, night protection, application color modes, software dimming and desktop partitioning. | Vendor-distributed bundled software; no current open-source app implementation/license was established by this review. The compatibility list explicitly includes RD280UG for macOS 13+. It is not a cross-vendor replacement for PG42UQ. [Supported models](https://www.benq.com/en-us/monitor/software/display-pilot-2/spec.html), [RD280UG features](https://www.benq.com/en-us/monitor/programming/rd280ug.html). |
| MonitorControl | Direct brightness/volume sliders, keyboard interaction and clear per-display controls. | Free MIT software. DDC compatibility depends on connection: documented exceptions include all M1 built-in HDMI ports and entry-level M2 Mac mini HDMI; DisplayLink docks do not carry its hardware DDC. Accessibility permission is needed for native media keys, not ordinary slider use. Its scope is brightness/volume, not ownership-aware desktop/audio recovery. [Project and compatibility](https://github.com/MonitorControl/MonitorControl). |
| Lunar | Monitor-specific ranges, quick actions, manual control and local Shortcuts. | Free and paid features; current site lists daily free manual/Shortcuts limits. The public repository is MIT-labelled but explicitly cannot build the complete app because paid code is hidden. Do not describe the entire shipped product as a reproducibly buildable open-source replacement. [Product](https://lunar.fyi/), [source/build limitation](https://github.com/alin23/Lunar). |
| displayplacer | Inspect and reproduce a whole layout through a small CLI. | MIT open source. Its own documentation warns that persistent IDs can change, available modes depend on current rotation, and some listed modes fall back to others. It does not supply the project's ownership, audio or recovery policy. [Project](https://github.com/jakehilborn/displayplacer). |

The most relevant additional discovery is [Didact, formerly BtnQ](https://github.com/gingerbeardman/Didact),
an MIT menu app initially built for RD280UG. It ships a monitor profile and targets
Apple silicon/macOS 13+ through private IOKit/CoreDisplay access. Its documented
profile format distinguishes unreadable values, unverified writes and multiplexed
registers: a read may identify only the last-touched channel. This is useful evidence
for future protocol investigation, not permission to treat a remembered setting as
hardware confirmation. This review did not execute or security-audit its code.

Open source enables inspection but does not establish safe behavior or compatibility.
None of these pages establishes a ready-made equivalent to Display Bridge's exact
two-host ownership policy, enrolled identities and HDMI audio recovery. Replacing
the controller with a general display app would require a separate integration and
physical qualification project.

## BenQ rotation and connection evidence

BenQ's [RD280UG launch announcement](https://www.benq.com/en-us/news/monitor/best-coding-monitor-for-programmers.html)
explicitly describes a rotating hinge with auto pivot. That supports the hardware
feature's existence; it does not document a public sensor API, polling interval, or
guaranteed macOS latency. Display Bridge already has calibrated sensor rotation.
The open issue is measuring and improving that path, not adding rotation again.

BenQ's [connection troubleshooting](https://www.benq.com/en-sg/support/downloads-faq/faq/product/application/monitor-faq-kn-00078.html)
recommends direct USB-C or USB-C-to-DisplayPort for some M-series HDMI limitations
and enabled DDC/CI. Its broader compatibility-page HDMI language should not be
generalized into a claim that every M2/M4 HDMI path fails. Model, port and transport
readbacks remain the deciding evidence. No connection changes were made for this review.

## Already implemented: avoid rebuilding these

The [README](../../README.md), [usage guide](../usage.md),
[current priority plan](../plans/ui-feature-priority-review-2026-09-21.md), and
`native/menu/SizeChooser.swift` / `native/menu/PresetWindows.swift` establish these
current source features:

- Five-tab status/control UI, scalable app text, local keyboard navigation, timed
  pause and keyboard help.
- Explicit target and percentage entry for brightness/volume, dated observations,
  capability explanations, named brightness presets and guarded submission.
- Readability comparison windows, reference-preserving size choices, model-based
  physical-size estimates, reversible previews and orientation-bound named presets.
- Per-profile speaker preference, temporary manual preservation, bounded recovery,
  listening checks and persistent-failure notification.
- Local diagnostics, reviewed support summary, transition history and phase timing
  with sample counts, median and p95; rotation observation/readback ages.
- Enrollment-bound changes, unknown-input deferral, setup review and rollback.

The source also has sticky eligibility loss in several modal dialogs: a later
apparently healthy poll does not silently reactivate a stale proposal. These are
real implementations, not proof of VoiceOver speech, optical quality, audibility,
physical rotation speed or Mac B behavior. See [qualification](../qualification.md).

## Five priorities with measurable acceptance

These extend the current plan rather than replace it with a feature-count contest.
Complete one slice at a time; keep fixed 120 Hz, HDR off and the saved readable sizes.

| Priority | Proposed work and useful precedent | Acceptance |
| --- | --- | --- |
| 1 — qualify and fix | Finish accessible operation of existing flows. Borrow the direct, target-focused interaction of MonitorControl rather than adding more panels. | Exact-build demo covers ready, stale, unknown, paused, recovering and unsupported states at Largest/minimum size in light/dark. Tab order, focus retention during refresh, Escape and modal invalidation are checked. VoiceOver names/values and speech are recorded separately; every discovered failure gets a focused fix. No accidental hardware dispatch in the demo. |
| 2 — improve reliability | Make rotation delay actionable with the existing phase evidence. Display Pilot establishes the expected auto-pivot experience but provides no latency guarantee. | Existing reports identify sensor observation, confirmation, layout and readback separately. Missing durations remain missing. An opt-in physical sample records exact installed revision and user-visible completion; several samples are needed before a median/tail claim. Optimize only the measured slow phase; no extra polling merely to animate UI. |
| 3 — finish readability workflow | BetterDisplay's scale matching is a useful reference; finish our existing compare → reference → preview → Keep → optional save sequence. | Current/proposed dimensions and estimate appear for ordinary and saved choices. Reference stays unchanged. Orientation/readiness changes invalidate open proposals. Keep/Revert and restart rollback are tested. Saving and reopening preserves the qualified pair. Estimates never claim measured sharpness. Do not create a second calibration store without a demonstrated need. |
| 4 — add convenience | Local Shortcuts actions for status, timed pause/resume and a named size preset, using the existing command boundary. Lunar and BetterDisplay demonstrate discoverability benefits. | Typed target/name inputs; explicit error versus accepted/pending/completed outcomes; stale ownership rejects mutations. Every mutation passes the same controller gates. No network listener or arbitrary shell command field. CLI timeout is not described as cancellation of an already accepted request. App-local keyboard help remains distinct from macOS Shortcuts. |
| 5 — investigate before exposing | An explicit, read-only RD280UG comfort-settings inspection could help investigate pulsing: show which settings are known, unsupported, unverified or unreadable. Display Pilot/Didact provide research leads. | First produce a firmware/transport-bound protocol assessment with provenance. No broad register sweep or writes in ordinary tests. Multiplexed/remembered values cannot become confirmed observations. Only after authorized hardware qualification should a narrow control be proposed, with enrollment/ownership guards and restoration requirements. MoonHalo or visual-optimizer controls are not ready to ship based on the current evidence. |

Priority 5 is a research gate, not a commitment to implement undocumented controls.
If its protocol cannot be verified, retain concise monitor-OSD guidance instead.

## Defer and maintain

Adaptive brightness, application-triggered color changes and synchronized dragging
would introduce competing automatic behavior and can complicate pulsing diagnosis.
Virtual displays, HDR boosting, sharpening filters and PiP do not directly improve
the currently accepted readable desktop. Do not add physical input switching,
software disconnect or network control: these conflict with this project's scope.

The continuing maintenance work is qualification and cohesive boundaries: move demo
fixtures out of orchestration when touching that code, keep reports concise, and
keep the newest plan as the documentation entry point. A large report catalogue is
not evidence that the installed app is current. Source release, local package
verification and physical qualification must remain separately stated.

No tests, installation, monitor writes or user-data collection were performed for
this research-only report.
