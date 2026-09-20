# Contextual recovery action

Added one adaptive action inside Overview's Recovery group. Fresh unavailable/error
state offers health inspection; a repairable size journal offers its token-bound retry;
exhausted audio recovery offers repair only through the existing audio guard. Ordinary
switching and automatic retries do not gain a repair prompt. Busy state disables the
button, and click-time comparison rejects stale state or a changed preview token.
A rejected click explains that the state changed without substituting another mutation.

Implementation follows milestone 1 in ui-next-milestone.md. No backend, persistence or
hardware-policy changes. Existing command boundaries remain authoritative. Rollback
requires a compatible prior menu binary; no recovery journal is removed.

Validation: 210 Python tests and all native builds/self-tests passed. After the final
feedback-text edit, rebuilt the menu and reran its self-tests. New cases cover stale
status, manual preservation, paused controls, unreadable controls, busy commands,
ordinary switching, missing tokens and changed tokens. In the isolated demo, confirmed
no action when healthy, Repair audio when exhausted, Largest text at the minimum window,
and that clicking repair reaches the demo's blocked hardware-command boundary.
Full keyboard/VoiceOver and physical recovery qualification remain pending. Not installed.
