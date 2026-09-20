# Advisory detection of other display tools

Added a local running-application snapshot to Setup readiness in the native window.
Recognized bundle names map to a fixed list of display-tool labels; unrelated app names,
paths and process identifiers are omitted. The report distinguishes uninspected, none
recognized and known apps running. It explicitly avoids claiming that presence proves
conflicting control or absence proves no other controller. No app is stopped, no data is
uploaded, and custom display-mode dependencies are left alone. No persistence change.

The snapshot runs only after an explicitly refreshed setup report returns, using AppKit's
running application list. The underlying CLI health report is unchanged; the new advisory
is window-only. Demo data remains synthetic and never queries the actual app inventory.

Validation: 214 Python tests and native builds/self-tests passed. Pure tests cover exact
recognition, case normalization, duplicate labels, unrelated-name omission and unavailable
versus empty results. Demo inspection verified the advisory text and scrollable report.
No physical tests or installation occurred. A read-only Mac A prerequisite check still
reported an unrecognized PG input, so coordinated deployment remains deferred.
