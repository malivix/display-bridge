# Everyday use and troubleshooting

Change monitor inputs normally. Display Bridge observes which screens show this Mac and
reconciles its desktop and speakers. Physical switching and DDC delays vary.

Open `~/Applications/Display Auto.app` for the menu and status window. Closing the window
or quitting the menu does not stop the background controller. For initial setup, upgrades
or rotation calibration, use the [installation guide](install.md).

## Find a control

| Location | What you can do |
| --- | --- |
| Overview | See monitor ownership, selected speaker and recovery; use the relevant repair action when available. |
| Details | Select Live status, Setup readiness, Health check, Transition timing, Monitor communication or Support summary. Choose Refresh for a new report. |
| Displays | Refresh the logical-layout schematic and current/saved display modes. |
| Audio | Set speaker preferences for all four profiles, preserve a manual output, resume automatic audio or request repair. |
| Controls | Choose a monitor, read or adjust brightness/volume, manage brightness presets and check preset-command support. |
| Window footer | Pause/Resume, change this app's text size, preview display size, and Keep/Revert an active preview. |

More controls opens the compact menu. Advanced contains rotation, timed pause, audio
preferences, monitor controls and reports. Active preview and restoration actions remain
at the top level. Repair actions explain why they are unavailable and recheck status when
clicked; they do not override manual audio preservation.

## Readable interface and keyboard navigation

Resize the window or choose **Standard**, **Large** or **Largest**. Status text, tabs,
buttons, selectors and preset forms scale together; long content scrolls. This changes
only Display Bridge, not monitor resolution or other apps. Alerts and the menu retain
native system sizing.

With the main window focused, **⌘1–⌘5** select Overview, Details, Displays, Audio and
Controls. **⌘R** refreshes the selected view: Details reruns its selected report, Displays
reads modes, Controls reads the selected local monitor's brightness/volume, and
Overview/Audio reread controller state. These shortcuts change no settings, ignore held-key
repeats, and do not intercept keys in other apps or modal dialogs. No global keyboard
monitoring or Accessibility permission is added.

## Display snapshots

**Displays → Refresh display details** reads modes without changing settings. The schematic
arrow runs from desktop source to mirror on this Mac. Input ownership and macOS rotation
are shown separately. It is not a physical placement diagram or an inspection of another
Mac's desktop. Older helpers without topology information report it unavailable.

The report distinguishes logical resolution, framebuffer dimensions, refresh rate, HiDPI,
HDR preference and saved-mode match. It is a timestamped snapshot, not continuous monitoring
or proof of optical sharpness. A notice above it identifies changed inputs, unavailable
controller status and refresh failures. Failed or malformed refreshes retain the last valid
reading and explicitly mark it as old. Even matching inputs do not prove unchanged size,
rotation or other settings; refresh after changing them.

## Display size and named presets

With both enrolled monitors local, extended and healthy, choose **Preview size…**. Select
a relative size or available named preset, then **Preview selected size**. Selection alone
changes nothing. The comparison shows current/proposed logical and framebuffer dimensions
and an estimated interface-size change for each monitor. It compares each monitor with
itself, without promising equal physical size across monitors or native pixel sharpness.
Escape closes the chooser without applying a preview.

Choose **Keep size** within the 20-second countdown or the controller restores the previous
size. Keep saves only the current orientation. If inputs or orientation change, restoration
waits for the original context. Preserve recovery journals and avoid manual configuration
edits while a preview or restoration is pending.

**Save current as preset…** captures the displayed, qualified fixed-120-Hz/HDR-off HiDPI
pair, not the highlighted proposed choice. It changes no display settings. Names apply
separately to landscape and portrait. Replacement is unchecked by default and must be
explicit. Invalid names stay in the form with a correction message. Names allow up to
48 Unicode code points; combined accents and emoji can consume more than one.

**Remove a saved preset…** shows the name and orientation and requires its explicit Remove
button. It changes saved choices only; current sizes and the other orientation remain.
Concurrent replacement causes removal to fail until you inspect again.

Size presets are limited to 20 name/orientation pairs and stay local to the enrolled setup.
Changed enrollment, missing modes and damaged preset data are reported; the original store
is preserved. Ordinary relative-size previews remain available when only the preset store
is unreadable. Named presets remain unavailable until valid data is restored.

## Brightness and monitor volume

In **Controls**, select PG or BenQ, then read its brightness and volume or use the explicit
±5% steps. The monitor must be showing this Mac. Each adjustment waits for confirmation;
confirmed values appear inline. Equal brightness percentages need not produce equal light
output. Monitor volume does not select the Mac's audio output.

Open **Brightness presets…** for the selected monitor:

- **Save current brightness…** reads its current hardware brightness under a name. It does
  not apply the highlighted preset. Replacing the same name requires the explicit checkbox.
- **Apply selected brightness** checks ownership and the saved hardware range, writes at
  most once, then checks readback. It does not retry automatically.
- **Remove selected preset** deletes that saved entry without accessing monitor hardware.

Saved values are labeled separately from live readings. An empty list offers Save.
Brightness presets belong to a monitor and enrollment, not an orientation, and cannot be
copied between Macs. They are separate from size presets and do not schedule brightness
changes or change speaker volume.

The menu validates brightness/volume responses against the requested monitor and feature.
A failed or malformed response retains the previous reading, explicitly marked not refreshed;
no adjustment is automatically retried. Use Read brightness and volume to inspect again.

### Preset support after upgrades

Controls shows the last support check and **Check preset support**. A read-only probe runs
once at menu launch. Unsupported brightness presets and named size-preset save/removal
are disabled; ordinary size preview and recovery remain independent. Update the menu and
controller together, then recheck. Each newer preset command also probes support before
use, with a deadline of five seconds. This verifies CLI support, not daemon/helper integrity.

## Speakers, pause and recovery

Choose preferred available speakers per profile in Audio. Automatic routing preserves an
external headset; **Preserve output for 30 minutes** suspends automatic routing while you
use a manual selection. Resume automatic audio when wanted. Selection readback alone does
not establish audible sound—listen to verify a repair.

Pause temporarily stops automatic reconciliation; timed pause is also available in Advanced.
The Overview recovery section distinguishes pending, paused, ownership-held and exhausted
work. It shows the trigger, last error and retry eligibility without showing a current
countdown from stale status. Normal switching does not offer repeated repair.

A command opens the status window with its active phase, elapsed phase time and deadline.
Preset compatibility checks have a five-second phase before the separate 45-second command
phase; a rejected check never advances to execution. A saved request is
not confirmation that work finished. The latest settings request can be acknowledged,
applying, deferred, verified or failed. The last 20 observed requests persist locally; newer
requests supersede unfinished older settings work. A command timeout does not prove that
no changes occurred or cancel work already queued in the controller. Check status before
retrying.

Persistent-failure notifications suppress repeats for the same incident until recovery;
distinct failures may alert separately. Clicking opens the status window. An outdated
repair notification opens status instead of issuing repair.

## Setup checks, reports and privacy

**Details → Setup readiness → Refresh** inspects this Mac's configured inputs, stored
landscape/portrait profiles, sensor mapping, controller health, installed files and monitor
responses. Missing facts from older controllers are unreported rather than assumed ready.
This is a checklist; enrollment and orientation capture still use the installer.

Setup readiness also recognizes standard BetterDisplay, MonitorControl, Lunar and Display
Pilot bundle names among running apps. Presence does not prove a conflict; review overlapping
settings manually. Display Bridge never stops another tool. Renamed bundles, background
services and command-line tools are outside this check; an empty list does not prove exclusivity.

Details reports remain timestamped, selectable snapshots until refreshed or replaced.
Live status updates when selected. Transition timing shows median, nearest-rank p95, slowest
value and each phase's own sample count. Failed attempts can include retries and are not
counts of failed physical switches. Small samples and application-only timing cannot establish
overall physical switching performance; missing metrics remain unavailable.

Health checks inspect menu heartbeat/version and saved preset stores. A closed menu is
informational because the controller can continue. Valid stored data does not establish
current mode availability. An unreadable controls file disables setting changes rather than
showing default preferences; health, diagnostics and preview reversion remain available.
A missing optional controls file uses normal defaults. The menu never resets damaged files.

**Support summary** produces an allowlisted report excluding raw logs/errors, names,
identifiers, paths and exact timestamps. Review before sharing, then choose **Copy reviewed summary**. This copies only the shown
support-summary body, excluding the view timestamp; it does not upload it. Copy is disabled
until a summary is displayed and while refreshing. Changing reports or starting a summary
refresh clears the copy target. **Diagnostics** saves a
separate private local artifact containing device and configuration information. Neither
uploads anything. Do not post raw configurations, logs, diagnostic bundles or screenshots
with device information in public issues. See [security and privacy](../SECURITY.md).

## When something is wrong

| Symptom | Next step |
| --- | --- |
| Waiting for monitor response or unknown input | Let switching settle; verify cables, selected inputs and DDC availability, then check health. No valid read means no layout change. |
| Inactive setup | Return to the enrolled pair. Extra or replacement monitors are intentionally unmanaged. |
| Recovery exhausted | Keep intended inputs stable, check health, then use the appropriate explicit repair action. |
| Selected sound output is silent | Confirm the visible monitor, resume automatic audio if wanted, then Repair audio and listen. |
| Preview awaiting restoration | Return both inputs and BenQ orientation to their original state. Preserve the journal. |
| Saved settings need attention | Save private diagnostics and restore a known-good local backup. Deleting a damaged journal is not a repair. |
| Preset controls unavailable after upgrade | Update menu/controller together, then use Controls → Check preset support. |
| Display snapshot marked old | Refresh display details after switching/recovery settles; the retained reading is for comparison. |
| Menu unavailable | Open `~/Applications/Display Auto.app`; inspect controller status separately. |

Rollback with `python3 rollback.py BACKUP_TIMESTAMP` from the repository restores controller
and menu together from newer snapshots. Older backups lacking menu coverage are rejected.
Read [installation](install.md) and [qualification](qualification.md) before deployment or rollback.

## Terminal reference

Use the installed launcher so commands run with the installation's selected Python:

```sh
~/.local/bin/display-auto.sh status
~/.local/bin/display-auto.sh doctor
~/.local/bin/display-auto.sh pause-for --minutes 15
~/.local/bin/display-auto.sh resume
~/.local/bin/display-auto.sh support-summary
~/.local/bin/display-auto.sh history
~/.local/bin/display-auto.sh --help
```

`status` reads the latest heartbeat; `doctor` makes fresh read-only checks. `check` exposes
raw display/audio inventory and identifiers for local debugging. Nothing is uploaded.

For size presets, `preset-save --preset Reading` saves current sizes; add `--replace` only
to replace that name in the current orientation. `preview-options` lists availability and
fingerprints. Pass the inspected layout's `fingerprint` to
`preview-start --preset Reading --fingerprint VALUE`; the normal Keep/Revert flow applies.
For removal, use `preset-remove --preset Reading --orientation 0 --fingerprint VALUE`
(or orientation `90`). Removal needs the entry's `revision`, not the preview-layout fingerprint.
Append these arguments to `~/.local/bin/display-auto.sh`.

For brightness:

```sh
~/.local/bin/display-auto.sh brightness-save --monitor benq --preset Reading
~/.local/bin/display-auto.sh brightness-list --monitor benq
```

Use `--replace` explicitly to replace an existing name for that monitor. Pass the list entry's
`revision` to `brightness-apply` or `brightness-remove` with `--fingerprint VALUE`, together
with `--monitor benq --preset Reading`. List and removal access no monitor hardware.
