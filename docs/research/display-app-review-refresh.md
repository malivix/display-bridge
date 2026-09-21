# Display app review refresh

Primary sources reopened 2026-09-21. Repository reference: `17dc95b` and the current
[priority plan](../plans/ui-feature-priority-review-2026-09-21.md),
[usage guide](../usage.md), and [qualification record](../qualification.md).
This refresh updates decisions from the [earlier comparison](display-app-comparison-2026-09-21.md);
it does not repeat a feature catalogue. No app was installed, no monitor was changed,
and no competitor's compatibility or accessibility was physically qualified.

## Decision

Keep Display Bridge focused on the two Macs sharing the PG42UQ and RD280UG: clearly
show who owns each screen, preserve readable sizes, recover the intended speaker,
and make rotation predictable. General monitor-control apps provide useful interface
examples, but the sources reviewed do not establish this exact ownership/recovery
policy. Treat a replacement as an integration project, not an immediate simplification.

The highest-value gap is qualification of the existing user journey. Brightness
sliders, audio preferences, size comparison, named presets, rotation and local
status/pause/resume Shortcuts already exist in the repository. The current plan's
delivery sections take precedence over its historical proposals. In particular,
“add Shortcuts” is no longer an accurate next feature; named size-preset preview is
the remaining separate Shortcuts slice. Source delivery is distinct from production
activation and physical qualification. [Current plan](../plans/ui-feature-priority-review-2026-09-21.md)

## What the current alternatives actually offer

| Reference | Useful precedent | Availability and limits |
| --- | --- | --- |
| BetterDisplay | Flexible HiDPI and manual/automatic UI scale matching; display arrangement guides; diagnostics; App Intents. | The current matrix describes v5: flexible HiDPI and UI scale matching are Pro; arrangement and Shortcuts access are free, but Pro operations still need Pro. v5 requires macOS 26.3+. Hardware/connection support varies. Free use has non-business-use conditions. [Official feature matrix](https://github.com/waydabber/BetterDisplay/wiki/List-of-free-and-Pro-features), [license terms](https://github.com/waydabber/BetterDisplay/discussions/739). |
| BenQ Display Pilot 2 | Brightness, volume, color modes and desktop partitions; monitor-series-specific controls and MoonHalo. | Vendor-bundled software, not an established open-source implementation. The current compatibility list includes RD280UG and macOS 13+; it does not cover ASUS PG42UQ. Broad site features should not be assumed to apply to every supported model. [Product](https://www.benq.com/en-us/monitor/software/display-pilot-2.html), [compatibility](https://www.benq.com/en-us/monitor/software/display-pilot-2/spec.html), [bundled status](https://www.benq.com/en-us/news/monitor/best-coding-monitor-for-programmers.html). |
| MonitorControl | Compact direct brightness/volume controls, keyboard shortcuts and native keys. | Free MIT software. Native Apple keys need Accessibility permission; ordinary sliders do not. Hardware DDC excludes specified built-in HDMI paths (all M1, entry-level M2 mini and 2018 Intel mini) and DisplayLink; software dimming is different. Its current README also notes limited native OSD percentage feedback on Tahoe. [Official project, license and compatibility](https://github.com/MonitorControl/MonitorControl). |
| Lunar | Manual controls, monitor automation and discoverable Shortcuts. | Free manual mode currently allows 100 adjustments/day and Shortcuts 100 calls/day; Pro removes those limits. Its public repository is MIT-labelled, but the maintainer explicitly says it cannot build the app because paid source is hidden. Gamma fallback darkens the image without controlling hardware brightness, volume or input. [Product and limits](https://lunar.fyi/), [source/build limitation](https://github.com/alin23/Lunar#building). |

BetterDisplay's public GitHub presence must not be confused with current app source:
the maintainer explicitly says the current implementation is private. This is a
different licensing situation from MonitorControl, and from Lunar's incomplete
public source. A free download, a public issue tracker and an open-source license
are separate facts. [Maintainer explanation](https://github.com/waydabber/BetterDisplay/discussions/4837)

BenQ's own compatibility page contains a broad statement about M-series HDMI and
a narrower M1-specific explanation. Do not turn that into a claim that every M2/M4
HDMI connection fails: the app, Mac, port and transport need individual evidence.
Competitor advertisements do not qualify this project's live transport.
[BenQ compatibility and FAQ](https://www.benq.com/en-us/monitor/software/display-pilot-2/spec.html)

## Readability: extend the existing workflow

Apple provides per-display resolution selection and sometimes additional modes
through Show all resolutions. It warns that scaled modes can affect performance
and that windows can cease to fit; its recovery guidance includes waiting for
automatic reversion or pressing Escape after an unsupported selection.
[Apple resolution guide](https://support.apple.com/en-nz/guide/mac-help/mchl86d72b76/mac)
Apple also documents Larger Text, app text sizing and magnification as separate
ways to improve legibility. [Apple size/accessibility guide](https://support.apple.com/en-ph/guide/mac-help/mchlbc4c53ca/mac)

Recommendation: preserve the saved 120 Hz, HDR-off baseline and use the existing
Compare → preserve reference → Preview → Keep/Revert → optional Save workflow.
Show the effect on both monitors before technical details. The existing physical
size estimate is a proposal, not an optical sharpness measurement or a substitute
for the user's normal viewing distance. Do not add another calibration store when
identity- and orientation-bound presets already remember the desired pair.
[Existing readability controls](../usage.md)

## Useful next results and acceptance

| Order | Observable result | Evidence required |
| --- | --- | --- |
| 1 | Existing controls remain usable with large text and assistive technology. | Complete the open exact-build VoiceOver/high-contrast/dialog matrix. Check spoken target/value/error, Tab order, focus after refresh, Escape, and sticky invalidation when ownership changes. Existing screenshots or accessibility attributes alone do not prove speech. |
| 2 | A two-Mac handoff leaves an understandable desktop and intended sound output. | Record exact installed builds, input transitions, both ownership summaries, chosen profile/output, bounded recovery and headset preservation. A selected output/readback does not prove audible sound. Mac B and competing controllers remain separate checks. |
| 3 | Rotation delay has a measured cause and a targeted improvement. | Use existing sensor-observation, confirmation, layout and readback timing. Opt-in physical samples must record visible completion and exact revision. Preserve missing durations; do not infer a latency guarantee from auto-pivot advertising. |
| 4 | A named readable-size preset can be initiated from Shortcuts safely. | Reuse existing preview and Keep/Revert; validate fresh identity/orientation/ownership at dispatch. Distinguish accepted, pending, completed and failed outcomes. Do not duplicate delivered status/pause/resume work. |
| Research only | RD280UG comfort settings become understandable during pulsing investigation. | Establish narrow firmware/transport-bound read semantics first. Distinguish confirmed, unsupported, unreadable and unverified values. No broad register sweep or undocumented writes. Use OSD guidance if safe inspection cannot be established. |

These are recommendations grounded in the repository's current
[open qualification limits](../qualification.md) and
[delivery record](../plans/ui-feature-priority-review-2026-09-21.md), not a claim of
newly discovered failures. Address one measured user problem at a time.

BenQ specifically advertises a rotating hinge with auto pivot, MoonHalo, Night
Hours Protection and Visual Optimizer on RD280UG. This supports investigating
model-specific settings and an expected auto-rotation experience; it supplies
neither a public sensor API nor a latency guarantee. The health/comfort wording is
vendor marketing, not proof that a setting resolves this user's symptoms.
[RD280UG announcement](https://www.benq.com/en-us/news/monitor/best-coding-monitor-for-programmers.html)

Defer adaptive brightness, app/Focus-triggered color changes, HDR boosting, virtual
displays and PiP: they do not resolve the current ownership, readability or audio
acceptance gaps. Keep physical input switching, software disconnect and network
control outside this milestone, consistent with [project invariants](../../AGENTS.md).
Adding another continuously active monitor writer would require explicit
coexistence qualification; running several apps is not itself a reliability fix.

## Validation of this refresh

Read the project instructions and existing comparison/priority/usage/qualification
documents, reopened official vendor/project/Apple pages, and checked local Markdown
links. Only this report was added. No runtime tests, deployment or hardware tests
were performed; this is research and prioritization evidence.
