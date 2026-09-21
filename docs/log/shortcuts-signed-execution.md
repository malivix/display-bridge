# Qualify synthetic Shortcuts execution

The action from the native probe is now verified in the Shortcuts app on the
development Mac. This is not production status integration or release qualification.

## Failure and controlled comparison

The ad-hoc-signed action appeared in the action library but execution failed with
Shortcuts unable to communicate with the app. Targeted logs reported a missing
signing team identity and an Apple Events connection failure. Signing identity,
startup handling and stale registration were the candidate causes.

A private copy of the same binary and metadata, signed with an existing Apple
Development identity, executed successfully. No startup code, entitlements,
keychain permissions or controller files were changed. The result supports signing
identity as the cause on this setup; it is not a universal compatibility claim.

## Observed execution

- The action was found by searching the action library. An existing empty shortcut
  was inspected without editing it, then duplicated into a separately named
  synthetic integration test. No existing user shortcut was run.
- The signed action returned its synthetic entity in Shortcuts.
- A Get Text from Input action selected the entity's `State` property and produced
  `Ready`. This verifies typed-field consumption rather than only a display label.
- The first cold-launch attempt selected an older ad-hoc probe sharing the test
  bundle ID. Only duplicate synthetic probe registrations were removed; no global
  Launch Services reset occurred. After registering the signed probe, Shortcuts
  launched that exact executable from a stopped state and again returned `Ready`.
- Private captures 32–33 record signed execution and typed cold-start output.
  Logs, signatures, certificate identifiers and generated bundles remain private.

The dedicated synthetic shortcut remains available for follow-up integration work.
It contains only the probe and text-conversion actions. No actual status, monitor
access, playback, controller installation or public upload was involved.

## Reproducible builder and remaining work

The optional `DISPLAY_BRIDGE_PROBE_SIGN_IDENTITY` environment variable lets a
developer explicitly select a local signing identity. The builder still defaults
to ad-hoc and never discovers or creates credentials. Signing failure does not
fall back to ad-hoc or print the supplied identity.

Builder checks passed for default ad-hoc and explicit development signing, including
metadata, signature and direct intent self-tests. An invalid synthetic identity
failed with the intended message and without printing its value. These command
checks do not themselves exercise Shortcuts UI registration or execution.

Production still needs a bounded real-state projection, menu-process integration,
explicit build/signing capability reporting, packaging and rollback checks. Keep
ordinary ad-hoc installation supported; do not advertise native Shortcuts where
its signing and metadata requirements are unmet. Cross-version and distributed
build qualification remain open.
