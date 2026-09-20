# Consistent orientation-aware health reporting

A regression demonstrated that Check health incorrectly compared PG with the default saved
layout when the current BenQ orientation selected a different saved layout for the pair.
The newer Displays snapshot already handled both monitors. Extracted one read-only saved-layout
selector and used it in both reports. Missing, duplicate, or unsupported BenQ orientation
cannot select an arbitrary baseline; checks report the missing match instead.

The failing test used different PG sizes in the orientation-specific layout, then verified
that duplicate BenQ identity does not silently select it. All 192 Python tests passed after
the change. No controller policy, saved configuration, or hardware setting changed. This
fix remains source-only until a later coordinated deployment. Physical-input clarification
is still pending and does not block these isolated reporting tests.
