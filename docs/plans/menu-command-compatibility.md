# Menu command compatibility

New preset commands must be checked against the command executable before dispatch.
Add a read-only, configuration-independent protocol report derived from argparse's
accepted action list. The menu checks this report on its worker queue for size-preset
save/removal and brightness commands. Missing, invalid, timed-out or unsupported reports
stop dispatch and explain that the menu and controller need a coordinated update.

Keep legacy status, recovery and other existing commands available on older installations.
Do not infer support from the shared version label or cache across upgrades. This is CLI
capability discovery, not daemon/build attestation; existing installer and manifest checks
remain necessary. No persistent state is added. Rollback restores the previous sources.
Verify that rejected probes never dispatch the requested action and that legacy recovery
is not prevented by a missing report. Native tests use an injected runner; CLI tests use
an empty disposable home and prohibit hardware/configuration access.
