# Preserve valid history around malformed durations

Reproduced a history crash with a valid JSON integer outside floating-point range. Both
recent-event projection and aggregate collection now use a duration validator that rejects
booleans, nonnumeric/negative/nonfinite values and overflow during conversion. Invalid
phases are omitted; other valid phases/events remain available and source bytes are preserved.
Also calculate the even-sample median without summing two large positive floats, avoiding
an infinite median from individually finite samples. Aggregate semantics remain unchanged.

Validation: 242 Python tests and privacy checks passed. Regressions cover oversized integers,
negative/null/string/boolean/nonfinite samples, preservation of other timing evidence and
original file bytes, and finite large samples producing valid JSON aggregates. Native code
was unchanged. No installed services, hardware settings or production history were changed.
