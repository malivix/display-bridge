# Discoverable precise controls and one display refresh instruction

Moved Set percentage directly below Read brightness and volume. Healthy readiness no
longer consumes a separate paragraph; blocking guidance still appears and the existing
eligibility checks still disable actions. Displays no longer repeats its empty-state
instruction in the report body. The Refresh button retains a read-only snapshot
explanation in its tooltip and accessibility help. No command or controller behavior
changed, and no new test was added solely to mirror the view ordering.

Validation: `scripts/verify --native` passed, including 297 Python tests and native
builds/self-tests. Current-build isolated demo inspection at Largest text and minimum
main-window size confirmed the precise action is visible. Stale status restored the
blocking reason and disabled adjustment. Displays showed one empty instruction and
synthetic Refresh populated its existing report. Screenshots remain private/ignored.
No physical monitor read/write, sound, notification, clipboard action or installation
was performed. Full VoiceOver and light appearance remain unqualified; no new CI run
is claimed. Contextual Audio preferences remain a separate pending slice.
