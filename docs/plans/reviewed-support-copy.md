# Copy the reviewed support summary

Add a Details action scoped to the displayed support-summary body. Do not copy timestamps
added by the report view, health reports, raw diagnostics or later unseen results. Selecting
another report or starting summary refresh invalidates the copy target; failed refresh
must not leave the old target enabled. Keep command output and clipboard actions separate.

Copy requires an explicit click; no upload or implicit clipboard change. The demo blocks
clipboard writes. Verify selection/invalidation/size bounds in native tests and the button's
placement/enabled state in the demo. No persisted state; rollback restores prior menu source.
