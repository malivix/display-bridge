# Installation

## Prerequisites

- Apple-silicon Mac running macOS 13 or newer, with Python 3.10+ available as `python3`.
- Xcode Command Line Tools. Run `xcode-select --install` if needed; finish the Apple installer.
- PG42UQ and RD280UG connected and online, DDC/CI enabled where the monitor exposes it.
- Exactly the two external displays in extended mode, both showing the Mac being configured.
- Select fixed 120 Hz and HDR off in macOS Displays settings, then choose readable sizes.
  Existing custom HiDPI modes must already be available; this project does not create them.

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

## Input mapping

| Monitor | Mac A | Mac B |
| --- | --- | --- |
| PG42UQ | HDMI 1, DDC value 17 | HDMI 2, DDC value 18 |
| BenQ RD280UG | DDC value 19 | DDC value 15 |

The two roles must use this mapping. Other inputs remain unknown; automation does not guess
or switch a physical input. The saved pair is bound to locally discovered identities.
Extra or replacement displays make automation idle until the setup is deliberately recaptured.

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
before directory changes and again under its installation lock.
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
