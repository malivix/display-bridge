# Preserve failed-transition timing

The controller retains completed phase timings incrementally. A failed attempt now records
elapsed application total and the interrupted phase with elapsed time. The history projection
accepts only known phase labels and valid durations; raw errors remain private. The native
recent-attempt report explicitly labels the phase interrupted rather than completed. Failed
attempts remain excluded from successful-transition timing aggregates.

Tests induce failures during rotation, layout and audio and assert exactly which completed
phases survive. Projection tests reject unknown labels, booleans and overflowing numbers while
preserving valid completed phases. Native checks cover interrupted-phase wording and omission
of unknown labels. The synthetic history fixture includes an interrupted audio phase.

All 255 Python tests and native builds/self-tests passed. No retry budgets, input checks,
hardware operations or installation were changed. Detection delay before the first valid
observation remains unmeasured; this is not a physical latency qualification.
