# Include preset evidence without unbounded state reads

Private diagnostics now include size-presets.json. State reads are capped at 1 MiB each;
oversized files record a 64 KiB sample, observed file size, truncation and captured-sample
hash. They do not populate the full-file hash field. Normal/malformed files within the cap
retain the existing full-byte hashing behavior. Original state files remain untouched.

Timing summary reads are also bounded and now expose history availability. The native
formatter distinguishes unavailable/oversized history from valid history with no completed
transitions. History recording behavior and the allowlisted support summary are unchanged.

Regression coverage first reproduced missing preset evidence, then checked oversized valid
JSON, retained samples/hashes, original-byte preservation, and unavailable timing history.
Native coverage checks the unavailable-history message. No installed runtime or hardware
changes were made; reports remain private and are not uploaded automatically.

Final validation: 207 isolated Python tests, native builds/self-tests and source verification
passed. Privacy review applies to the staged source; no private diagnostic artifact is staged.
