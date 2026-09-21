# Actionable setup prerequisite failures

The native setup review previously displayed failed check names without explaining a
remedy. It now places failed checks before successful checks and supplies static,
check-specific guidance for platform, macOS, Python, source completeness, build tools
and service-namespace problems. Python guidance explains that rebuilding is necessary
to change the interpreter retained by an existing setup app.

The existing validated check name is sufficient to identify the failure category; no
parallel reason-code protocol was added. Arbitrary subprocess details remain excluded.
The change does not alter preflight, install eligibility, service migration or recovery.
Service conflicts require reviewing the existing installation guide and preserving
settings/backups, rather than an automatic cleanup action.

Native regression coverage exercises all six failed categories, failure-first ordering,
private-detail exclusion and rejection of a contradictory success report. `scripts/verify --native`
passed, including 279 Python tests and native builds/self-tests. This is presentation
coverage, not graphical installer activation or physical qualification. Setup lifecycle
fault testing remains the next reliability item in the current delivery plan.
