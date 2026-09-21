# In-app keyboard reference

More controls now includes Keyboard shortcuts near the top. The local help window lists
tab selection, refresh, controls menu, focus traversal and dismissal. It follows the app's
text-size preference and explains that command shortcuts are window-scoped and refresh
can read settings without changing them. The help action is allowed with unreadable controls
and returns before any backend command handling; it uses the existing text/action dialog.

`scripts/verify --native` passed all 297 Python tests and native self-tests, including
the help action's read-only eligibility. A new signed demo at Largest size showed all text
and Done fitting in the window. Done received initial focus and Escape dismissed the
window. Unreadable-control eligibility was checked in native policy tests, not a separate
UI scenario. VoiceOver speech was not tested. No runtime state, hardware, clipboard or
notification changes occurred.
