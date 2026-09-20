# Preset availability before interaction

Controls now displays a last-check summary and explicit Check preset support button.
A bounded worker-queue probe runs once at launch; unknown or unsupported commands leave
preset controls disabled. Rechecking clears old support while checking. The size chooser
also disables unsupported named preset save/removal and includes update guidance. Ordinary
size preview and recovery remain independent. No automatic repeating probe, persistence,
or hardware polling was added. Command-time preflight remains authoritative after upgrades
or a long-open dialog. The capability parser is shared by discovery and preflight.

Validation: `scripts/verify --native` passed 221 Python tests and native self-tests,
including unknown/checking/partial availability labels and the existing no-dispatch
compatibility regressions. A rebuilt hardware-free demo with the older-controller fixture
showed the explanatory text and disabled brightness entry at Largest text size without
clipping. Opening the size chooser confirmed Preview remained enabled while Save/Remove
were disabled and the compatibility note was present. These observations do not establish
VoiceOver completeness, installed upgrade behavior, or physical hardware results.

No installed bundle or controller was changed. Rollback restores the prior menu source;
there is no stored capability cache to migrate or remove.
