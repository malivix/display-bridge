# Attempt both service restarts

The rollback finally block stops at the first bootstrap error, potentially leaving the
other service stopped. Collect operational restart failures while attempting all services
that were stopped. Report every failed service and keep any original rollback exception
as the cause; otherwise chain the first restart failure. Never print a success summary
after a restart failure. Preserve existing file restoration and service ordering.

Test controller, menu and both restart failures after successful restoration and after a
failed verification that restores the undo snapshot. All tests use temporary files and fake
launchctl. No persistence migration; rollback is the previous source revision. This does
not make rollback atomic or guarantee recovery when launchctl cannot start a service.
