# Preserve keyboard focus when recovery actions disappear

An isolated reproduction exposed focus loss after automatic recovery. A private copy
of the current demo source started in recovery and scheduled ready two seconds after
the Repair button became first responder. The production refresh path then hid the
recovery group. The accessibility adapter reported focus on the window, with no visible
control focused. No button was activated and no backend command was dispatched.

The app now computes the next recovery action before updating visibility. If a focused
Repair action changes, or the adjacent focused Health action is about to disappear,
it moves focus to the existing tab control. Other focus is left alone; stale-action
validation and repair dispatch remain unchanged. Repeating the same private probe
reported focus on the visible Overview tab after recovery. The focused ring was visible.

The timer and initial recovery state exist only in ignored probe sources, not production
or the normal demo. The probe's scenario picker still says ready and is not evidence
of its initial injected health. This is an instrumented interaction test, not an
unmodified release binary or physical recovery test. Both probes used Standard text.

Validation: `scripts/verify --native` passed, including 297 Python tests and native
builds/self-tests. Exact before/after interaction evidence is retained privately. No new
unit test was added merely to mirror AppKit view ordering. The adjacent Health and
changed-preview-token cases share the focus guard but were not separately exercised.
VoiceOver speech and the complete focus matrix remain unqualified.

The same probe shows extra blank space above the smaller ready summary after recovery
groups collapse. That document-layout issue remains open as the next targeted fix.
A read-only installed heartbeat check still reported an unknown input combination, so
no installation was attempted. No raw identities or local machine paths are published.
