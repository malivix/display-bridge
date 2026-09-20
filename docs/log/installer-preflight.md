# Read-only software prerequisite report

`install.py HOST --preflight` now checks platform/macOS/Python requirements, source entry
points, bounded SDK/compiler discovery and known service namespace conflicts before any
installer mutation. It emits structured status and guidance without discovered local paths,
and returns nonzero for unmet prerequisites. Capture flags are rejected in preflight mode.
The normal installer path is unchanged; this report does not authorize deployment or
qualify hardware, saved configuration, pending recovery or permissions.

Validation: `scripts/verify` passed 226 isolated tests. New cases cover success without state
creation/builds, unsupported platform, capture-option conflicts, incomplete source and SDK
discovery timeout. Running `python3 install.py A --preflight` on the development Mac returned
prerequisites-ready for the six software checks. No helpers were built or invoked, and no
installation/service/hardware action occurred. Native tests were not repeated for this
Python-only installer addition. There is no persisted state to migrate or roll back.
