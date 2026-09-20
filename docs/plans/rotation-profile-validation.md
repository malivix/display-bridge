# Validate rotation profiles before activation

Observed: validate_config checks the main baseline's identity membership, while
select_rotation_baseline copies a rotation profile into rotation-active.json without
validating its structure or identity. Native apply has additional guards, so this is
not evidence that an arbitrary screen can be changed, but it can replace active state
with unusable data and defer failure until reconciliation.

Add shared validation in display_snapshot for stored rotation configuration and selected
profiles. Validate enabled completeness, sensor mapping, enrolled pair membership,
orientation and native layout field types before activation. Disabled incomplete
configuration remains supported for two-stage installer capture; malformed provided
profiles are rejected. Use the existing startup state-error path and preserve all files.

Tests reproduce rejection before replacing the active file, no hardware command on invalid
profiles, incomplete disabled enrollment, and valid rotation behavior. Keep existing
input rechecks/native mode preflight. Rollback is prior source; no migration or deletion.
