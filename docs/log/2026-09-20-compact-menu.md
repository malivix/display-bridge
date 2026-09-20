# Compact menu and retained advanced commands

The main menu now presents status/freshness, each monitor's ownership, selected output,
Open Display Bridge, Pause/Resume and Quit. Preview confirmation/restoration actions remain
at the top level when relevant. Advanced retains timed pause, rotation, audio preferences,
monitor adjustments, size choice, notifications and reports. Window title uses Display Bridge;
no bundle/defaults/service migration is involved.

Menu-open tracking uses a set of open menu identities, so closing a nested menu cannot
incorrectly clear the parent's open state and allow timer-driven reconstruction mid-selection.
No controller command or ownership policy changed.

Validation: 192 Python tests and native builds/self-tests passed. Fresh demo accessibility
inspection confirmed the compact menu, Advanced command inventory, and return from nested
menus. After switching the demo to both-away and reopening, ownership updated to Mac B and
monitor adjustments/preview were disabled. Menu screenshot capture did not return an image;
menu evidence is the live accessibility tree, not a visual or VoiceOver qualification.
No installed app, hardware settings or permissions were changed.
