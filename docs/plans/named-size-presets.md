# Named size presets

Save the currently qualified pair under a local name and orientation. Recall is a new
request to the existing journaled preview service, never a direct mode write. Store logical
and framebuffer dimensions plus refresh rate; resolve mode IDs from a fresh qualified
inventory on recall. Reject ambiguous/missing matches and changed enrolled host/identities.

Use a bounded versioned local store with atomic private writes and a dedicated file lock.
Save under the preview/settings guard and installation read lock, checking input/orientation
before and after inspection. Damaged stores are preserved and reported, not reset. Duplicate
name/orientation saves require explicit replacement; the other orientation stays intact.
Chooser fingerprints still cover the proposed config, so changed presets/modes reject stale
requests. A request carries a preset name, not arbitrary mode data.

Deliver backend/CLI and isolated regression coverage first, then native save/recall UI.
Acceptance includes corrupt store, unavailable/ambiguous modes, host/enrollment mismatch,
orientation separation, stale fingerprints and existing preview rollback regressions.
Rollback: old runtime ignores size-presets.json; unresolved preview journals remain owned
by the established recovery path. Never copy the store to another host as enrollment.
