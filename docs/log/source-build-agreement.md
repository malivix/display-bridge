# Report source build agreement

New installations record a portable controller/menu source fingerprint in manifest.json and the
menu's signed Info.plist. The menu heartbeat carries its reported value. Setup/Health now adds
Reported build agreement: equal metadata, mismatch, malformed or legacy/missing metadata.
A shared version number alone no longer supplies the missing source-identity information.

The fingerprint covers RUNTIME_MODULES and MENU_SOURCES, includes portable names and content
hashes, and excludes checkout paths and runtime configuration. Menu compilation checks that
those sources did not change across the build. This metadata is not binary attestation and
does not cover non-menu native helper source; existing installed-file hash and heartbeat checks
remain independent. No hardware authorization depends on fingerprint equality.

Tests verify checkout-location independence, controller/menu content sensitivity, runtime-state
exclusion, missing source failure and all health-report cases. All 261 Python tests passed;
native builds/self-tests passed for the heartbeat change. Staged privacy checks passed. No
installation occurred, so existing deployments will continue to lack this metadata until a
coordinated update. Physical and complete upgrade qualification remain separate.
