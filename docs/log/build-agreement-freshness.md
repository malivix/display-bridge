# Require a valid heartbeat for current build agreement

Reported build agreement now requires the menu's process, timestamp and version checks to
pass. Otherwise it explicitly describes stored fingerprints as historical metadata and
current agreement as unavailable, rather than showing an OK row beside a stale-menu warning.

Timestamp checks reject booleans, strings, nonfinite/huge values and future timestamps before
arithmetic. This also avoids float-conversion overflow from malformed JSON timestamps.
Regression coverage exercises stale, malformed, future and invalid-process cases with equal
stored fingerprints. All 262 Python tests and staged privacy checks passed. Native code and
installed state were unchanged; no physical or installation qualification is claimed.
