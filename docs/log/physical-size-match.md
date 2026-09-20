# Model-estimated physical size matching

Added Match PG size to BenQ to the existing preview options. BenQ remains the reference;
only already qualified PG modes are considered. The option appears when it improves the
estimated mismatch by more than half a percentage point and comes within 5% of BenQ's
physical UI scale. Both supported orientations use the long logical axis. The chooser shows
current and proposed physical percentages before detailed dimensions.

The CLI accepts `--size match-benq`; the daemon regenerates the proposal from fresh inventory
and uses the existing configuration fingerprint, ownership checks, preview journal and timed
rollback. No separate mode-writing path was added. Missing or unsuitable modes offer no match.
The model dimensions and first-party sources are in the scoped plan. This is an approximate
match, not user calibration, a readability guarantee or native-pixel sharpness at arbitrary sizes.

Validation: 251 Python tests and native builds/self-tests passed. New tests cover portrait and
landscape, no close candidate, invalid dimensions, unchanged BenQ choice and input report, plus
an integration fixture that updates simulated mode readbacks and verifies restart rollback.
An initial fixture did not simulate applied mode changes and correctly failed post-apply
verification; it was extended to model those readbacks, without weakening production checks.
After moving comparison text above dimensions, rebuilt and reran native self-tests.

In the isolated Largest-text chooser, the new option showed PG changing from 1920 × 1080 to
3008 × 1692 while BenQ remained 1920 × 1280, with synthetic physical estimates of 154% and 98%.
No preview was applied to hardware. Physical readability, calibration and deployment remain
unqualified; the current installed release and user settings were not changed.
