# Bounded Shortcuts pause and resume

Two native actions now complement status: Pause Display Bridge accepts integer
minutes in 1–1440 (default 30); Resume Display Bridge requests normal reconciliation
without clearing a manual audio override. Both use the canonical CLI and its
mutation/control locks. No direct control-file writer or hardware path was added.

The shared submission function rejects demo and invalid duration before any process,
checks the read-only capability protocol, then dispatches exactly once with a bounded
time/output budget. A successful exit is insufficient: the acknowledgement must
contain the requested action and a valid request identifier matching the saved
command request. Typed results are Request saved, Request not sent and Outcome
unknown. Saved means persisted for the controller, not paused/resumed hardware.
Unknown outcomes explicitly explain that timeouts do not cancel accepted work.
Raw output, controller configuration and error details never become intent results.
Blocking subprocess work runs outside the UI thread.

Native regressions exercise boundary durations, invalid durations, demo mode,
missing/failed capabilities, pause/resume command arguments, matching and mismatched
acknowledgements, nonzero exit, timeout, output overflow and no automatic retries.
The metadata builder now requires all three actions, including status, before signing;
the missing-metadata regression removes only Pause to check this requirement.

Validation: `./scripts/verify --native` passed with 305 Python tests and native
checks. A private signed build also ran menu self-tests; its demo-mode run passed.
Metadata contained all three actions/shortcuts and the three outcome cases, with
pause output explicitly referencing the outcome enum. Strict signature verification
passed. Final review added exact request-identifier length validation and a trailing
newline regression; full native verification was rerun after that final change.
The signed metadata inspection predates that final parser-only tightening.

Ordinary checks use
injected runners and disposable state; the actions have not been invoked against the
installed controller. Actual Shortcuts UI execution of the two new actions remains
pending. Prior isolated status-action execution does not qualify mutations.
