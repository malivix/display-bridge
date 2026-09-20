# Scale window controls with interface text

Window buttons, audio labels/selectors, monitor selector, and tabs now follow the three
interface sizes. Replaced fixed footer frames with native stack/anchor layout; audio
preferences stack label above selector. Display refresh uses intrinsic sizing and anchors.
The existing local preference remains compatible; hardware command paths are unchanged.
Rollback is the previous menu binary, with no controller state migration.

Validation: 192 Python tests and all native builds/self-tests passed. Fresh isolated demo
inspection at Largest confirmed enlarged Audio controls, scroll access to Repair and its
explanation, and Displays refresh/footer without overlap at the default window size.
A resize gesture did not change the window, so minimum-size visual qualification remains
outstanding. VoiceOver traversal, light appearance, preview-active footer and native alerts
remain follow-up work. No installation or physical display/audio changes were performed.
