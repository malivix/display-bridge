# Changelog

## 2.10.2 — unreleased

- Separate native sources, unit tests, native tests, and physical tests.
- Share an isolated test command with the import-safe installer.
- Bound menu commands by deadline and output size.
- Show command progress, status age, and last-known labels; open status from failure notifications.
- Add an Audio tab with profile preferences and explanations for unavailable repair.
- Add read-only display-mode snapshots with measured/saved comparisons and ownership checks.
- Group status into Overview and Details, expose Pause directly, and hide inactive preview decisions.
- Add a resizable status window, three text sizes, and a hardware-free UI demo.
- Deduplicate failure alerts per incident and ignore stale notification repair actions.
- Track controller request acknowledgements and bounded durable outcomes without replaying hardware work.
- Reject oversized request timestamps without blocking preview restoration.
- Validate backup payloads before restoration and roll back controller/menu together.
- Clarify installation, usage, troubleshooting, development, and qualification docs.
- Centralize the controller/menu version and test Python compatibility in CI.

## Public bootstrap — based on 2.10.1

- Initialize Display Bridge as a public source repository from controller 2.10.1.
- Add agent guidance, developer workflow, privacy checks, hooks, and CI.
- Exclude private evidence, historical notes, machine state, and compiled artifacts.
- Use a project-owned service namespace for new installs and reject older conflicting services.
- Identify known panel specifications by model rather than a development monitor's serial.

Earlier local revisions are summarized in qualification notes; this repository does not
publish the private development history or claim a newly hardware-qualified release.
