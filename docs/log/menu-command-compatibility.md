# Preset command compatibility guard

The CLI now offers a configuration-independent, read-only `capabilities` report derived
from the parser action list. Before brightness and named size-preset save/removal commands,
the menu probes support on its worker queue. Missing, malformed, unsupported or failed
responses stop dispatch with coordinated-update guidance. Existing status and recovery
commands do not depend on this newer endpoint. Reports are not cached across invocations.

Validation: 221 Python tests and all native builds/self-tests passed through
`scripts/verify --native`. The isolated CLI test checks no configuration/hardware access
or state-directory creation. Native injected-runner tests cover accepted support, timeout,
invalid schema, missing commands and legacy recovery passthrough. No installed code or
hardware changed. This is not daemon/build attestation, proactive button disabling, or
physical upgrade qualification. Capability probing adds at most five seconds before the
existing command deadline. No new persistent state needs migration or rollback.
