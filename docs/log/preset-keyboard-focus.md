# Restore keyboard traversal in preset dialogs

In the isolated Largest demo, Tab stayed on the brightness selector and on the preset
name field instead of reaching subsequent controls. Both dialogs constructed native
controls dynamically without recalculating their key-view loop before running modally.
Apply the same native recalculation already verified for the size chooser. No custom
keyboard interception, permission change, or controller behavior was introduced.

After rebuilding, observed Tab from brightness selector to Apply and Shift-Tab back to
the selector. In the naming form, Tab reached the replacement checkbox, Save and Cancel.
Return with an empty name displayed the validation error and focused the name field;
Escape returned to the main window. The Largest naming form was visually inspected with
all controls visible. No preset or hardware settings were changed. The shared naming/removal
form receives the fix, but destructive removal was not exercised in this check.

Validation: 238 Python tests, native builds and isolated native self-tests passed. The
actual keyboard failure and corrected behavior were verified through the native demo,
not a test that merely asserts a method call. VoiceOver speech, other system keyboard
configurations and light appearance remain unqualified. No installed app was replaced.
