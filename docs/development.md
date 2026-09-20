# Development workflow

Use Python 3.10+ and Git. Install Gitleaks (for example `brew install gitleaks`) for publication
checks. Native checks require Apple silicon and Xcode Command Line Tools. Run
`./scripts/setup-hooks` after cloning. Use a GitHub no-reply email for commits to this public repo.

`./scripts/verify` runs isolated Python tests and a privacy scan of the Git index.
`./scripts/verify --native` also compiles every helper and runs DDC/menu self-tests in a temporary
directory. Neither command installs software or runs physical switching/fault tests.
Gitleaks scans the staged snapshot through `./scripts/public-check`; with `--history`, that
command also scans commit history and checks author/committer email metadata.

Stage exact reviewed paths, run verification, inspect `git diff --cached --stat` and
`git diff --cached`, then commit with a Conventional Commit subject. The local commit-msg
hook enforces the subject format. CI checks pushed subjects and the same verification script.
Hooks are opt-in per clone and can be bypassed; CI and human review remain necessary.

For behavior changes, document expected outcomes, errors, and rollback before editing.
Add focused regression tests for actual failure modes. Keep dependencies minimal and
retain upstream license/provenance when vendoring. Summarize changes and validation in
`docs/log/`; raw logs, diagnostics, and machine inventories stay private.

## Hardware and deployment

Do not run `install.py`, `test_layouts.py`, or `test_audio_journal.py` in CI or a normal unit
suite. Physical tests may move windows, alter output routing, or deliberately interrupt
recovery. Plan them explicitly with a recoverable baseline and the intended host available.
Successful helper exit or readback is not proof of audible sound or correct physical output.

For an older service namespace, back up the private state directory, identify the controller
and menu LaunchAgent plists by their ProgramArguments, stop those exact services with
`launchctl bootout`, and move both plists outside LaunchAgents. Then run the new installer.
Do not leave two controllers enabled. Automatic namespace migration is not implemented;
the new installer refuses conflicting plists before making installation changes.
The previously installed controller can continue running while public source is developed.

## Public worktree boundary

`.local-only/` retains pre-publication notes and old exports on the original development
machine. `evidence/` retains private validation artifacts. Neither belongs in Git or a release
archive. The public history begins with reviewed source, not an import of private history.
Use synthetic fixture identities. Before release, inspect the actual archive contents as well
as Git history; ignoring a file does not protect arbitrary ZIP uploads.
