# Structure and reliability review

## Scope

Continue the adversarial review from the public bootstrap. Keep the installed setup running;
make source-level corrections and qualify them with isolated and hosted checks.

## Findings and fixes

- Native sources and all tests were mixed into the root. Moved them into `native/`,
  `tests/unit/`, `tests/native/`, and `tests/hardware/`. Flat runtime modules stay at root to
  match the installed release; deployment paths did not change.
- The installer maintained its own test list and ran it against the actual home directory.
  `scripts/test` now owns isolated discovery and is used by installation and verification.
  The installer is import-safe, supports `--help`, and rejects unsupported hosts before writes.
- Menu subprocess reading could wait forever. A native regression failed against the old
  reader; the new implementation caps time at 45 seconds and output at 1 MiB. Native tests
  exercise normal completion, command failure, timeout, and excessive output without hardware.
- Oversized request timestamps raised overflow before the preview service reached rollback.
  A deterministic test reproduced this; the existing overflow-safe numeric validator is now
  shared rather than duplicated. Malformed requests no longer block timeout restoration.
- Restoring a backup with a missing payload could modify earlier files before failing.
  Reproduced this with temporary files. All payloads are now preflighted, and new backups
  include checksums for ordinary files and menu bundle contents. Rollback also rejects
  metadata pointing outside this installation before stopping services.
- Controller rollback omitted the companion app. New snapshots include it and both
  LaunchAgents. Rollback coordinates both services, undoes failed verification, and rejects
  older snapshots without menu coverage. Isolated fake-launchctl tests verify these paths.
- Controller/menu versions were duplicated. `release_manifest.py` now owns version 2.10.2
  and the menu build. This revision is unreleased and has not been installed on hardware.

## Documentation and CI

README now separates installing, using, and developing. Dedicated guides cover input mapping,
rotation, upgrades, stopping services, troubleshooting, privacy, and the source map.
CI adds Python 3.10 and 3.14 unit jobs, while native checks remain on Apple-silicon macOS.
Actions are pinned and credentials remain read-only. Local checks passed 172 unit tests;
final native/publication/hosted results are reported with the completed commit.

## Limits

Power-loss-atomic installation and physical qualification remain outstanding. A menu command
being terminated does not undo daemon work already queued. Backup checksums detect accidental
payload changes; they are not signatures or protection against the same user editing metadata.
No real monitor, audio route, installed service, or private configuration was modified here.
