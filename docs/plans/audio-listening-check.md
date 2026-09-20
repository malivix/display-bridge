# Explicit listening check

Provide an operator-started audio-test command: inspect enrollment and known input ownership,
identify one live selected output, reject a selected enrolled monitor showing the other Mac,
play one fixed quiet system sound with a three-second deadline, then recheck inputs/output.
Never select, unmute, change volume, reset formats or retry. A changed route/input or playback
failure is inconclusive. Success means playback completed, not that sound was audible.

This is not an execution request in command-results or a routing mutation. It cannot lock
other apps or physical monitor input switches; endpoint comparisons cannot prove no transient
change occurred. Return only an output category, not audio IDs. A subsequent native UI action
will explain the audible effect before invocation and ask the user whether it was heard.
No automatic sample on startup, switching or recovery. Unit tests mock every hardware/playback
call. No real sound during development verification; no persistence/schema migration.
