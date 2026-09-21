# BenQ identity differs per physical input

Capture identified the enrolled pair by a single hardcoded `vendor:model` prefix each,
`1715:17120:` for PG and `2513:32963:` for BenQ. Installing Mac B failed at capture with
`Cannot uniquely identify benq; no configuration written`, and the installer restored the
prior files from its backup.

The two hosts must occupy different physical inputs on the same BenQ, and the RD280UG
publishes a different EDID product code per input. Mac A reads `2513:32963`, Mac B reads
`2513:32959`. Re-cabling cannot avoid this; one input cannot serve both hosts. The PG
reports `1715:17120` on both of its HDMI inputs, so only BenQ was affected.

`PANEL_IDENTITIES` in `hidpi_report.py` now maps each role to the product codes that role
may present, `PANELS` derives from it, and capture matches any of a role's prefixes. The
`len(found) != 1` ambiguity guard is unchanged, so an unknown panel and a duplicate identity
still refuse to write a configuration. Saved configurations keep the identity the host
actually observed; no stored format changed and nothing migrates between hosts.

Rollback removes the extra accepted identity, which would restore the Mac B capture failure
while leaving Mac A working.

Validation: 308 Python tests and `./scripts/verify --native` pass. A new isolated test drives
capture for both hosts with synthetic identities and asserts each resolves to its own key;
a second asserts an unknown panel is still rejected. It fails before this change on Mac B's
code and passes on Mac A's, reproducing the installation failure without hardware.

Mac B was then installed for real: the baseline captured, the installer's four layout
transitions passed, both services reached `ready` with profile `extended` and inputs 18/15,
and the menu app installed. Physical input switching, sound, sleep/wake and rotation on
Mac B remain unqualified; rotation is disabled because no orientation profiles exist yet.
