# Consistent demo snapshots

Derive synthetic display inputs, owners and layout from the same demo state used by Overview.
Add single-local scenarios in both directions. Show no available measurements for unknown
ownership or remote monitors; away does not imply a new mirror configuration. A refreshed
ready snapshot must agree with Overview. A previously retained snapshot must still warn after
scenario changes, and the failed-refresh scenario must preserve the prior reading.

No installed state or hardware calls. Test the rendered report boundary across ready,
single-local, away and unknown scenarios. Build/check native code and visually refresh the
isolated demo. Rollback is source-only; no runtime migration or installation.
