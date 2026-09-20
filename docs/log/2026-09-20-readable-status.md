# Readable status and incident-aware notifications

The menu now deduplicates by a hashed incident category/profile/recovery reason rather
than a global sent flag. Retry timestamps and counts do not create new incidents. A pending
reservation prevents overlapping notification-settings callbacks from duplicating delivery;
late completion cannot overwrite a newer reservation. Failed delivery can retry, and stored
incident fingerprints survive app restart. Fresh Ready/inactive state clears the episode.
At most 16 distinct incident fingerprints alert before recovery, limiting notification storms;
all further faults remain visible in status. An old notification cannot issue audio repair
against a different or stale incident. Actual macOS banner delivery remains unqualified.

The status window is resizable and provides 16/20/24-point text, preserving scroll/selection
on refresh. The control labels remain native size; this is not the complete accessibility or
grouped dashboard redesign. Demo mode supplies synthetic data and blocks backend commands,
notification setup, heartbeat writes, and preference persistence.

Visual checks: opened a separately built ignored demo bundle, selected Largest, then shrank
the window. Content wraps and scrolls while controls stay visible. The accessibility tree
exposes named text-size choices. Check health in the demo displayed the hardware-free guard
instead of invoking a controller. Screenshots stay in the ignored local directory.

The initial temporary bundle had a launcher identity problem, followed by a deployment-target
mismatch. Rebuilding with the verifier's explicit macOS 13 target resolved launch. No installed
app, controller, or monitor settings were changed. VoiceOver, keyboard traversal, light mode,
actual notifications, and the installed hardware flows still require separate qualification.

Rollback is a menu rebuild/source revert; controller journals and settings are unaffected.

Validation passed: 179 Python tests, native builds, DDC self-tests, incident/routing/menu
regressions, staged secret/privacy checks, and whitespace checks. Demo interactions were
visually inspected; the demo was quit afterward. Its files remain ignored local artifacts.
