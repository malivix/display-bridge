# Report source build agreement

Hash the sorted portable names and SHA-256 digests of RUNTIME_MODULES and MENU_SOURCES. Embed
this identity in the installation manifest and signed menu plist; report the latter through
menu heartbeat. Reject source changes detected across menu compilation. No Git dependency,
absolute path, hardware identity or runtime configuration participates in the fingerprint.

Health/setup distinguishes equal metadata, mismatch, malformed and missing/legacy metadata.
Retain independent heartbeat freshness and installed-file hash checks; fingerprint equality
is not binary attestation, a fresh-heartbeat assertion or physical qualification. No new
hardware/authorization gate. Old installations report unavailable rather than invented agreement.

Verify portability/content sensitivity and all report cases with isolated tests, run native
checks for the heartbeat field and stage/privacy review. Installation remains separate and
rollback uses existing coordinated snapshots; no live deployment for this slice.
