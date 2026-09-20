# Security and privacy

This is local hardware-control software, not a security-certified application. Runtime
stores device identities, layout, audio routes, and diagnostics under the user's account.
Treat diagnostic bundles, backups, logs, and screenshots as private until manually reviewed.
Private diagnostics include named size and brightness presets. State-file reads are capped at 1 MiB each;
oversized files retain a 64 KiB sample with a sample hash, not a claimed full-file hash.
Do not attach raw bundles to public issues. Use a minimal synthetic reproduction instead.
`support-summary` creates a separate allowlisted overview without identifiers, names, paths,
raw errors, logs, or exact timestamps. Review it before sharing: health and usage counts can
still reveal operational information. It does not upload anything or sanitize an existing
private bundle. Missing/damaged sections are reported explicitly.

Publication gates reject private artifact paths, binaries/archives, concrete home-directory
paths, common credentials, and UUID-shaped device identifiers outside approved synthetic
fixtures. Gitleaks provides a second detector. These checks are heuristic, not proof that all
sensitive information is absent; inspect the staged diff and commit metadata too.

Use GitHub's private vulnerability reporting on this repository when enabled. If it is
unavailable, open a minimal issue requesting a private contact channel without exploit details,
credentials, device data, or diagnostic attachments. No response-time guarantee is offered.

If sensitive data reaches history, revoke exposed credentials first, then follow GitHub's
sensitive-data removal procedure. Deleting a file in a later commit does not remove history.

CI uses read-only permissions and no runtime credentials. Review third-party action pins
before updates. Never execute untrusted pull-request code with write tokens or secrets.
