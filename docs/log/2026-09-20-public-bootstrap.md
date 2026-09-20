# Public repository bootstrap

## Objective and scope

Publish a reviewed, privacy-safe source snapshot with a small engineering workflow.
Keep the existing installed controller and local evidence untouched. Use Privix's approach
of a short instruction map backed by checks, without importing its unrelated platform rules.

## Changes

- Added canonical AGENTS guidance, CLAUDE import, architecture/development/security docs,
  qualification boundaries, Conventional Commit hooks, staged/history privacy checks, and CI.
- Kept historical notes, raw evidence, exports, and compiled files outside public tracking.
  Used a GitHub no-reply commit identity and retained upstream licensing/provenance.
- Removed the development monitor serial from model lookup and upstream example UUIDs from docs.
- Centralized installed module/helper inventory; deployment and health now share it.
- Centralized namespace conflict checks for both controller and menu installers.
- Isolated tests from the real home directory and fixed a unit test using the live DDC lock.
- Added a fresh input check between rotation preflight and ordinary layout mutation.
- Corrected DDC packet lengths for zero checksums and stale buffer contents.
- Restricted newly installed state directories to the current user.

## Validation

The full isolated suite passed 160 Python tests. Native checks compiled both Swift helpers,
all three Objective-C helpers, and vendored m1ddc, then passed the DDC transport and menu
policy self-tests. The new zero-checksum regression failed against the original transport
before the fix. Staged privacy checks and Gitleaks found no flagged content. Static checking
for undefined names and syntax errors passed. Raw command output remains local.

Publication/history checks and remote CI are recorded separately after execution. Physical
hardware tests and reinstallation were not performed for this public-source revision.

## Remote qualification follow-up

The first GitHub CI run failed during preview setup. A deterministic regression using a
fractional monotonic clock reproduced the same rejection: subtracting timestamps could
round a valid 120-second lifetime slightly above 120. Deadline validation now compares
against `started + 120`, preserving the limit without a fuzzy tolerance. The regression
failed before the fix. The suite now contains 161 Python tests.

An additional isolated publication test proved that private staged bytes are rejected even
when the working-tree file has already been cleaned. Personal agent override files and
runtime-state filenames are now explicitly blocked as well. Initial history scanning passed;
GitHub secret scanning, push protection, and private vulnerability reporting are enabled.

Hosted verification [run 35524216899](https://github.com/malivix/display-bridge/actions/runs/35524216899)
passed all 161 Python tests, native builds/self-tests, staged/history scans, and commit-subject
checks. Its checkout-runtime deprecation warning prompted an update to the SHA-pinned
checkout v7.0.1 action (Node 24). No deployed controller changes were made.
