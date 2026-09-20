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
Mac B deployment, concurrent controllers, sleep/wake, headset transitions, and all cable/
firmware combinations remain unqualified. Raw historical evidence stays local for privacy.

A release should record the exact revision, OS, model/connection categories, test commands,
physical outcomes, and unresolved cases without publishing serials, UUIDs, local paths, or logs.

## Known engineering limits

- New snapshots include controller files, configuration, the companion menu bundle, and its
  LaunchAgent. Older snapshots without companion coverage are rejected. Coordinated rollback
  has isolated tests; physical rollback qualification is still pending.
- Installer backups recover caught failures, but installation is not a power-loss-atomic
  transaction across configuration, LaunchAgents, and the menu bundle.
- Menu commands have a 45-second deadline and a 1 MiB output cap. Terminating the CLI does
  not cancel work already queued in the daemon; inspect status before retrying.
- Read/validate/write ownership checks narrow hardware races but cannot atomically lock a
  physical input switch made on another computer.

These do not establish a production-ready release. They remain explicit follow-up work;
this repository remains a hardware-specific experimental controller.
