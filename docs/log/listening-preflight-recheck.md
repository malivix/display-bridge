# Recheck listening target immediately before playback

The listening command now repeats input/output comparison after initial inventory inspection
and before invoking afplay. A detected pre-playback change aborts without playing. After
playback, unavailable inspection and detected changes explicitly report an inconclusive check;
no success result is returned and the menu cannot ask for a successful playback observation.
Endpoint checks still cannot exclude transient changes between reads or lock another app.

Tests cover input changes before playback (zero calls), input changes afterward (one call),
changed output after playback and post-playback inventory failure. All 259 Python tests and
staged privacy checks passed. Native code was unchanged. No sample was played and no installed
service or monitor settings changed.
