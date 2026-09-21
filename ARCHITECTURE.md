# Architecture

`display_snapshot.py` validates stored rotation profiles before startup/activation and
provides read-only mode reports. Profile validation does not replace fresh hardware guards.

`display-auto.py` owns polling, debounce, profile reconciliation, rotation, and the mutation
lock. `audio_policy.py` selects a route; `recovery_state.py` bounds retries.
`persisted_state.py` and recovery journals preserve intent across interrupted operations.
`command_results.py` records the latest observed settings requests and outcomes; it is
observability, not an execution queue. Damaged result history is preserved and reported,
without resetting recovery or replaying actions.

`native/menu/` contains the per-user menu app. `MenuApp.swift` owns AppKit orchestration,
`Commands.swift` bounds process execution and defines preset capability groups,
`Presentation.swift` formats controller observations. `SizeChooser.swift` owns size comparison,
reference filtering and modal validity; `PresetWindows.swift` owns saved-preset dialogs and
panel keyboard routing.
`SelfTests.swift` holds isolated checks; `main.swift` selects test entry points or starts the app.
The app submits controller commands and reads health;
it does not maintain an independent hardware state machine. CLI execution has bounded time
and output, so a stalled child does not permanently disable menu actions. `observability.py`,
`health_check.py`, and `ddc_log_report.py` report state and timing locally.

`scaling_choices.py` qualifies modes, `scaling_proposal.py` creates candidate configuration,
`scaling_preview.py` journals reversible intent, `preview_runner.py` drives the state machine,
`preview_hardware.py` checks ownership and hardware, and `preview_service.py` serializes requests.
Confirmation preserves the original request time while respecting the hard recovery deadline.

Native boundaries:

- `native/display-layout.swift`: CoreGraphics layout and mode operations.
- `native/display-audio.m`: CoreAudio selection and targeted sample-rate recovery.
- `native/display-rotate.m`: rotation.
- `native/display-mode-info.m`: private mode metadata, which can become unavailable.
- `vendor/m1ddc`: pinned DDC implementation with local validation and retry fixes.

`install.py` builds locally, stages immutable runtime files, backs up state, activates a
release, and coordinates menu installation. `rollback.py` restores coordinated controller/menu snapshots. Backup contents are checked
before mutation; a failed post-restore check restores the pre-rollback snapshot.
`release_manifest.py` defines the version and installed inventory used by installation and health checks.
The checkout is independent from the running installed release. `install_progress.py` records the latest attempt under the installer lock and provides a
bounded, read-only status projection for both the checkout and installed controller. It never authorizes, resumes or retries installation.

Stored display keys and audio UIDs belong only in per-machine runtime configuration.
Model vendor/product identifiers in source select supported panel specifications; they are
not authorization for mutations. Mutation authorization also requires enrolled device identity.

`native/setup/` is an independent graphical installer front end. `setup_gui.py` builds a private
app containing a clean committed source snapshot. It invokes the existing installer for software
review and explicit activation; the menu app is not the installer's parent. `SETUP_SOURCES` defines
its build inventory. The front end owns presentation/process observation, not hardware mutations.
