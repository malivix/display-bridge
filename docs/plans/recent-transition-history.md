# Recent transition details

Extend the existing local history report with the ten newest recognized completed/failed
attempts, preserving event order. Project only role, result, valid known phase durations and
bounded attempt number; no raw errors, identifiers, paths or timestamps. Keep existing
aggregate statistics unchanged. Do not add polling or record synthetic production events.

The menu shows recent attempts before aggregates, marks missing phases as unrecorded, and
explains retries and overlapping timings. Older reports retain their aggregates with an
unavailable-detail notice. Validate newest-first bounds, projection privacy, malformed values
and menu formatting; inspect the synthetic report at Largest. This is a read-only report
addition, not a new event schema or recovery policy. Rollback restores report/menu code.
