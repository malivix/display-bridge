# Read-only layout snapshot

Expose actual macOS mirroring in the existing two-read display inspection. The mode helper
adds the mirrored source display ID. Compare IDs and mirror relationships across reads;
map them to enrolled roles before UI output. Missing, invalid, cyclic or unfamiliar
relationships report unknown. Never infer the logical layout from the desired profile.

Displays renders an accessible relationship schematic plus ownership and measured rotation,
followed by existing current/saved size details. Label this as a snapshot of this Mac, not
physical screen contents or positions. Older helpers omit topology and must show unknown.
No new polling or mutation path; rollback restores source without state migration.
