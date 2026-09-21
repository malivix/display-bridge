# Observe the current installer attempt accurately

Review found that setup marked a running child's presence but did not explicitly mark
its absence after termination. A saved report still marked running therefore received
generic unknown-process wording instead of the stronger observed-exit explanation.
Also, a missing or mismatched report left the previous text visible during polling.

Extracted current-attempt correlation into `setupAttemptSummary`, shared by the live
presentation and native regressions. It checks child PID, host and finite start time
against the window's launch time and current time. The owned child's observed running
state replaces any process-observation field supplied by the file. An exited child
with a running report now produces the explicit unknown-outcome/missing-process message.
Missing or mismatched current records clear the previous presentation. Existing report
schema validation remains in `installationSummary`; no automatic retry or recovery was added.

Regression cases cover running/exited observations, wrong PID, Boolean PID, old/future
start time and wrong host. These are isolated report/lifecycle-state cases, not actual
installer subprocess failure injection. Service interruption, power loss and physical
recovery remain unqualified. No installation or monitor command was performed.

Validation: `scripts/verify --native` passed with 279 Python tests and native builds/self-tests.
