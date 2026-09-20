# Recovery-first interface and enrollment review

Overview now keeps Recovery directly after its summary, ahead of monitor/audio details. The
existing guarded action precedes long error text. Stable ordering avoids moving focus as the
heartbeat changes. Audio shows its current output, repair and availability reason, then manual
controls and profile preferences. No hardware policy, retry or journal behavior changed.

Finished the pending native enrollment-review entry point: explicit A/B selection with no
default, compatible-controller probe, validated host/input/mode report and no capture or service
activation. Its source is included in the shared menu build manifest. Usage documents the
read-only boundary and installer requirement.

Validation: 247 Python tests and all native builds/self-tests passed. An initial verification
was interrupted by a test source being edited during compilation; the clean rerun passed.
After moving the audio availability label next to repair, rebuilt the demo and reran its native
self-tests. The existing stale-action, busy, manual-preservation and preview-token tests remain.

Synthetic UI inspection at Largest and the supported minimum window confirmed exhausted
recovery's action and first explanation are visible without scrolling; Audio's Repair action
precedes profile settings. Tab reached Repair from the Audio tab and Shift-Tab returned. Full
VoiceOver, appearance/state matrix and physical listening remain unqualified. No installed
controller, monitor settings or services changed. Enrollment checks cover no default host,
wrong host, malformed fields and old-controller refusal; they do not prove physical enrollment.
