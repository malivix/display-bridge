# Preserve save-dialog eligibility

Save dialogs currently check availability before opening, but do not show subsequent
readiness loss while a name is entered. Give size and brightness save dialogs a read-only
availability callback from their existing parent policy. Poll only local state once per
second in the modal loop, retain the first unavailable reason, disable Save, and require
Cancel/reopen even if readiness returns. Recheck on submission. Name editing must not
override a context failure. Removal keeps its existing validation and is outside this slice.

Use the existing controller command path and backend validation. This UI guard cannot
atomically lock physical input changes or observe every brief transition. No new hardware
reads, persistent state, configuration schema, or permissions. Rollback is the previous
coordinated source build. Verify with native checks and a timed isolated modal fixture;
do not activate the installed controller or change monitors.
