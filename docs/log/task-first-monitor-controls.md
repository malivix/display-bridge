# Put monitor adjustments before support details

The compact Controls tab previously showed compatibility prose before the unavailable
reason and brightness/volume actions. At Largest text and the minimum window size,
ordinary adjustments were outside the initial viewport.

Reordered the existing controls: selected monitor, availability, read action, paired
brightness and volume steps, results and presets. Support information and its refresh
action now sit under a keyboard-operable Show support details checkbox. The control
identifiers, dispatch paths, capability checks and ownership guards are unchanged.
Volume buttons retain explicit monitor-speaker accessibility labels.

Validation: `scripts/verify --native` passed, including 279 Python tests and native
builds/self-tests. A separate demo compiled from this working tree showed all adjustment
buttons at Largest text in the 600 × 480 minimum window. The stale scenario showed its
reason before disabled adjustments. Support expanded and collapsed; Tab reached the
monitor selector, presets and disclosure while skipping disabled adjustments, and Space
collapsed the disclosure while retaining focus. No hardware commands or installation ran.

This qualifies these synthetic layout/keyboard cases, not full VoiceOver or light-mode
coverage. Footer simplification, clearer readback presentation and the remaining items in
the [delivery plan](../plans/ui-feature-follow-up-2026-09-21.md) remain open. Existing source
and installed controller remain separate until coordinated deployment is eligible.
