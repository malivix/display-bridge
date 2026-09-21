# Display Bridge

Automatically manage the desktop and speakers when two Macs share an **ASUS PG42UQ**
and **BenQ RD280UG**. Change inputs on the monitors as usual; Display Bridge observes
which screens show this Mac and adjusts its desktop.

| Screens showing this Mac | Desktop behavior |
| --- | --- |
| Both | Restore the saved extended layout |
| Only PG | Hidden BenQ desktop mirrors PG |
| Only BenQ | Hidden PG desktop mirrors BenQ |
| Neither | Preserve the layout and continue observing |

The menu app provides status, pause/resume, speaker preferences, brightness and volume,
local diagnostics, named brightness presets, and reversible size previews with saved presets.
BenQ auto-rotation requires calibration.
Optional [native Shortcuts actions](docs/shortcuts.md) provide status and timed
pause/resume; they require an explicitly signed build.
Speaker selection preserves an external headset. Runtime stays local and does not call BetterDisplay.

**Early, hardware-specific software.** Apple-silicon macOS 13+, Python 3.10+, and Xcode
Command Line Tools are required. Mac B is deployed but its switching, listening and
sleep/wake qualification remain incomplete.
Private macOS APIs and DDC behavior can change. Read the [qualification limits](docs/qualification.md).

## Install

First put both monitors on the Mac being configured, use an extended desktop, and choose
fixed 120 Hz, HDR off, and comfortable sizes. The installer requires exactly these two
online displays; close the laptop lid if its built-in display is active.

```sh
git clone https://github.com/malivix/display-bridge.git
cd display-bridge
python3 install.py A --preflight  # software checks only
./scripts/test
python3 install.py A  # use B on the other Mac
```

For an optional guided window, run `python3 setup_gui.py` from a clean trusted checkout.
It reviews software first and requires an explicit Install / upgrade action. See the
[graphical setup instructions and qualification limits](docs/install.md#optional-graphical-setup).

Installation builds locally and starts per-user services. The first installation briefly tests
mirroring and restores the saved desktop. It needs no administrator access. Capture settings
separately on each Mac; never copy mode IDs or device identities between hosts.
See the [installation guide](docs/install.md) for prerequisites, input mapping, rotation,
upgrades, and older installations.

## Use

Open **Display Auto** from your user Applications folder to see status and controls.
The installed app retains this name for compatibility. Closing its window keeps the
menu icon running; Quit menu bar removes the icon while the background controller
continues. The installed menu allows only one instance.

```sh
~/.local/bin/display-auto.sh status
~/.local/bin/display-auto.sh doctor
```

Start with the [control map](docs/usage.md#find-a-control), [readable interface](docs/usage.md#readable-interface-and-keyboard-navigation),
and [troubleshooting](docs/usage.md#when-something-is-wrong). The [changelog](CHANGELOG.md) summarizes current source changes. Source checkout updates do not
update the installed app; use the [coordinated upgrade](docs/install.md#upgrade-or-replace-a-saved-baseline).
Diagnostics contain private device information; keep them local. Read [SECURITY.md](SECURITY.md) before sharing any report.

## Develop

```sh
brew install gitleaks  # if Homebrew is already installed
./scripts/setup-hooks
./scripts/verify --native
```

`./scripts/test` runs isolated Python tests without Git, Gitleaks, or hardware access.
`./scripts/verify` adds publication checks; `--native` also builds and self-tests native helpers.
Physical tests under `tests/hardware/` are opt-in and excluded from these commands.

Read [development](docs/development.md), [architecture](ARCHITECTURE.md), and
[agent instructions](AGENTS.md). The [documentation index](docs/README.md) links reviews,
work logs, research, and current limitations.

## License

MIT; vendored m1ddc retains its MIT license and attribution. See
[third-party notices](THIRD_PARTY_NOTICES.md). No association with monitor vendors is implied.
