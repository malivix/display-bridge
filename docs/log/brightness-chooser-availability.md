# Brightness preset chooser readiness

Apply and Save previously used readiness captured when the chooser opened. They now
observe local-state policy while open, retain the first failure and require reopening
after a failure. Selection changes cannot clear the failure. Submission rechecks eligibility.
Remove checks its own current saved-controls/busy policy; remote monitor ownership alone
does not prevent managing saved data. Cancel remains available. The modal timer is invalidated
on exit; parent and controller validation remain authoritative.

Validation: `scripts/verify --native` passed, including 290 Python tests and native
self-tests. A signed isolated fixture used the real chooser at 24-point text and two
synthetic presets. Initially Apply, Save and Remove were enabled. During the synthetic
failure, selecting the second preset showed its correct value and all three actions
were disabled. After synthetic recovery, Remove became enabled while Apply/Save remained
disabled. Keyboard Tab reached Remove; the screenshot showed the reason and controls
fitting. Escape closed the fixture without applying or removing anything.

No controller installation, hardware action, clipboard change or real state mutation
occurred. These checks do not qualify physical DDC, VoiceOver speech, or transient state
changes between local polls. Retained failure text records the reason that invalidated
the window; reopening obtains current eligibility.
