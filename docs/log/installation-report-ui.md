# Inspect the last installation from the menu

Last installation is available from the top-level menu and Details. The installed controller
exposes a read-only `installation-status` command before configuration loading or hardware locks;
it reads this Mac's latest report and labels the recorded host. Explicit CLI host filtering is
preserved. The reader ships in the runtime inventory, and the menu probes command support before
dispatch so older controllers decline gracefully.

A focused native formatter validates the response and presents outcome, phase, report age and
recovery separately. Raw process/attempt identifiers, arbitrary errors and extra fields are not
rendered. A missing process for a stored running attempt puts outcome unknown in the headline.
Stored completion remains an installer observation, not current health or physical qualification.
Nothing is installed, resumed or retried by viewing or refreshing this report.

The Largest-text dark demo was inspected for completion and missing-process outcomes. This found
an omitted Command-R mapping; report selection and keyboard refresh now share one registry.
Command-R was then verified in the demo. The missing-process headline was promoted after visual
inspection and its position covered by a native assertion. Additional native cases cover failed
recovery, live-PID uncertainty, malformed fields, extra-field exclusion and unsupported commands.

Validation: 276 Python tests and native builds/self-tests passed, including read-only status
inspection with invalid saved config and no helper calls. Staged privacy checks passed. Installed
services and hardware were unchanged. Graphical activation and full accessibility/physical
qualification remain unfinished; the demo and its observations do not establish installed behavior.
