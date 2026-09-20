# Put the next setup action first

Setup readiness now shows error/warning counts and the first error's suggested action,
or the first warning when there are no errors, above the full checklist. Original ordering
within severity is preserved. Informational-only reports explicitly do not qualify physical
behavior. Missing enrollment checks remain labeled unreported; missing action text gets a
conservative inspection instruction instead of a guessed command.

Health and Setup share a typed decoder requiring a real read-only boolean, nonempty bounded
checks, names/details, known statuses and an aggregate status consistent with the findings.
Malformed or contradictory reports no longer render an apparent readiness pass. No settings,
controller commands, persisted schemas or automatic repair behavior changed.

Validation: 238 Python tests and all native builds/self-tests passed. Final wording was
rebuilt and native self-tests rerun. Tests cover priority, contradictory status, wrong boolean
type, empty/missing checks, missing fields, absent actions and informational-only results.
The Largest isolated demo shows the synthetic portrait-profile warning and next action in
the initial viewport; the full report remains scrollable. This does not establish real
calibration, audibility or physical readiness. No installed app or monitor settings changed.
