# Package optional signed Shortcuts in the companion app

`menu_build.py` now builds a complete menu bundle independently of activation.
`setup_menu.py` retains service ownership, activation and rollback. The default
ad-hoc build requires no metadata tools and records Shortcuts as not packaged.
An explicit `DISPLAY_BRIDGE_MENU_SIGN_IDENTITY` selects the optional signed path.
No identity is discovered automatically or stored in source/configuration.

The optional build emits multi-file constants, extracts App Intents metadata and
checks the expected action and six fields before signing. Strict bundle signature
verification and a team-identity check must pass before activation is possible.
Invalid metadata or a source change blocks signing. Signing errors do not echo
the supplied identity or fall back to ad-hoc. Preflight reports optional tool
readiness separately and does not attempt signing.

The ordinary test runner discards inherited signing selections. Tests that need
them set synthetic values explicitly. Signed demo actions now return unavailable
synthetic status rather than reading real controller files.

Validation:

- `./scripts/verify --native` passed: 305 Python tests, all native builds/self-tests
  and publication checks. A final Python-only preflight import-error guard was
  followed by another passing `./scripts/test` run.
- New tests cover default versus signed construction, metadata-before-signing
  ordering, incomplete metadata, missing signature team, invalid/failed identity,
  source drift and optional read-only preflight without identity disclosure.
- The production builder created a private development-signed menu bundle from
  current source. Native self-tests, full metadata validation and strict signature
  verification passed. It was not opened or activated.
- An isolated copy of that bundle was snapshotted, its metadata damaged, then
  restored through the existing deployment code. Its complete payload hash matched
  the original and strict code-signature verification passed afterward.

The rollback exercise covers bundle contents, not service activation, abrupt
termination or power loss. Companion-process Shortcuts execution and interaction
with the menu ownership lock remain unqualified. The earlier synthetic app's
success is not proof of those paths. No installed service, monitor or configuration
was changed; all signed artifacts and signer information remain private.
