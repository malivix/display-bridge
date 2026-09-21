# Give the selected tab more space

The persistent footer previously repeated size selection and support actions on every
tab, reducing the visible content at large text sizes. Moved Preview size to Displays
and More controls, Health and Diagnostics to Details. Pause/Resume and interface text
size remain global. The global Keep/Revert row appears during an active preview; its
existing freshness, token and deadline guards are preserved.

Validation: `scripts/verify --native` passed, including 279 Python tests and native
builds/self-tests. A separately compiled hardware-free demo was inspected at Largest
text in the minimum 600 × 480 window. Audio now shows its listening check and manual
preservation action in the initial ready viewport. Displays shows both refresh and
size preview; Details exposes the relocated support buttons. In the synthetic active
preview scenario, Keep/Revert remained visible while viewing Audio. Command 2/3/4
navigation worked. Synthetic preview time is static and does not qualify real deadlines.

No installation, monitor mutation or playback ran. Full keyboard/VoiceOver and light-mode
qualification remain open. Updated usage instructions. Coordinated deployment remains
separate; rollback uses the prior controller/menu snapshot.
