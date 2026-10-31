# Changelog

## Unreleased

Source changes only; not installed. Physical qualification is listed in
[docs/log/2026-10-31-windowserver-connection-churn.md](docs/log/2026-10-31-windowserver-connection-churn.md).

- Read monitors through one long-lived `display-ddc serve` process instead of starting
  four or five helpers per poll. Each helper opened and closed its own WindowServer
  connection, about 270,000 a day, and WindowServer exited after about a day of uptime
  twice in a row, logging the user out. The reader is recycled every 10 minutes and after
  any timeout, exit or malformed reply. The per-poll topology check now uses the reader's
  `display keys`, the same identity the layout helper reports.
- Tolerate isolated missed DDC replies: two consecutive failures neither report the monitor
  unavailable nor force a full reconciliation afterwards. Sustained failures (a monitor off
  or in standby) back off up to 4 s between polls instead of retrying four times a second.
- A monitor that does not answer during a transition's input confirmation now counts as
  settling, not as a failed recovery attempt, so a flapping monitor no longer exhausts the
  retry budget and leaves the controller degraded.
- `display-layout apply` defers without changing anything while an online display is asleep;
  the controller reports it under "waiting for monitor response" and retries on a new input
  state or after 30 s. The apply timeout is 20 s so a slow mode change is not killed between
  its unmirror and restore transactions.
- `display-ddc`: refuse an identifier that matches more than one display, validate display
  indexes, check the online-display list for errors, allow 16 online displays, initialize
  and release every enumerated field, and terminate any command after 8 s.
- `display-audio status` skips a device that disappears during enumeration instead of
  failing the whole inventory; `display-rotate` explains each refusal.

## 2.11.0 — current source milestone

Source changes only; installed production activation of the optional Shortcuts
build remains unqualified. See the [usage guide](docs/shortcuts.md) and
[qualification limits](docs/qualification.md).

- Mirror an enrolled built-in display while the lid is open instead of idling: onto the PG,
  or onto the BenQ while the PG is away. Enroll it with `install.py <host> --capture-lid`.
  Doctor reports the enrollment. Any other extra display still idles automation.
- Describe each profile's layout, mirroring included, in the applied baseline. The native
  helper alone compares it with the live layout, skips the apply when they already match,
  and verifies its own readback. `display-layout apply` no longer takes a source argument,
  and the new read-only `display-layout check` backs the preview verifier.
- Re-request pending recovery after a capture replaces the baseline, so attempts counted
  against the replaced one no longer leave verification exhausted. A rotation capture for
  the orientation that differs from the saved baseline no longer needs manual service
  handling.
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
