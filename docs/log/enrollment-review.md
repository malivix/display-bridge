# Inspect prospective enrollment without saving it

Extracted candidate inspection from capture's write phase and added capture-review --host
A/B. Existing capture and the new review share identity, mode-policy, audio discovery and
two-input-read checks. Final mode metadata must still match the initial candidate. Review
returns only monitor roles, dimensions, orientation, local input values and audio categories;
private identities and helper paths are not included. No config or service changes occur.

The command uses existing maintenance/DDC serialization; coordination files may be created.
It requires built helpers and is not a standalone graphical installer. Review output is not
a reusable authorization token: capture always recomputes current evidence before writing.
Missing host is rejected during argument parsing before runtime setup.

Validation: 247 Python tests and privacy checks passed; CLI help was checked without hardware.
Synthetic Mac B review used its own input mapping, omitted identity/path data, preserved prior
config/baseline bytes and rejected a mode change during inspection. Existing capture-policy
and installer tests passed. Native code and installed services were unchanged; no physical
enrollment was performed. The native guided workflow and activation review remain future work.
