# Read-only enrollment review boundary

Separate candidate inspection from capture's configuration writes. Both use the same fresh
identity, fixed-mode, audio-discovery and two-input-read checks. Add capture-review --host A/B
for first-time inspection without an existing valid enrollment. Return an allowlisted summary
of role, logical/framebuffer size, orientation, expected local input and available audio route
categories; keep discovered device IDs/paths out of the report.

This command writes no configuration or services and is not an approval token. Existing
maintenance/DDC locks may create coordination files; helpers must already be built. Capture
always recomputes the candidate before saving. Hold the installer maintenance lock while
reviewing, serialize DDC reads, and permit no configuration mutation from review output.
Validate independent host mapping and unchanged existing bytes with synthetic adapters.
A native guided enrollment UI and physical first-host qualification remain subsequent work.
