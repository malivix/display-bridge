# Display Bridge

Local macOS display and audio automation for a specifically enrolled monitor pair.
Read [ARCHITECTURE.md](ARCHITECTURE.md) before changing controller boundaries.
Read [docs/development.md](docs/development.md) for setup, verification, deployment,
and changes to persisted state. Read [SECURITY.md](SECURITY.md) before publication,
diagnostics, dependency changes, or handling machine state.

## Invariants

- Hardware mutations require the saved display identities, topology, and fresh input ownership.
- Unknown or failed reads defer changes. Preserve recovery journals and original configuration.
- Keep monitor inputs connected; never switch physical inputs as part of automation.
- Serialize hardware changes through the controller. UI requests use the existing command boundary.
- Runtime remains local: no telemetry, cloud dependency, or network listener.
- Mode and speaker readbacks are evidence of software state, not audibility or optical quality.

## Work loop

1. Define the observable result and read the affected code/tests.
2. For recovery, persistence, or cross-module changes, record a short plan and rollback strategy.
3. Reproduce defects with an isolated failing test when feasible. Keep hardware tests opt-in.
4. Implement the smallest coherent change; preserve unrelated local work.
5. Run `./scripts/verify`. On Apple silicon, run `./scripts/verify --native` for helper changes.
6. Review `git diff --cached` and run `./scripts/public-check` before committing.
7. Record meaningful changes and actual validation in `docs/log/`; state deferred physical tests.

## Publication and commits

Use Conventional Commits: `type(scope): imperative summary`, for example
`fix(audio): preserve pending recovery after restart`. Use `!` for breaking changes.
Run `./scripts/setup-hooks` once per clone. Hooks and CI supplement review; do not bypass them
or weaken checks to obtain a pass. Never stage private evidence, archives, machine identifiers,
credentials, personal commit email addresses, or actual user configuration.
Public examples use synthetic identifiers and portable paths. Do not install or run physical
fault tests as part of ordinary verification. Deployment and publishing releases are separate
from committing source. Keep a single current work item; add infrastructure only for an observed need.
