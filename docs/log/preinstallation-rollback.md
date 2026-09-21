# Preinstallation rollback qualification

An isolated first-install scenario confirms that restoring a snapshot with absent launcher,
app and LaunchAgents stops both loaded services without trying to bootstrap missing agents.
The undo snapshot restores the installed files in a files-only round trip. Existing service
policy remains unchanged: rollback restarts previously loaded services whose agent files remain.

The final message now distinguishes restored files from the number of restart commands
that succeeded. It no longer leaves the service outcome implicit. Usage documents the
zero-restart case and separates command success from physical behavior.

The new regression failed on the old summary, then passed with the clarified result and
the complete undo round trip. `scripts/verify` passed all 293 Python tests and privacy checks.
No native changes or real launchctl/hardware calls. These tests qualify temporary file and
fake service-manager behavior, not a physical uninstall or power-loss-safe recovery.
