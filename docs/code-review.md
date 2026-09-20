# Adversarial initial-publication review

Reviewed the initial public snapshot using the requested
[Thermo-Nuclear Code Quality Review skill](https://raw.githubusercontent.com/cursor/plugins/refs/heads/main/cursor-team-kit/skills/thermo-nuclear-code-quality-review/SKILL.md).
Scope: controller/policy, preview persistence and orchestration, native helpers, menu,
deployment, tests, vendored DDC patch, publication tooling, and documentation.
This is an engineering review, not an independent security certification.

## Blocking findings addressed

1. **Runtime inventory duplication could leave upgrades or health checks incomplete.**
   Replaced repeated hand-maintained installation/backup/hash inventories with
   `release_manifest.py`, shared by installation and health checking. Source hashing now
   discovers top-level source files rather than relying on another stale list.
2. **Service namespace change could create competing controllers/menu apps.**
   Moved conflict detection into the existing deployment boundary and applied it to both
   entry points. Tests cover controller and menu conflicts, preserving original plists,
   malformed unrelated plist shapes, and compatible services. No automatic migration claim.
3. **A unit test accessed the real service lock.** The original full test run failed when
   the running controller held it. The test now owns a temporary directory; the canonical
   suite also runs with an isolated child-process home to protect live state.
4. **Layout mutation could follow a stale input observation after rotation preflight.**
   Added a fresh ownership check before ordinary layout application. Regressions verify
   the stale operation cannot reach layout/audio work; timing expectations include that read.
5. **DDC write length depended on nonzero buffer contents.** An intercepted transport test
   reproduced truncation of a zero checksum. Packet-header length replaces the byte scan,
   deleting the inference helper. The test does not send a hardware command.
6. **Publication could include local evidence, exports, identifying source constants, or
   private commit email metadata.** Public files are explicitly staged, private material is
   ignored and rejected by checks even if force-added, serial-specific lookup is removed,
   and index/history checks complement redacted Gitleaks scans. Commit identity uses noreply.

## Structural judgment and limits

The preview journal/runner/hardware separation has distinct responsibilities and supports
crash recovery tests; collapsing it would mix durable intent with hardware side effects.
The controller remains dense, and the menu uses loosely typed JSON at its process boundary.
Further cleanup should extract cohesive policy with behavioral tests, not distribute mutable
state across new pass-through modules. No source file crosses 1,000 lines in this snapshot.

Manual rollback does not include the menu app, installation is not power-loss atomic across
all components, and the menu lacks an overall child-process watchdog. These are documented
in `docs/qualification.md`. They block claims of universal or production-complete reliability;
they are not hidden behind passing unit tests. Native compilation is not physical qualification.

Public-source readiness is assessed separately from deployment readiness. Publication checks
are heuristic: reviewers must still inspect the exact staged filenames, content, permissions,
and commit metadata. No raw diagnostic bundle or private development history is included.
