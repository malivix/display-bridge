# Menu source boundaries

The adversarial maintainability review found the menu had grown to 1,918 lines, combining
process execution, presentation policy, modal controls, application wiring and self-tests.
Split these responsibilities into ordinary Swift sources under native/menu, with main.swift
as the sole entry point. Keep the installed executable and all CLI flags unchanged.

Use one MENU_SOURCES inventory in release_manifest.py for setup_menu, installer prerequisites
and native verification. Existing recursive source hashing includes the new paths. Remove
duplicated preset action lists in favor of one group definition shared by command preflight,
availability labels and demo capability fixtures. This is not a new hardware-policy layer.

Preserve all existing native tests, then build the multi-file demo and exercise report/preset
navigation. Compare function bodies across the move; only intended command-group deduplication
and phase-entry wrappers should differ. No installed configuration migration. Rollback means
restoring the old source/build entry; the installed binary name is unchanged.
