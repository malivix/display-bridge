# Choose the reference monitor for physical matching

Added Match BenQ size to PG beside Match PG size to BenQ. Either direction retains the
reference monitor's qualified current mode and selects only an improving close mode for the
other monitor. The existing chooser consumes the returned labels and comparison fields; no
native command path or rendering changes were required. Estimates remain model-based.

Extended the matching selector instead of adding a second implementation. Tests cover keeping
PG fixed with BenQ in either orientation and rejecting an unknown reference. Integration checks
for each direction regenerate the fingerprinted proposal, simulate applied-mode readbacks and
verify controller-restart rollback through the existing transaction.

All 253 Python tests and staged privacy checks passed. Native code was unchanged. No installed
release or physical display changes were made; optical/readability checks remain deferred.
