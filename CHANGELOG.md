# Changelog

## 2.11.0 — current source milestone

Source changes only; installed production activation of the optional Shortcuts
build remains unqualified. See the [usage guide](docs/shortcuts.md) and
[qualification limits](docs/qualification.md).

- Record the stable interpreter path in the installed services instead of a resolved
  one, so a Python patch upgrade no longer leaves them unable to start. Reject a
  relative or missing interpreter at entry.
- Accept the product code each enrolled panel publishes on the input a host uses, so
  capture identifies the BenQ on both Mac A and Mac B. Ambiguous and unknown panels
  are still rejected.
- Scale native controls and window minimum heights with interface text size; validate
  size comparison reports before offering preview actions.
- Keep development reviews window-only, allow one review at a time across bundle
  identities, and exit when the last review window closes.
- Preserve keyboard focus when recovery actions disappear, keep Overview aligned
  at the top, and reveal controls reached by keyboard navigation.
- Offer Check health directly for unrecognized monitor inputs without changing
  the enrolled mapping or offering an unsafe repair action.
- Add typed native Shortcuts status, timed pause and resume through the existing
  controller boundary. Validate requests, distinguish saved and uncertain outcomes,
  and avoid automatic retries or result-dialog waits.
- Add optional signed metadata packaging while retaining the standard ad-hoc build.
  Verify isolated companion execution and coordinated bundle-content restoration.
- Verify caught SIGINT rollback after installer release activation with disposable
  state and stubbed services; this does not establish power-loss durability.

## 2.10.2 — source milestone

These are source changes, not a newly qualified binary release. Updating the checkout
alone does not update an installed controller or menu app. See the
[upgrade guide](docs/install.md#upgrade-or-replace-a-saved-baseline) and
[qualification limits](docs/qualification.md).

### Controls and readability

- Add Overview, Details, Displays, Audio and Controls tabs, a resizable window and three interface text sizes.
- Offer 15-, 30- and 60-minute pauses from the main window; show expiry and distinguish stale controller status.
- Add window-scoped tab/refresh shortcuts, ⌘⇧P for More controls, and an in-app keyboard reference.
- Add targeted brightness/volume controls, explicit-Apply percentage entry, dated readbacks and named brightness presets.
- Add display snapshots, paired readability samples, reference-monitor size comparisons and named size presets with physical-size estimates.
- Preview qualified sizes with Keep/Revert and automatic restoration; reject stale choices when readiness or orientation changes.
- Show speaker preferences by profile, temporary output preservation, and explanations for unavailable audio repair.
- Validate preset names during editing and explain why an open save/apply dialog lost eligibility.
- Add a local diagnostic report and a separate allowlisted support summary without automatic upload.

### Recovery and deployment

- Bound menu commands by deadline and output size; show progress, status age and last-known values.
- Track controller request acknowledgements and durable outcomes without replaying hardware work; reject oversized request timestamps without blocking preview restoration.
- Deduplicate failure notifications per incident and reject stale repair actions.
- Align health and snapshots with orientation-specific saved layouts; prevent duplicate menu ownership and replacement while old instances remain.
- Validate backup payloads and restore controller/menu together. Prepare all restore copies before changing live files so a copy failure leaves the current installation intact.
- Attempt service recovery after failed stop observations, continue remaining restarts after an operational restart error, and report partial recovery explicitly.
- Add a separately built graphical setup app with bundled source, software preflight and an explicit installation action.

### Development and evidence

- Separate native sources, unit tests and opt-in physical tests; share the isolated test command with the import-safe installer.
- Centralize controller/menu versioning and build inventories; verify Python compatibility, native helpers, commit conventions and privacy in CI.
- Add isolated process-termination, restore-copy, permissions and relative-link regressions. These do not establish whole-installation atomicity or power-loss durability.
- Expand installation, usage, troubleshooting, architecture and qualification guides. Detailed evidence remains in [work logs](docs/log/).

## Public bootstrap — based on 2.10.1

- Initialize Display Bridge as a public source repository from controller 2.10.1.
- Add agent guidance, developer workflow, privacy checks, hooks, and CI.
- Exclude private evidence, historical notes, machine state, and compiled artifacts.
- Use a project-owned service namespace for new installs and reject older conflicting services.
- Identify known panel specifications by model rather than a development monitor's serial.

Earlier local revisions are summarized in qualification notes; this repository does not
publish the private development history or claim a newly hardware-qualified release.
