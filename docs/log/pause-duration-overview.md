# Visible pause duration

Overview now identifies indefinite pauses and shows a timed pause's local expiry time and
approximate remaining minutes. An expired timer or cleared pause with a still-paused
controller report is described as waiting for a status update. Stale health keeps the
existing unavailable-status explanation rather than offering a current countdown.

Native regressions cover timed/indefinite pauses, minute rounding, expiry, malformed
timestamps, cleared preferences and stale health. Final `scripts/verify --native` passed
all 293 Python tests and native self-tests. The initial compile was invalidated by a source
edit during the build; the final run used the completed source without concurrent edits.

A newly built signed demo at Largest text and minimum window size showed the expiry,
remaining time and Resume button without scrolling. Its timed-pause scenario is synthetic
and always fifteen minutes from the fixture's current time; it does not prove real expiry.
Controller expiry remains covered by isolated Python tests. No pause preference, installed
service, hardware or clipboard state changed.
