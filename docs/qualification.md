# Qualification boundaries

The pre-publication controller was used on one Apple-silicon Mac with PG42UQ and RD280UG.
The user reported usable desktops for both-away then PG-first and both-away then BenQ-first
returns. Earlier audio recovery and ordinary switching were also physically confirmed.
These are observations from one setup, not cross-device compatibility guarantees.

The public-source namespace was migrated on Mac A for source revision 3dd6809 (2.10.2).
A verified private backup was retained. Saved identities/layout/audio/rotation settings were
compared before and after, and installed hashes, ready heartbeat, both local input reads,
and fixed-120/HDR-off mode checks passed. The newer UI was visually checked in a synthetic
demo; the computer-use adapter retained the old installed bundle identity. This is partial
upgrade qualification, not a new physical switching or listening qualification.
Concurrent controllers, sleep/wake, headset transitions, and all cable/firmware
combinations remain unqualified. Raw historical evidence stays local for privacy.

Mac B was first deployed for source revision d99080a (2.11.0) on macOS 26.7 and an
Apple M4 Pro laptop, with PG42UQ on HDMI 2 and RD280UG on its DisplayPort input. Capture
had to be corrected first: the RD280UG publishes a different EDID product code per input,
so the single hardcoded BenQ identity matched Mac A only. After that, the baseline captured,
the installer's four layout transitions passed, both services reached a ready heartbeat, and
host enrollment, configuration, installed hashes, both local input reads, both saved
fixed-120/HDR-off modes, the menu app and build agreement all report ok. One live transition
was then observed: the PG moved to the other host's input, the controller selected the BenQ
profile, and audio followed to the RD280UG.

Both orientation profiles were then captured on Mac B and automatic rotation is enabled
there. The landscape capture succeeded against the running controller; the portrait one
needed two failed attempts and the controller stopped by hand before the cause was
identified. Each attempt rolled back and left the installation working. The installer now
re-requests a pending recovery after it replaces the baseline, so that manual step is no
longer required; that path has unit coverage but has not been re-run against hardware.

That is a first deployment, one observed transition and a completed rotation enrollment, not
a Mac B switching, listening or rotation qualification. Listening, both-away and both-return
orders, sleep/wake, and an actual sensor-driven rotation have not been exercised on Mac B.

A release should record the exact revision, OS, model/connection categories, test commands,
physical outcomes, and unresolved cases without publishing serials, UUIDs, local paths, or logs.

## Known engineering limits

- New snapshots include controller files, configuration, the companion menu bundle, and its
  LaunchAgent. Older snapshots without companion coverage are rejected. Coordinated rollback
  has isolated tests; physical rollback qualification is still pending.
- Installer backups recover caught failures, but installation is not a power-loss-atomic
  transaction across configuration, LaunchAgents, and the menu bundle.
  An isolated SIGKILL test before/after release-pointer replacement verifies retry and
  snapshot restoration at that single boundary. It does not qualify abrupt termination
  across the full installer or power-loss durability.
  A separate full-entry-point SIGINT test now interrupts after release/launcher
  activation and before configuration inspection. With external commands stubbed,
  it verifies coordinated snapshot restoration before the old-service restart,
  removal of new helper links, released locks and an interrupted recovery report.
  This covers caught Ctrl+C at that boundary, not SIGKILL, menu replacement,
  service readiness, every commit phase or physical recovery.
- Menu commands have a 45-second deadline and a 1 MiB output cap. New preset commands
  first use a separate capability probe capped at five seconds and 16 KiB. Terminating the CLI does
  not cancel work already queued in the daemon; inspect status before retrying.
- Read/validate/write ownership checks narrow hardware races but cannot atomically lock a
  physical input switch made on another computer.

These do not establish a production-ready release. They remain explicit follow-up work;
this repository remains a hardware-specific experimental controller.

Stored rotation profiles are now validated at startup and again before active-profile
replacement: enrolled pair, orientation, dimensions, native numeric fields and sensor
mapping. Disabled partial enrollment is supported; malformed supplied profiles are rejected
and preserved. A local saved-configuration compatibility check passed during development.
This is structural validation, not proof that mode IDs remain available or rotation works
on a new OS or monitor connection. Native preflight and physical qualification remain needed.
