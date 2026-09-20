# Validate display policy before capture

Guided enrollment must build on capture that proves the configured image policy. Existing
capture checks only numeric refresh, which cannot distinguish fixed 120 Hz from VRR.
Add one shared validator for first capture and installer orientation/fixed-mode recapture:
exact display identities and mode properties, 2x HiDPI, explicit VRR/ProMotion false and
HDR preference false. Unknown metadata rejects capture; do not change monitor settings.

Read current metadata before saving any baseline. Preserve prior configuration on rejection;
installer errors retain existing coordinated rollback. Tests cover supported modes, missing
metadata, VRR/HDR, mode drift and rejected initial capture with prior bytes unchanged.
No schema migration. Rollback restores source; guided mutable enrollment remains future work.
