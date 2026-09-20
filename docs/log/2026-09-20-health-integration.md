# Health checks cover menu and preset integration

Added independent menu heartbeat/process/version checks and preset schema/enrollment checks.
A missing menu heartbeat is informational; a present stale or mismatched menu warns with
matching-app guidance. Preset errors preserve the original file and explain that relative
previews remain available. Preset validation does not claim that modes are currently available.
Health JSON reads now stop at 1 MiB and report oversized state rather than fully parsing it.

Validation: 210 Python tests and source/privacy verification passed. Regressions cover current,
stale, mismatched and missing menu states, damaged presets, oversized state, and byte-for-byte
preservation. Existing native report rendering is reused; no native source changed. GitHub
verification for previously pushed 651ebb4 completed successfully. No installation or physical
monitor operations were performed.
