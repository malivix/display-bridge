# Preserve ordinary previews when named presets are damaged

Regression tests reproduced the whole chooser failing for malformed preset JSON and denied
file access. Preset loading is now isolated from fresh hardware mode inspection. It returns
an explicit warning and no named choices while retaining ordinary size choices. The original
file is never reset. Hardware, topology and ownership failures still fail the full inspection.
Named saves/recalls continue to reject damaged or mismatched state.

The native chooser displays the warning first and disables Save current as preset. Added a
hardware-free presets-error demo fixture. Largest-text inspection confirmed the warning,
current choice and enabled Preview action, with Save disabled.

Validation: 203 tests passed after two new regressions first failed; native builds/self-tests
passed. Final demo fixture compiled and was inspected. No installed app or hardware changes.
