# Explicit brightness presets

Save and recall named brightness values per enrolled monitor. Store the confirmed native
value and maximum, scoped to host and display identities. A changed maximum rejects recall
rather than guessing a percentage. Names use the existing preset-name validation.

Deliver backend/CLI first, then a readable Controls chooser using list revisions, explicit
Save/Apply/Remove actions and confirmed values. Reuse the mutation, maintenance and DDC
locks, setup/ownership checks and bounded settling interval. Never replay after failure,
schedule writes, dim via gamma, change volume or switch monitor inputs. Two monitors can
have different values; equal percentages do not imply equal luminance.

Persist bounded schema-versioned data using atomic private writes. Preserve malformed
stores and other monitors' entries. Require explicit replacement and revision checks for
apply/removal. Diagnostics include this private file; public summaries omit names/values.
Tests cover enrollment/range/revision changes, corruption, ownership changes, readback
failure, no-op recall and one-write-only behavior. Physical brightness qualification is
opt-in. Rollback ignores the additive store; no configuration migration is required.

## Source implementation status

Backend and Controls chooser are implemented. The chooser keeps the monitor and revision
from its validated list snapshot, distinguishes saved from live values, and has explicit
Save/Apply/Remove actions. Empty and malformed lists have separate outcomes. See
[UI validation](../log/brightness-preset-chooser.md). Physical recall, ownership changes
during an open dialog, and installed-version qualification remain pending.
