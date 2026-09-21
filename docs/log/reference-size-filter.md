# Reference-first size matching

The size chooser now filters existing qualified options by intent: all sizes, keep BenQ
size while adjusting PG, or keep PG size while adjusting BenQ. It recognizes only the
controller's existing matching keys, not display labels or named presets. Selected rows
map back to original option indices so the existing fingerprint and preview command stay
paired. An empty group disables Preview and explains how to return to all options.
Filtering never changes display settings or creates a new candidate mode.

Validation: final `scripts/verify --native` passed (290 Python tests and native checks).
Native regressions cover both references, original indices, unknown/empty groups and
excluding label-only or named-preset lookalikes. Initial compilation caught an overbroad
edit affecting another dialog; it and unused fields were removed before final verification.
The isolated demo showed the BenQ-reference group selecting a synthetic PG-only size
change, and the empty PG-reference group disabling Preview with an explanation. Escape
returned without applying. The demo predates removal of unused fields in unrelated dialogs;
the tested size chooser is unchanged. Physical matching and Largest-text inspection remain
separate qualification; this turn used Standard text. No installation or hardware changes.
