# Keep brightness preset actions current

The chooser takes a one-time availability string and removal flag. Replace those with
local-state callbacks. Retain the first hardware-action failure, disable Apply/Save, and
explain Cancel/reopen. Check again before returning an action. Removal uses its own fresh
saved-controls/busy policy; remote ownership alone must not prohibit managing saved data.
Cancel always remains available. Preserve the parent and controller validation layers.

Verify the modal timer, eligibility changes, selection changes and cancellation with an
isolated fixture using real controls. Native verification remains hardware-free. No new
configuration or hardware polling; rollback is the previous coordinated source build.
