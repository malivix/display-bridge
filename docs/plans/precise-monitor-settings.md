# Precise monitor settings

Add an explicit percent target through the existing serialized DDC command boundary,
then expose a native slider with a separate Apply action. Dragging must not send writes.
The slider shows desired versus confirmed values, and target selection/ownership changes
invalidate pending intent. Continuous streaming/coalescing remains a later measured step.

The backend converts percent using the freshly read hardware maximum, rechecks ownership
before and after the single write, and validates readback. No retry or automatic rollback
may overwrite a manual change or remote input. Existing ±5 controls remain supported.
The new command is capability-gated in the UI before dispatch to older controllers.

Acceptance: invalid percentages fail before requests; arbitrary hardware maxima are handled;
no-op targets avoid writes; input loss prevents further writes; mismatch is not success.
Test through the CLI's existing maintenance/preview/ownership guards, then inspect the
native interaction separately in a hardware-free demo. Physical latency/readability remain
opt-in. No installed release is changed by ordinary verification. Rollback is coordinated
controller/menu restoration; this adds no persisted configuration or execution journal.
