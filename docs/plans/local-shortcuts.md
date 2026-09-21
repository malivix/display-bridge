# Native macOS Shortcuts integration

Status: signed synthetic integration qualified on the development Mac;
real status projection, action source and optional signed packaging implemented;
isolated companion-process execution passed; production activation remains unqualified.
This extends the [current product plan](ui-feature-priority-review-2026-09-21.md).

## Intended user outcome

Shortcuts offers **Get Display Bridge Status** as a native action with structured
output. It reads the latest local controller observation without opening the
control window, contacting monitors, playing audio, changing settings or creating
controller state. A stale observation must never become a fresh success merely
because the action itself ran successfully.

Use Apple's [AppIntent](https://developer.apple.com/documentation/appintents/appintent),
[AppEntity](https://developer.apple.com/documentation/appintents/appentity) and
[AppShortcutsProvider](https://developer.apple.com/documentation/appintents/appshortcutsprovider)
interfaces. This is an engineering design, not an assertion that the production
app is registered with Shortcuts. No URL listener, HTTP service or arbitrary shell
field is needed.

## Verified build seam

`./scripts/probe-shortcuts` builds a synthetic app under `.local-only`, extracts
metadata, checks that the action/entity/shortcut descriptions exist, verifies its
ad-hoc signature and directly tests its typed action result. It does not install,
open apps, register shortcuts or access real state. It requires Apple silicon and
full Xcode with the metadata processor; it is intentionally outside ordinary tests.

On Xcode 26.4.1, the probe passed targeting macOS 13. The compiler's frontend
constant-value output flag is necessary; the driver flag alone did not produce
the metadata input. The installed protocol manifest is an object containing
`constValueProtocols`; the compiler input expects that list. The metadata tool
requires source and compiler-constant file lists. The script derives toolchain,
SDK and build version locally rather than publishing machine paths or pinning the
developer's Xcode location. This establishes one toolchain, not all supported Xcodes.

The subsequent Shortcuts test discovered the action but could not execute the
ad-hoc-signed app. Targeted system logs reported a missing signing team identity.
A private copy signed with an existing Apple Development identity executed
successfully without executable or metadata changes. Another action read its
typed `State` property as `Ready`. After unregistering duplicate synthetic bundles,
the same test passed with the signed app initially stopped. See the
[integration evidence](../log/shortcuts-signed-execution.md). This establishes one
signed development setup, not all macOS versions or public distribution.

The builder accepts an optional local `DISPLAY_BRIDGE_PROBE_SIGN_IDENTITY`
environment variable for this comparison. It does not discover credentials,
create certificates, change keychain permissions or publish signed artifacts.
Default remains ad-hoc for isolated checks. Keep only one registered probe bundle
for this fixed test identifier when checking launch behavior; stale duplicate
registrations can launch an older app. Never reset the whole Launch Services
database to fix this test.

## Production implementation order

1. Synthetic gate passed on one signed development setup: discovery, execution,
   typed-field consumption, and execution with the app running and stopped.
   Broader OS/distribution coverage remains open. Keep test names synthetic.
2. Add a bounded status projection using the existing `readMenuState` boundary.
   Separate freshness (`fresh`, `stale`, `unavailable`) from controller status,
   pause state, arrangement and recovery. Missing or malformed fields stay
   unknown. Reuse the current 15-second freshness rule; reject boolean, nonfinite
   or future timestamps. Include observation age when valid. Do not return raw
   configuration, errors, logs, identifiers, paths or audio-device names.
3. Integrate the action into the companion app. Keep the menu ownership lock and
   launch behavior intact; a background action must not take ownership from the
   running UI. A native action result is observation, never mutation authorization.
4. Integrate metadata extraction and validation before signing in the real build.
   Resolve full-Xcode versus Command-Line-Tools availability and signed identity
   requirements explicitly; do not
   silently ship an advertised action without metadata or unexpectedly drop the
   project's documented installation support. Include metadata in coordinated
   backup/rollback and package verification, with tests for extraction failure.
5. Update the usage guide only after exact-build Shortcuts discovery/execution
   passes. Record source, package and installed qualification separately.

Rollback: before installation, revert the source/build slice; after installation,
use the existing coordinated snapshot. Do not introduce a new status store or
write to the controller's health file. Ordinary tests must use disposable state.

## Later actions and acceptance

The real source action now exposes six allowlisted fields via the bounded regular-file
reader. Freshness shares the menu's 15-second threshold. Timestamp/boolean types are
checked strictly; missing recovery information stays unknown. Requested pause is
distinct from reported controller state. The latest-status entity re-reads when
resolved; it is not a persistent historical snapshot. The installer can now optionally
package its metadata using an explicitly selected local signing identity, while
preserving the default ad-hoc build. Private production-bundle construction and
isolated metadata/signature rollback have passed. Companion-process execution remains
unqualified; do not advertise it as an available installed action until that passes.

Timed pause/resume follows read-only status. Validate bounded inputs and route
through the existing CLI/controller boundary. Distinguish request acceptance,
pending work, completion and failure; caller timeout does not cancel accepted work.
Named size presets follow separately with fresh context checks and existing
Keep/Revert recovery. Do not add input switching or software disconnection.

Before calling the feature complete, cover fresh, stale, missing, malformed and
unreadable state; FIFO/symlink/oversize rejection; paused and recovering states;
unknown ownership; Shortcuts execution with app running/stopped; action discovery
after package replacement; and metadata-preserving rollback. Native compilation
or a directly invoked `perform()` alone does not satisfy that gate.

## Companion startup checks

The demo reader mismatch is fixed and covered in both command-line test modes;
see [the regression evidence](../log/shortcuts-demo-isolation.md). The next isolated
companion test must cover more than the returned entity: normal startup acquires
the menu lock, probes CLI capabilities, refreshes the menu heartbeat and may request
notification permission. Inspect these effects during warm/cold Shortcuts execution,
and confirm duplicate launches do not steal ownership. Do not claim that a passing
reader self-test establishes background execution behavior. Use disposable state
and a private bundle identity before testing installed activation.

## Companion execution result

The isolated real companion passed warm/cold action execution, structured freshness
consumption, malformed-to-fresh recovery and ordinary duplicate-process ownership.
See [the evidence and isolation changes](../log/shortcuts-companion-execution.md).
Earlier pending integration entries above describe the sequence of work; this is
the current result. Installed production activation, first notification permission
and distribution coverage remain unqualified. Bounded pause/resume is the next
source feature; it must reuse controller command validation.
