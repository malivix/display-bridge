# Separate native menu responsibilities

The requested [strict review](https://raw.githubusercontent.com/cursor/plugins/refs/heads/main/cursor-team-kit/skills/thermo-nuclear-code-quality-review/SKILL.md)
identified a 1,918-line menu source containing process execution, report formatting, dialogs,
application orchestration and self-tests. The source is now split by those responsibilities
under `native/menu/`; the app controller is the largest file at approximately 765 lines.
One `MENU_SOURCES` inventory drives compilation, installer prerequisites and verification.
Preset command groups now have one definition shared by compatibility and availability checks.
The executable name, command flags, installed inventory and persisted schemas are unchanged.

Validation: 233 Python tests, native builds and native self-tests passed. A declaration
comparison retained all prior top-level declarations without duplicates; the preset-window
body was unchanged. The rebuilt isolated demo passed its private named-pasteboard check.
Overview/Displays/Controls navigation and the Largest brightness-preset dialog were inspected;
the dialog labels and all four actions were visible without clipping. Demo mutations are blocked.
No hardware settings or installed services were changed.

This addresses source boundaries, not every maintainability issue. App orchestration still
contains a long result-dispatch chain, and several reports use loosely typed dictionaries.
For example, monitor result presentation defaults an unknown monitor to BenQ and an unknown
feature to volume. Those fallbacks need a validated response boundary before adding further
control types. Full VoiceOver, light appearance and physical qualification remain open.
