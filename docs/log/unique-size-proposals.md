# Avoid duplicate physical-size proposals

A qualified PG mode near the 105% model-size boundary could satisfy both the 100%
matching target and the 110% relative target. The chooser then offered two differently
named actions producing the identical PG/BenQ mode pair. A regression reproduced three
proposals for only two distinct pairs before the fix.

`paired_sizes` now retains one generated proposal per ordered PG/BenQ mode-ID pair.
Existing relative-size proposals come first, followed by ordinary physical matches and
then offset targets. The ordinary match is therefore retained when adjacent matching
targets overlap. User-named saved presets are unaffected. Mode IDs are compared only
inside the current qualified inventory; they are not portable identities.

Validation: the reproduction now passes and `scripts/verify` passed all 285 Python
tests. Native sources were unchanged. No hardware operation or installation occurred.
The service still re-derives current choices before preview, so an obsolete omitted
identifier is rejected rather than applied from stale UI data.
