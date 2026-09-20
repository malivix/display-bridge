# Remove named presets without changing displays

Added explicit name/orientation removal to the chooser and CLI so the bounded store can be
managed without editing JSON. Removal requires the inspected entry revision, preserves the
other orientation, uses shared persistence/locking guards, and never sends a hardware command.

Validation: 205 Python tests passed; native builds/self-tests passed. New tests cover stale
confirmation, preservation of another orientation, blocking during preview, and removal with
hardware commands forbidden. Largest-text demo inspection confirmed the name/orientation
selector and explicit Remove/Cancel controls; cancellation returned to the window.

Read-only live check found fresh Mac A health still waiting-for-known-input, with an
unrecognized PG input. No deployment or physical preset test was attempted. UI qualification
and installed/source parity remain separate. Private hardware state was not copied into Git.
