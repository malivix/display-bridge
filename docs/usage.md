# Everyday use and troubleshooting

Change monitor inputs normally. The menu reports the current profile, speaker, rotation,
and recovery state. Physical switching and DDC delays vary; it is not an instantaneous switch.

Overview groups monitor ownership, audio, and recovery. Details keeps the full report.
Displays → Refresh display details reads current and saved modes without changing settings.
It labels logical/framebuffer size, refresh, HiDPI, and HDR preference separately. Refresh
after input or display changes; these are timestamped snapshots, not continuous monitoring.
Audio shows the selected output and all four profile preferences. It also provides manual
output preservation, resume, and repair, with an explanation when repair is unavailable.
Pause/Resume is available directly in the window. More controls opens the compact menu:
status, monitor ownership, speaker, Open Display Bridge, Pause/Resume, and Quit.
Advanced contains rotation, timed pause, audio preferences, monitor controls and reports.
Active preview Keep/Revert and restoration retry remain at the top level.
Keep/Revert buttons appear only during a size preview. The Recovery group explains pending,
paused, ownership-held and exhausted work, including the trigger, last error and reported
retry eligibility. Stale status never presents a current retry countdown.

The status window is resizable. Choose Standard, Large, or Largest interface size. Window tabs,
buttons, speaker selectors and status text enlarge together; this changes only this app,
not monitor resolution or other applications. Long content remains scrollable. Separate
alerts and the menu still use their native system sizing.

## Controls

- **Pause / Resume:** temporarily stop automatic reconciliation, including a timed pause.
- **Speaker preferences:** choose the preferred available output for each profile. External
  headsets remain under your control; manual audio preservation suspends automatic routing.
- **Brightness / volume:** the Controls tab offers monitor selection, readback, and explicit
  steps for a monitor currently showing this Mac. Confirmed values appear inline. Buttons
  explain unavailable states and wait for each command before accepting another adjustment.
- **Preview display size:** available when both displays are local and healthy. Keep within
  the countdown or the controller restores the previous size. This saves only the current
  orientation. If inputs or orientation change, restoration waits for the original context.
- **Check health:** read-only inspection. **Save diagnostics:** writes a private local report.
- **Repair audio / Retry size restoration:** explicit retry after the cause of failure is resolved.

The status window opens when a command starts and shows its operation and elapsed time.
A saved request is not confirmation that the controller finished applying it. The window
shows acknowledgement, applying, deferred, verified, or failed for the latest settings
request. Preference acknowledgement does not claim physical effects or audible sound.
Results survive a menu restart; the last 20 observed requests are retained locally.
A newer request supersedes unfinished older settings work. Last-known
labels and report age identify details that may be stale. Clicking a failure notification
opens the status window. Repeated alerts for the same incident are suppressed until
recovery; distinct failure categories can alert separately. An outdated repair notification
opens status instead of issuing repair.

Closing the menu does not stop the controller. A command timeout is not proof that no changes
occurred; check status before retrying. Avoid manual configuration edits during a preview.

## Useful commands

All commands below use the installed controller:

```sh
python3 ~/.local/bin/display-auto.py status
python3 ~/.local/bin/display-auto.py doctor
python3 ~/.local/bin/display-auto.py pause-for --minutes 15
python3 ~/.local/bin/display-auto.py resume
python3 ~/.local/bin/display-auto.py support-summary
python3 ~/.local/bin/display-auto.py history
python3 ~/.local/bin/display-auto.py --help
```

`status` reads the latest heartbeat; `doctor` performs fresh read-only checks. `check` exposes
raw display/audio inventory and identifiers for local debugging. None uploads information.

## When something is wrong

| Symptom | Next step |
| --- | --- |
| Waiting for monitor response | Let input switching settle, verify cables/input selection and DDC availability, then run `doctor`. No valid read means no layout change. |
| Inactive setup | Return to the enrolled pair. Extra or replacement monitors are intentionally unmanaged. |
| Recovery exhausted | Keep the intended inputs stable, check health, then use the appropriate explicit repair action. |
| Sound selected but silent | Confirm the visible monitor, resume automatic audio if wanted, and use Repair audio. Listen to verify success. |
| Preview awaiting restoration | Return both inputs and BenQ orientation to their original state. Preserve its journal. |
| Saved settings need attention | Save private diagnostics and restore a known-good local backup. Deleting a damaged journal is not a repair. |
| Menu unavailable | Open `~/Applications/Display Auto.app`; inspect controller status separately. |

More controls → Preview support summary produces a small allowlisted report for review.
It excludes raw logs, error text, device/audio names, identifiers, paths, and exact timestamps.
Copy only the reviewed summary when sharing; private diagnostics remain a different artifact.

Configuration and recovery are private state, not repository files. Rollback via `rollback.py BACKUP_TIMESTAMP` restores controller and menu together from
new snapshots. Older backups without menu coverage are rejected; use a compatible installer. See [qualification](qualification.md) for deployment limits. Do not post raw logs,
configurations, diagnostics, or screenshots containing device information in public issues.

## Named size presets

In the window, choose **Preview size…**. Select a relative size or an available named
preset, then **Preview selected size**. The comparison lists both logical resolutions and
explains unavailable presets. **Save current as preset…** saves the sizes currently displayed,
not the highlighted proposed choice. Replacement requires checking the explicit option.

With both enrolled monitors showing this Mac, extended and stable, you can also save the
currently qualified fixed-120-Hz/HDR-off HiDPI pair from Terminal:

```sh
display-auto.sh preset-save --preset Reading
display-auto.sh preview-options
display-auto.sh preview-start --preset Reading
```

Saving changes no display settings. Names apply separately to portrait and landscape.
Use `preset-save --preset Reading --replace` to deliberately update an existing name in
this orientation. The chooser report includes preset availability, reasons, and fingerprints;
pass its `--fingerprint` to `preview-start` when recalling a previously inspected choice.
The normal timed Keep/Revert flow applies. Presets are limited to 20 name/orientation pairs,
stay local to this enrollment, and never silently substitute another mode. Changed enrollment
or damaged preset data is reported and preserved. Ordinary relative-size previews remain
available if only the preset store is unreadable; saving/recalling named presets stays blocked
until valid data for this enrollment is restored. The native chooser uses the same
preview transaction and fresh fingerprint checks as the CLI.

To free a preset slot, open **Preview size… → Remove a saved preset…**, select the name
and orientation, and confirm **Remove selected preset**. This changes saved choices only,
not your current monitor sizes. The other orientation is preserved. If the preset changed
while the dialog was open, removal fails and you must inspect it again.

For CLI removal, pass the selected preset's `revision` from `preview-options` as
`--fingerprint`, plus `--preset NAME --orientation 0` (landscape) or `90` (portrait), to
`preset-remove`. This revision is distinct from the proposed-layout fingerprint for preview.

The **Details** tab offers Live status, Health check, Transition timing, Monitor communication,
and Support summary. Select a report and choose **Refresh**. Read-only reports remain as
timestamped, selectable snapshots until refreshed or replaced; they are not polled in the
background. Live status continues updating when selected. Support summaries still require
review before sharing; no report is uploaded automatically.

Transition timing shows median, nearest-rank p95, slowest value, and each phase's own sample
count. Profiles with only failed attempts remain visible. Failed attempts may include retries;
they are not a count of failed physical switches. Small samples and application-only timing
cannot establish overall physical switching performance. Missing older fields stay unavailable.

Health checks also inspect the menu heartbeat/version and any saved preset store. A closed
menu is informational because the controller can continue without it. Stale/mismatched menu
state and unusable preset data include corrective guidance; no file is reset. A valid preset
store does not establish current mode availability—that is checked by the size chooser.

If the menu cannot read an existing controls file, it marks preferences unavailable and
disables setting changes instead of showing default speaker choices. Health, diagnostics,
and preview reversion remain available. A missing optional controls file still uses the
normal defaults. Restore valid settings through the documented recovery process; the menu
never resets the file itself.

The Overview recovery section offers the relevant action beside its explanation:
Check health for unavailable state, Retry size restoration for a repairable preview,
or Repair audio after exhausted recovery when policy permits. Normal switching does
not offer repeated repair. Actions recheck current status when clicked; if it changed,
review the refreshed action before retrying. Manual audio preservation is not overridden.

Preview size opens a resizable comparison window. Selecting a choice updates current
and proposed logical dimensions, framebuffer dimensions and the estimated interface-size
change for each monitor. The estimate compares that monitor with itself; it does not
promise matching physical size across monitors or native pixel sharpness. The window's
text, selector and buttons follow your interface size. Escape cancels without applying.
Unavailable named presets include their orientation. The existing 20-second Keep/Revert
transaction still controls any preview; opening or selecting a choice changes nothing.

Save and Remove preset forms also follow the selected interface size. Invalid names stay
in the Save form with an inline correction message. Names use the backend's limit of
48 Unicode code points; combined accents or emoji may use more than one. Replacement is
unchecked by default. Remove displays the name and orientation and requires its explicit
button; keyboard selection alone does not remove a preset. Backend errors such as a
concurrent replacement or changed ownership still reject the submitted command.

For setup review, open Details → Setup readiness → Refresh. This runs the existing
read-only health inspection once. Enrollment findings show this Mac's configured input
map and whether matching landscape/portrait profiles and a sensor mapping are stored.
The remaining checks cover controller health, installed files and monitor responses.
Missing facts from an older controller are explicitly unreported, not assumed ready.
This is an inspection checklist; enrollment and orientation capture still use the installer.

Setup readiness also lists recognized running display apps when refreshed in the menu
window. It recognizes standard BetterDisplay, MonitorControl, Lunar and Display Pilot
bundle names. Presence alone does not establish a conflict. Review overlapping settings
manually if needed; the app never stops another tool. Renamed bundles, background services
and command-line tools are outside this check, so an empty list does not prove exclusivity.

With the main Display Bridge window focused, use ⌘1 for Overview, ⌘2 for Details,
⌘3 for Displays, ⌘4 for Audio and ⌘5 for Controls. ⌘R refreshes the current view:
Details reruns its selected report, Displays reads mode details, Controls reads the
selected local monitor's brightness/volume, and Overview/Audio reread controller state.
These shortcuts do not change display settings. Held-key repeats are ignored, and the
shortcuts do not apply inside modal preview/preset dialogs or other applications.
No global keyboard monitoring or Accessibility permission is added.
