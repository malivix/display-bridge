# Show the controller's current reconciliation phase

The controller now publishes a recovering health observation immediately before rotation
checking, desktop layout application, input confirmation and audio reconciliation. Each
includes the existing recovery state and the phase identifier. The observation timestamp
comes from the existing health writer; no additional clock sampling, DDC read or hardware
command was introduced. Final and failed outcomes replace the phase-bearing snapshot.

The BenQ rotation summary displays an allowlisted phase description and seconds since its
report while the controller is recovering and the report is less than 15 seconds old.
Paused/manual controls, stale status, unsafe setup, preview ownership and remote BenQ take
precedence. Unknown phases and invalid timestamps never become instructions. This is an
observed phase, not an estimated completion percentage or proof that a call is advancing.
The rotation-check phase still includes both the native rotation and its readback; more
detailed subphase timing and physical latency qualification remain open.

Regression coverage asserts publication before each operation and removal at the final
outcome. Native checks cover phase text, age, malformed values, unknown identifiers and
pause precedence. The retry regression now ignores in-flight observations when counting
failed outcomes; its expected three-attempt budget is unchanged. Using the health timestamp
preserves the existing clock-controlled wake and slow-failure tests.

No deployment or physical test occurred. Polling/debounce/ownership policy is unchanged.
Rollback is the previous coordinated controller/menu snapshot; no persisted execution
journal or user configuration schema changed.

Validation: `scripts/verify --native` passed with 284 Python tests and native builds/self-tests.
