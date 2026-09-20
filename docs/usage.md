# Everyday use and troubleshooting

Change monitor inputs normally. The menu reports the current profile, speaker, rotation,
and recovery state. Physical switching and DDC delays vary; it is not an instantaneous switch.

Overview groups monitor ownership, audio, and recovery. Details keeps the full report.
Displays → Refresh display details reads current and saved modes without changing settings.
It labels logical/framebuffer size, refresh, HiDPI, and HDR preference separately. Refresh
after input or display changes; these are timestamped snapshots, not continuous monitoring.
Pause/Resume is available directly in the window; More controls opens the advanced menu.
Keep/Revert buttons appear only during a size preview.

The status window is resizable. Choose Standard, Large, or Largest status text; this
changes only this app, not monitor resolution or other applications. Long status content
remains scrollable.

## Controls

- **Pause / Resume:** temporarily stop automatic reconciliation, including a timed pause.
- **Speaker preferences:** choose the preferred available output for each profile. External
  headsets remain under your control; manual audio preservation suspends automatic routing.
- **Brightness / volume:** explicit steps apply only to a monitor currently showing this Mac.
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

Configuration and recovery are private state, not repository files. Rollback via `rollback.py BACKUP_TIMESTAMP` restores controller and menu together from
new snapshots. Older backups without menu coverage are rejected; use a compatible installer. See [qualification](qualification.md) for deployment limits. Do not post raw logs,
configurations, diagnostics, or screenshots containing device information in public issues.
