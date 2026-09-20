# Explicit audio listening check

Added `audio-test` and Audio → Test selected output. The menu asks before playback and probes
controller support. The command validates the enrolled setup, known input ownership and one
live selected output, rejects an enrolled monitor showing the other Mac, plays a fixed quiet
system sample with a three-second deadline, then compares output and input state again. It
never selects, unmutes, adjusts system volume, resets formats or retries the sample.

A validated playback result leaves audibility unconfirmed. The menu asks Not sure / Heard it /
No sound, defaulting to Not sure, and keeps the response only as an explicitly past observation
in memory. It is not a current health assertion, saved diagnostic field or automatic repair
trigger. Transient endpoint changes between checks cannot be excluded; no lock on external apps
or physical input buttons is claimed.

All 258 Python tests and native builds/self-tests passed. Mocked checks cover monitor, built-in
and external categories, remote ownership, changed output, timeout, dead/ambiguous output and
strict result decoding. The local afplay help confirmed the playback-volume option. In the
isolated Largest-text Audio view the action was present and clicking it reported playback
disabled. No sound was played, no installed service changed, and the actual listening/response
flow remains physically unqualified. Staged privacy checks passed.
