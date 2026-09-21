# Physical-size comparison for saved pairs

Ordinary size choices exposed `physical_size_percent`, but resolved named presets omitted
it, causing the existing comparison UI to show the selected estimate as unavailable.
Available presets now include the same estimate computed from their freshly resolved modes.
Unavailable presets remain unavailable. Fingerprints, enrollment/orientation scope,
persistence schema and preview/rollback behavior are unchanged.

The existing end-to-end preset test initially failed on the missing response field. It now
checks a positive estimate equal to the current pair just saved, unchanged preset-file bytes
after inspection, and successful preview followed by restart rollback. All 24 preview-service
tests and `scripts/verify` passed (297 Python tests plus privacy checks). Native source was
unchanged; the existing UI consumes this optional response field. No new native UI capture
or physical comparison was performed.

Source review also confirmed that named presets already preserve a preferred pair with
identity and orientation binding. The plan now states this explicitly to avoid duplicating
that store. This estimate remains model-based, not a claim of optical calibration or sharpness.
