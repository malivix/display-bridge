# Validate monitor result presentation

The menu previously defaulted unknown monitor/feature names to BenQ/volume and missing
settings numbers to zero. Replaced those rendering branches with a typed response decoder
for monitor-settings, monitor-adjust and brightness-apply. It checks the requested role and
feature, range, ties-to-even percentage, actual boolean fields and before/changed consistency.
Missing, mismatched, oversized or unsuccessful responses cannot produce a confirmed reading.

Failed refreshes preserve one previous valid reading, explicitly labeled not refreshed.
Repeated failures do not accumulate nested stale messages. Backend failures still expose
the original error details. There are no automatic retries or backend policy/schema changes.
The demo includes a malformed-response scenario with synthetic earlier readings.

Validation: 233 Python tests and all native builds/self-tests passed. After final menu edits,
the macOS 13-target demo was rebuilt and native self-tests passed again. New cases cover
missing fields, role/feature mismatch, boolean-number confusion, range and percentage errors,
nonzero exit, malformed/oversized JSON, duplicate target arguments and percentage ties.
The Largest demo Controls view was inspected: the error, previous-reading label and values
were readable after scrolling with no horizontal clipping. Full accessibility and physical
qualification remain pending; no installed services or monitor settings changed.
