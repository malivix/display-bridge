# Setup readiness inspection

Added Details → Setup readiness using the existing read-only doctor command. The report
places saved enrollment findings before general instructions and retains the existing
health checks and timestamped snapshot behavior. Older reports lacking enrollment facts
show explicit unknowns; no new CLI action or background polling is required.

Health inspection now describes the configured host/input map and the presence of two
matching orientation profiles plus a sensor mapping. It does not expose enrolled keys
in these new fields or claim the sensor is calibrated or responsive. Incomplete enabled
rotation is a warning; optional unconfigured rotation is informational. Configuration
must pass the existing validator before enrollment facts are emitted.

Scope follows milestone 3 in ui-next-milestone.md. This is the read-only checklist, not
an enrollment wizard. No state writes, dependencies or hardware mutation paths were
added. Rollback uses the compatible prior source; reports add fields only. No journals
or installed configuration are changed.

Validation: 211 Python tests and all native builds/self-tests passed. Checks cover host
B mapping, complete/missing profiles, changed display identity, invalid sensor values,
and missing old-report facts. Rebuilt/reran native self-tests after reordering presentation;
reran Python tests after placing enrollment checks first. Demo inspection verified the
report selector, explicit Refresh, snapshot text, missing portrait guidance and findings
above next steps. No physical or Mac B qualification was performed. Not installed.
