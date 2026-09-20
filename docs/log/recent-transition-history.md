# Show recent transition attempts

The history response now includes at most ten newest recognized completed/failed attempts.
The projection includes only role/result, valid known phase timings and a bounded retry
number; raw errors, reasons, input data and timestamps are omitted. Existing aggregate
statistics remain unchanged. The menu shows recent attempts first, labels missing timings,
and explains overlapping phases and retry counts. Older reports retain aggregate access.

Validation: the new projection test failed first with missing recent_events, then passed.
240 Python tests and all native builds/self-tests passed. After final presentation edits,
the demo rebuilt and native self-tests passed again. Coverage includes ordering, ten-event
bound, unknown-event filtering, private-field omission, boolean duration rejection and
missing-report fallback. The Largest demo visibly showed a failed attempt followed by a
completed attempt; available timings and aggregates were present in the accessibility tree.
No new polling, hardware changes, installed updates or telemetry. These are source tests
and synthetic UI evidence, not measurements of the user's current switching speed.
