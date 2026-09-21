# Add an independent guided setup window

`setup_gui.py` builds a separate AppKit application. Real builds require a clean trusted Git
checkout and bundle a committed source snapshot with read-only source files. Extraction rejects
traversal, links and special files. Demo builds allow UI inspection of uncommitted work but
never dispatch the installer. Generated apps remain private and ignored.

The window offers explicit host selection, validated software prerequisite review, preparation
confirmation, Install / upgrade, last-attempt inspection and private-log access. Role changes
invalidate review/preparation. The existing installer owns hardware checks, mutation locks,
backups and rollback; baseline replacement and rotation capture are not exposed here.

The front end remains separate from the menu app replaced during installation. It uses a regular
private output file, holds ordinary Close/Quit while its child runs, and correlates progress by
PID, host and start time. Missing matching progress stays unknown. It does not kill an installer
on a presentation timeout. Forced termination, power loss, prolonged hangs and actual deployment
remain unqualified; this is not a new crash-recovery mechanism.

Validation: 279 Python tests and native builds/self-tests passed. The setup model covers explicit
role/review/preparation gates, invalidation and malformed prerequisite reports. Snapshot tests
cover unsafe paths, read-only files and dirty-checkout rejection. An isolated Largest-text dark
demo verified disabled defaults, role switching, separate preparation confirmation, a bounded
simulation, Close/Command-Q holds and unlocking after completion. UI inspection caught and fixed
an initial constraint-parent ordering error; compilation alone had not exposed it. Final copy
also clears the simulation's running instructions and handles missing attempt reports explicitly.
Minimum-size resizing and full VoiceOver behavior are not qualified by these observations.

No real installer, monitor command, audio change or service replacement ran during the UI tests.
The current live input prerequisite remains unresolved. Use the installation guide for the
source workflow and its qualification limits; physical activation remains a separate step.
