# Feature-specific percentage proposals

Monitor readings now retain a typed value and observation date for each monitor and
feature. Volume changes do not refresh brightness or another monitor. The percentage
chooser uses the selected feature's previous value with an explicit unrefreshed label;
unknown settings require slider interaction before Apply is enabled. Changing features
discards the unrelated proposal. No hardware polling or persisted state was added.

Validation: `scripts/verify --native` passed, including 290 Python tests and native checks.
Native regressions cover missing/cross-monitor values, separate feature values and dates.
A newly compiled isolated demo at Largest text showed disabled Apply without a reading,
Option–Right changing the requested value from 50 to 51 and enabling Apply, and switching
to volume resetting the unknown proposal and disabling Apply again. Escape returned to
Controls. No hardware commands were dispatched. Seeded values were model-tested; this
turn did not physically qualify a setting change or perform a VoiceOver speech test.

Numeric entry and compact in-panel reading placement remain the next portions of the
current priority plan. This change does not install a new release.
