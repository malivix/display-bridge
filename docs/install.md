# Installation

## Prerequisites

- Apple-silicon Mac running macOS 13 or newer, with Python 3.10+ available as `python3`.
- Xcode Command Line Tools. Run `xcode-select --install` if needed; finish the Apple installer.
- PG42UQ and RD280UG connected and online, DDC/CI enabled where the monitor exposes it.
- Exactly the two external displays in extended mode, both showing the Mac being configured.
- Select fixed 120 Hz and HDR off in macOS Displays settings, then choose readable sizes.
  Existing custom HiDPI modes must already be available; this project does not create them.
  Capture checks current mode metadata for 2× HiDPI, VRR/ProMotion off and HDR off. A numeric
  120 Hz reading alone is insufficient; unavailable metadata blocks capture without guessing.

Check `python3 --version` and `xcrun --sdk macosx --show-sdk-path` before installation.
Connection and firmware compatibility must be qualified on your setup.

## Check software prerequisites first

From the checkout, run:

```sh
python3 install.py A --preflight
```

Use `B` when preparing Mac B. This reports platform/Python requirements, required source
entry points, Xcode tool discovery and known service namespace conflicts. It creates no
installation state, builds nothing, changes no services and does not contact monitors.
Exit status is 0 when these software checks pass and 1 when they need attention.
Preflight cannot be combined with either capture option.

`prerequisites-ready` is not approval to deploy: input ownership, configuration, pending
recovery, permissions and physical behavior remain unqualified. Continue with the setup
requirements below; the actual installer still performs its own live checks.

## Inspect the latest installation attempt

```sh
python3 install.py A --status
```

Use `B` for the other host. This reads private `install-progress.json` without creating state,
installing or contacting monitors. Exit 0 means a valid report was read, including a failed or
incomplete attempt; inspect its `status`, `phase` and `recovery` fields for the outcome. Exit 1
means no valid report exists for that host. The report contains local process/timing metadata;
keep it private unless reviewed.

Reporting begins after installation locks and initial guards succeed. An earlier failure can
leave the previous attempt's record unchanged; compare attempt IDs and start times. A stored
`running` record is not proof the installer still runs. `process_observation` reports only
whether that PID exists, without proving its identity. Forced termination may leave an unfinished
phase. `completed-unverified` recovery means the rollback/restart commands returned, not that
hardware was physically qualified. Status never resumes installation or retries recovery.

## Input mapping

| Monitor | Mac A | Mac B |
| --- | --- | --- |
| PG42UQ | HDMI 1, DDC value 17 | HDMI 2, DDC value 18 |
| BenQ RD280UG | DDC value 19 | DDC value 15 |

The two roles must use this mapping. Other inputs remain unknown; automation does not guess
or switch a physical input. The saved pair is bound to locally discovered identities.
Extra or replacement displays make automation idle until the setup is deliberately recaptured.

## Review a prospective enrollment

With compatible helpers already built and available, run the checkout's read-only review:

```sh
python3 display-auto.py capture-review --host A
```

Use `B` for the other host. This can inspect a first enrollment without valid saved config,
but it does not build missing helpers or install anything. It checks the exact supported
pair, fixed-120-Hz/HDR-off HiDPI modes, audio discovery and two local input readings, then
rechecks mode metadata. The summary omits device IDs and helper paths. Configuration and
services are unchanged; maintenance/DDC coordination files may be created.

`review-ready` is a snapshot, not enrollment approval or physical qualification. Normal
capture re-inspects hardware before saving. The independent graphical setup interface is described below; its software review is
separate from this live hardware enrollment review.

## Optional graphical setup

From a clean, trusted Git checkout on the Mac being configured, run:

```sh
python3 setup_gui.py
```

This builds and opens a separate setup app. It does not install automatically. Choose Mac A or
Mac B, run **Review software**, prepare both monitors as described above and check **Both
monitors are prepared**, then choose **Install / upgrade**. Changing roles clears the previous
review and preparation confirmation. The regular upgrade path preserves existing enrollment;
baseline replacement and rotation calibration remain separate CLI operations.

The setup app bundles a committed source snapshot and shows its revision. Rebuild from an
updated clean checkout for newer code; an existing setup app retains its bundled revision. It is independent of
the menu app being replaced. Progress belongs to the installer; software review does not qualify
hardware. Close and Quit are held while the installer runs. Output goes to a private file under
`~/Library/Logs/DisplayBridgeSetup`, available through **Show installation log**. Forced app/process
termination and power loss are not guaranteed to recover automatically; inspect the report and
logs before retrying. The installer retains its own locks, fresh checks and rollback path.

Use **Last installation** to inspect the stored outcome without starting another attempt.
An exit status or recorded completion does not establish physical desktop or sound behavior.
The graphical flow has synthetic UI coverage; live installation and Mac B qualification remain
pending. Keep generated apps/logs private and build separately on each Mac; they can contain
local Python paths. The generated app remains under the checkout's ignored `.local-only` folder;
do not delete it while its installer is active.

For UI-only inspection, `python3 setup_gui.py --demo` blocks real installer/helper/service calls
and provides a ten-second simulation. `--build-only` builds without opening the app.

## Install each host

From the repository folder, run `./scripts/test`, then `python3 install.py A` on Mac A or
`python3 install.py B` on Mac B. The installer builds helpers, captures the baseline,
performs a brief layout test on first installation, and starts controller and menu services.
Run `python3 install.py --help` to list options without changing anything.

The controller uses `~/.config/display-auto` for private settings and backups and
`~/.local/bin` for installed helpers. The menu app is `~/Applications/Display Auto.app`.
LaunchAgents use `io.github.display-bridge` and `io.github.display-bridge.menu`.
No login credentials, cloud service, or administrator access are needed at runtime.

Test ordinary input changes, both-away, and both return orders. Listen to the selected output;
a software readback cannot prove that sound works. Mac B qualification is still pending.

## Optional native Shortcuts build (integration qualification pending)

The standard build remains ad-hoc signed and does not package native Shortcuts
metadata. The optional path requires full Xcode, its App Intents metadata tools,
and an existing suitable local code-signing identity. It does not obtain a
certificate or change keychain permissions. Keep identity values and signed
development bundles private.

For the CLI installer, explicitly set `DISPLAY_BRIDGE_MENU_SIGN_IDENTITY` to the
chosen local identity in your environment, then run the same preflight and install
commands above. Preflight checks the optional build tools; signature validation
happens during the build. Empty or ad-hoc identity selections fail instead of
silently producing an unusable action. Unset the variable to use the standard path.
The graphical setup has no signing-identity selector.

The package records whether Shortcuts metadata is included. Packaging and isolated
bundle rollback have passed locally, but execution through the actual companion
process is still being qualified. Only the separate signed synthetic app has
passed Shortcuts execution so far. This optional build is not a claim of distributed
release readiness. See the [implementation plan](plans/local-shortcuts.md).

## Calibrate BenQ rotation

After installation, keep both monitors on the current host. Physically orient BenQ in landscape,
set the matching macOS rotation and desired sizes, then run:

```sh
python3 install.py A --capture-rotation
```

Repeat in portrait with macOS rotation matching the sensor. Use `B` for Mac B.
Automatic rotation enables only after both orientation profiles exist. Keep PG at the origin
and BenQ directly to its left to use the current paired-size preview feature.

## Upgrade or replace a saved baseline

Run the same installer for the same host to preserve an existing baseline and verify the
current profile. Complete any pending size preview or recovery first. A queued preview
request also blocks installation, even before a preview starts. Let the controller finish
it; preserve requests and journals if troubleshooting is needed. The installer checks
before directory changes and again under its installation lock. Explicit rollback also
rejects queued requests and unresolved preview recovery before service changes or file
restoration. Neither operation deletes pending requests to force progress.
To deliberately replace the current baseline, arrange both local displays, select fixed 120 Hz,
then use `--capture-fixed-120`. This is a configuration change, not a repair shortcut.

Earlier private installations used another service namespace. Before upgrading those,
back up `~/.config/display-auto`, identify the old controller and menu plists in
`~/Library/LaunchAgents` by their `ProgramArguments`, stop those two services with
`launchctl bootout`, and move those plists outside LaunchAgents. Keep the backup until the
new installation works. The installer rejects conflicting plists; it does not automatically
migrate them or permit two controllers to run together.

If rollback after a failed upgrade reports a bootstrap error, the prior files may already
be restored but the service did not restart successfully. Inspect controller status and
LaunchAgent errors before retrying; do not delete the backup or recovery journals.

If an upgrade reports that the menu is still running, quit the older menu-bar app and retry.
The installer checks the exact executable path before replacement; it does not kill unrelated
processes. New menu builds also use a per-user ownership lock to prevent duplicate heartbeats.

## Stop automation

Pause from the menu for temporary work. To stop the new public installation's services:

```sh
launchctl bootout "gui/$(id -u)/io.github.display-bridge"
launchctl bootout "gui/$(id -u)/io.github.display-bridge.menu"
```

This does not restore an extended layout or remove saved files. Restore the desired layout
in macOS Displays settings. Move the two matching LaunchAgent plists out of LaunchAgents
if you also want them to stay stopped at the next login. Preserve configuration and recovery
journals until you have verified the displays and audio manually.
