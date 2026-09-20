# Grouped status dashboard

Added an Overview tab with separate monitor, audio, and recovery groups; retained the full
report in Details. Command results and active progress appear in Overview. Preview countdown
and restoration instructions are preserved there. Pause/Resume is directly accessible;
inactive Keep/Revert controls are hidden. Text size applies across both tabs.

Native regression checks cover ownership labels, missing-status labeling, section order,
and preview countdown visibility. The hardware-free demo was inspected at standard and
largest text size, including scrolling to recovery and opening Details. Accessibility
inspection initially exposed headings without values; explicit value semantics corrected
this and the final tree includes each group's status. Raw screenshots stay ignored locally.

This is presentation only. No installed app or hardware settings changed. Live notification
and display behavior, full VoiceOver navigation, light mode, and every error-state layout
remain unqualified. Rollback is a menu source revert/rebuild; persisted controller state is
unchanged. The advanced menu remains available while its later simplification is pending.

Validation passed: 179 Python tests, native compilation, menu/DDC self-tests, and staged
privacy checks. A final wording adjustment explicitly reports paused audio policy and
uncalibrated rotation; the native build/self-tests passed again after that adjustment.
