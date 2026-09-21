# Implement the real Shortcuts status action source

Added `ShortcutStatusSnapshot` and the typed `Get Display Bridge Status` App Intent.
The action reads the existing local health/control files through `readMenuState`;
it never contacts monitors, runs controller commands, creates state or plays audio.
The source inventory includes both new files for compilation and fingerprinting.

The result exposes observation freshness/age, reported controller state/arrangement,
requested pause state and reported recovery state. It contains no raw errors,
paths, device IDs, input values or speaker names. Freshness describes recency, not
health or hardware authorization. The shared menu threshold remains 15 seconds.
Known controller states include preview failure/restoration states; unknown status
strings do not become a valid observation. Missing recovery flags remain unknown.
Resolving the `latest` entity later obtains a new observation, not historical state.

Validation:

- `./scripts/verify --native` exited 0 on the final runtime sources: 297 Python
  tests, native builds/self-tests and publication checks passed.
- New native checks cover fresh/stale boundary, future/nonfinite/boolean timestamps,
  malformed states, unknown arrangement, pending/unknown recovery, numeric boolean
  rejection, timed pause expiry and private-field exclusion.
- Disposable-file checks cover missing state without directory creation, malformed
  JSON, oversized health, and control symlink/FIFO rejection. The typed App Entity
  is tested using a synthetic snapshot, without reading the installed controller.
- A private multi-file build extracted the actual production action metadata:
  expected action/entity, six result properties and five enums. No app was launched.

Compilation initially exposed cross-file synthesized-protocol requirements; the
plain enums now declare `CaseIterable` and `Sendable` in their own source file.
Multi-file metadata extraction also needs a constant-output map and the driver's
`-emit-const-values` flag. These findings must carry into packaging. One verification
attempt overlapped a final source edit and was rejected by the compiler; the final
reported run used stable sources and completed successfully.

This is source delivery, not completed feature deployment. The installer still
needs signing-aware metadata packaging, and the real companion app needs execution
and ownership-lock qualification. Only the separate synthetic app has passed
Shortcuts execution so far. No installed service or user configuration was changed.
