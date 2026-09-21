# Save dialogs retain readiness loss

Size and brightness save forms now observe their parent availability policy while open.
The first failure remains visible, Save is disabled, and editing a valid name cannot
restore eligibility. The form checks again at submission and releases its one-second
modal timer when closed. Removal keeps its existing validation. All commands still pass
through controller validation; this change adds no hardware reads or persistent state.

`scripts/verify --native` passed: 290 Python tests and all isolated native self-tests.
A separately built signed fixture used the real save panel at 24-point text. Its synthetic
availability failed after six seconds and recovered after twelve. The UI showed the
failure with Save disabled; after recovery, Command-A/name replacement and Return left
the same disabled form open. The screenshot showed the explanation and Cancel fitting.
Escape exited the fixture (the subsequent UI observation reported process-not-found,
consistent with the fixture's explicit termination after cancellation).

The fixture has no controller or hardware action callback. No software was installed,
and no display, audio or clipboard settings changed. This is modal interaction evidence,
not physical switching proof, full VoiceOver qualification, or coverage of transitions
shorter than the local-state polling interval. The brightness selection/apply dialog and
all remaining modal boundaries still need their own review.
