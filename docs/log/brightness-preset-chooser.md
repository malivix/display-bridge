# Brightness preset chooser

Controls now exposes per-monitor named brightness presets. The chooser displays the
explicit target and saved native value/range, with separate Apply, Save and Remove
buttons. It remains readable at the Largest text setting. Save reuses the existing
inline name validation and requires explicit replacement. Empty lists allow Save and
disable Apply/Remove. Invalid lists are rejected without modifying the store.

The menu validates monitor identity within the report, ranges, revisions and duplicate
names. Apply/removal retain the selected snapshot revision and monitor; the controller
performs the authoritative fresh ownership and store checks. No automatic brightness
writes or new hardware access path was introduced.

Validation: `scripts/verify --native` passed 220 Python tests plus native build/self-tests.
After adding an empty-list demo fixture, the final menu was rebuilt and its self-tests
passed again. Hardware-free UI inspection covered the populated Largest chooser, the
Save form, empty-list disabled actions, and Save reaching the demo's blocked-command
alert. This does not establish a real brightness change, full VoiceOver coverage, or
physical ownership-race behavior. Apply/Remove dispatch were not physically exercised.

The installed menu/controller were not changed. Deploy both together; older controllers
do not implement these commands. Rollback can restore the previous bundle while leaving
the additive preset store intact.
