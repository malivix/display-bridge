# Development

## Setup and checks

Use Python 3.10+ and Git. Native compilation requires Apple silicon and Xcode Command Line
Tools. Install Gitleaks for publication checks (`brew install gitleaks` if using Homebrew),
and run `./scripts/setup-hooks` once per clone. Use your GitHub no-reply email for public commits.

| Command | What it checks |
| --- | --- |
| `./scripts/test` | Syntax and all Python unit tests, with a disposable child-process home |
| `./scripts/verify` | Unit tests plus exact-index privacy and secret scanning |
| `./scripts/verify --native` | Above, plus all native builds and DDC/menu self-tests |
| `./scripts/public-check --history` | Index and history content, secrets, and commit email metadata |

The installer also calls `scripts/test`, so installation cannot silently use a smaller test
list. Tests under `tests/hardware/` are excluded from discovery; ordinary checks never install,
change monitor inputs, or exercise physical fault recovery. The menu self-test launches small
local processes to verify timeout and output limits; it does not start the app UI.

## Project map

- Root Python modules: deployed controller, policy, recovery, and diagnostics; their flat layout
  matches the installed runtime. `display-auto.py` is the CLI; `install.py` is import-safe.
- `native/`: Swift menu/layout and Objective-C audio/rotation/mode helpers.
- `tests/unit/`: isolated Python regressions. `tests/native/`: hardware-free native tests.
- `tests/hardware/`: explicitly invoked physical tests requiring a controlled setup.
- `scripts/`: developer verification and publication gates. `.githooks/`: opt-in local hooks.
- `vendor/m1ddc/`: pinned upstream DDC source, retained license, and local patch notes.
- `docs/`: user guides, qualification, work logs, plans, and research.

`release_manifest.py` is authoritative for the version, installed modules, and helper hashes. If a runtime
module is added, update it so deployment, backups, and health agree. Native build paths and
source-hash discovery must follow the source tree. Keep user state outside the repository.

## Work loop

Define an observable outcome. For persisted state, recovery, or cross-module changes, write
a short plan under `docs/plans/` with failure handling and rollback. Add focused regressions
for bugs, then implement the smallest coherent change. Stage exact paths, run checks, inspect
`git diff --cached`, and use `type(scope): imperative summary` Conventional Commit subjects.
Record what actually passed and what remains unverified in `docs/log/`.

Hooks can be bypassed; CI and review remain necessary. A passing mock or native compilation
is not a physical display/audio test. Preserve upstream attribution when editing vendor code.

## Local/private material

`.local-only/` and `evidence/` hold private historical artifacts on the original development
machine and are excluded from Git. Diagnostic reports, backups, and hardware inventories stay
local. Review release archives independently; Git ignore rules do not sanitize arbitrary ZIPs.
See [security](../SECURITY.md), [installation](install.md), and [qualification](qualification.md).

## UI preview

The compiled menu executable accepts `--demo` (or a test bundle with `DisplayBridgeDemo`
set to true). It uses synthetic status, blocks all backend commands and notification
requests, and does not write the controller heartbeat or save text preferences. This
allows layout/accessibility inspection without installing or controlling monitors. Build
with the same macOS 13 deployment target used by `scripts/verify`; the compiler default
may target a newer OS than the development machine. Local preview bundles stay ignored.
