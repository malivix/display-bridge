# Consistent scenario snapshots

Replaced the hardcoded single-local display fixture with a report derived from the same
scenario state as Overview. Added PG-only and BenQ-only choices. Remote and unknown monitors
receive unavailable mode descriptions; away does not invent a mirror relationship. Existing
snapshot retention and explicit refresh-failure behavior remain unchanged.

Native checks cover report input agreement, layout direction, available mode counts and report
acceptance for extended, each single-local direction, away and unknown. They also check that a
ready refresh matches inputs and a retained ready snapshot warns after switching scenarios.

All 247 Python tests and native builds/self-tests passed. In the isolated app, refreshed ready
showed two local desktops; changing to BenQ-only marked the old snapshot outdated; refreshing
showed BenQ as source with PG remote and matching-input status. No hardware or installation
changed. Synthetic modes do not establish real monitor compatibility or optical quality.
