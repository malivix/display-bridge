# Enforce fixed-refresh SDR policy during capture

First-time capture and installer recapture previously checked only numeric 120 Hz, despite
requiring fixed refresh and HDR off. They now share validation of current mode metadata:
exact enrolled identities/mode properties, 2x HiDPI, explicit VRR/ProMotion off and HDR-off
preference. Missing metadata or a changed mode rejects capture before baseline writes.
Installer metadata inspection is bounded to ten seconds. No monitor setting is changed.

Validation: 246 Python tests and privacy checks passed. Cases cover valid metadata, VRR,
ProMotion, HDR, absent/incorrect boolean values, metadata errors, changed dimensions and
invalid refresh. An initial-capture regression confirms rejection with original config and
baseline bytes preserved and audio capture not called. Existing installer tests passed;
physical first installation and recapture remain unqualified. Native code was unchanged.
This is a prerequisite for guided enrollment, not a claim that a mutable setup wizard exists.
