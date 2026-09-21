# Cohesive size chooser module

Moved size comparison formatting, duration validation, reference filtering, validity
latching and SizeChooser together into `native/menu/SizeChooser.swift`. PresetWindows
retains named-preset and brightness dialogs plus panel keyboard routing. The canonical
source inventory and architecture/development guides now describe the boundary.

This is a source-preserving extraction: recombining the new module and remaining file
without its duplicate import header reproduced the original text exactly before trimming
the new file’s trailing blank line. No action,
control, timer, argument or hardware policy changed. Keeping the complete size workflow
together gives subsequent calibration work one focused owner without a new wrapper layer.

Validation: `scripts/verify --native` passed, including 290 Python tests and all native
builds/self-tests through the updated source inventory. No new tests duplicate the move.
No fresh visual or physical test was claimed; existing behavior was preserved by the
source comparison. No installation occurred.
