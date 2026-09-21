# Percentage support before opening the dialog

Controls now uses the cached controller capability report to disable unsupported or
unverified percentage entry before the dialog opens. A nearby explanation distinguishes
checking, unverified and unsupported states; the existing support disclosure provides
rechecking. Legacy reads and step adjustments retain their existing ownership guards.
The dialog also checks support alongside ownership, and dispatch still probes support
again before sending the command. Cached capability data never authorizes a mutation.

Validation: `scripts/verify --native` passed (290 Python tests and native checks).
Native regressions cover checking, absent reports, unsupported commands and supported
percentage entry. Existing dispatch tests still ensure an unsupported command is not sent.
A new isolated demo showed Set percentage enabled for the ready fixture and disabled with
an adjacent explanation for older-controller, while Read and ±5 remained enabled.
The screenshot inspection used Standard text and the default window. Larger text can
require scrolling; this turn does not claim a complete accessibility matrix. No actual
controller, monitor, clipboard or installation was changed.
