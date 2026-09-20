# Display Bridge

Local display and audio automation for two Macs sharing an ASUS PG42UQ and a BenQ RD280UG.
When one monitor shows the other Mac, its hidden desktop mirrors the visible monitor.
When both return, the saved extended layout is restored.

The controller also provides automatic speaker routing and bounded audio recovery, BenQ
rotation tracking after calibration, a menu-bar status window, brightness/volume controls, local diagnostics,
and reversible display-size previews. Runtime uses Python's standard library and locally
compiled Apple helpers; BetterDisplay is not called.

## Status and scope

This is an early, hardware-specific project, derived from controller version 2.10.1.
It is not a universal display manager. macOS private mode metadata and DDC behavior may
change with OS, monitor firmware, adapters, and cables. Mac B and sleep/wake qualification
remain incomplete. See [qualification](docs/qualification.md).

Default input mapping:

| Monitor | Mac A | Mac B |
| --- | --- | --- |
| PG42UQ | HDMI 1: 17 | HDMI 2: 18 |
| BenQ RD280UG | 19 | 15 |

The installer captures each Mac's local display identities and baseline; mode IDs and
configuration must not be copied between hosts. Other monitor setups are left idle.
The currently used policy is fixed 120 Hz and HDR off; configure desired sizes first.

## Getting started

Requires Apple-silicon macOS, Python 3.10 or newer, Xcode Command Line Tools, and the
supported monitor pair with DDC communication available. Review the code before installation.

```sh
git clone https://github.com/malivix/display-bridge.git
cd display-bridge
./scripts/setup-hooks
./scripts/verify
./scripts/verify --native
# On the intended host, with both monitors showing that host:
python3 install.py A  # use B on the other Mac
```

Installation changes the logged-in user's display setup and starts per-user LaunchAgents.
It needs no administrator privileges. Verify extended, single-visible, both-away, and return
orders on each host before relying on it. Existing HiDPI modes may depend on prior display
configuration; this project does not create arbitrary fractional-scale modes.

Installed state lives under `~/.config/display-auto`, helpers under `~/.local/bin`, and the
menu app at `~/Applications/Display Auto.app`. These are private runtime locations, not repo
content. The service namespace for new public installations is `io.github.display-bridge`.
An earlier installation using another namespace must be stopped and its old LaunchAgents
moved aside before reinstalling; the installer refuses a conflicting service.

```sh
python3 ~/.local/bin/display-auto.py --help
python3 ~/.local/bin/display-auto.py check
python3 ~/.local/bin/display-auto.py doctor
```

Automatic rotation needs separately captured landscape and portrait baselines. After a
normal installation, place both monitors on the current host, set BenQ's physical and macOS
orientation to agree, then run `python3 install.py A --capture-rotation` for each orientation
(use `B` on Mac B). Rotation becomes enabled after both profiles are captured. This changes
installation state; do it deliberately, outside ordinary verification.

See [development](docs/development.md), [architecture](ARCHITECTURE.md),
[security and privacy](SECURITY.md), [changes](CHANGELOG.md), and
[repository research](docs/repository-research.md).

## License

MIT. Vendored m1ddc retains its upstream MIT license and attribution; see
[third-party notices](THIRD_PARTY_NOTICES.md). No association with monitor vendors is implied.
