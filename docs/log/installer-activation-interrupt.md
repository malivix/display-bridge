# Interrupt installation after release activation

The isolated probe runs the real installer entry point with a disposable home and
strictly stubbed external commands. Build commands create synthetic helper files;
service commands only record events. Unexpected commands fail instead of executing.
The barrier is after publishing the release pointer, helper links and launcher,
before inspecting or modifying configuration.

The parent confirms that the new release and launcher are active, sends SIGINT to
that child process, and waits for the real KeyboardInterrupt recovery path. The
probe checks prior release/launcher restoration at the attempted service restart,
not just after the installer exits. The parent then verifies saved file bytes,
prior controller linkage, absence of added helper entries, failed/interrupted
progress with completed-unverified recovery, and independently acquirable locks.
The old menu bundle is included in the snapshot but has not yet been replaced at
this barrier. No new rollback implementation or persistence schema was needed.

The focused subprocess test passed, followed by the ordinary verification suite
with 306 Python tests. No native runtime source changed. The probe has bounded
startup/exit waits and kills only its own child on test failure. All state is removed
with its temporary directory. Real service, monitor and audio operations are absent.

This advances caught-interruption coverage for one full-installer boundary. SIGKILL,
power loss, post-configuration and companion replacement boundaries, actual service
restarts and physical recovery remain unqualified. It is not a claim of transactional
installation across all files and services.
