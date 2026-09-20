# Repository guidance research

Reviewed 2026-09-20 against primary documentation. These are recommendations for
the repository bootstrap, not evidence that a control is installed or enabled.
Implementation and validation status belong in the work log and actual checks.

## Agent instructions

Use root `AGENTS.md` as the shared, concise entry point: project purpose,
architecture links, exact verification commands, hardware safety boundaries,
privacy rules, and contribution conventions. The format is plain Markdown;
nested files can provide narrower guidance when a subdirectory needs it.
Do not create nested instruction files merely for symmetry.
[AGENTS.md format](https://agents.md/)

Keep `CLAUDE.md` small and import `@AGENTS.md` rather than maintaining a second
copy of policy. Claude documents relative imports and recommends specific,
concise instructions. Current Claude Code can also load `AGENTS.md` natively,
but support depends on client version and session configuration; the presence
of a `CLAUDE.md` in the directory ancestry changes default discovery. An explicit
import keeps this repository's intended entry point clear. Do not publish
personal agent memory or `CLAUDE.local.md`. Instructions guide model behavior;
they do not enforce security boundaries.
[Claude Code memory documentation](https://code.claude.com/docs/en/memory)

## Engineering harness

Treat the instruction file as a map to maintained documentation, not an archive
of every past conversation. Keep architecture, decisions, work history, and
qualification evidence separate. OpenAI describes this structure and emphasizes
mechanical enforcement of important invariants; its article is a case study,
not proof that every project should copy its autonomy or merge policy.
[OpenAI harness engineering](https://openai.com/index/harness-engineering/)

For Display Bridge, the useful application is a small set of repeatable commands
that run offline tests and publication checks, with hardware tests explicitly
separated. Record the change, reason, validation, and remaining uncertainty in a
work log. Never label a mocked test as physical display or audio verification.
Keep generated local diagnostics out of public logs. These are project-specific
recommendations inferred from the case study and this application's hardware
control responsibilities.

## Public repository safety

Check the exact staged content before the first commit, and all commits intended
for publication before push. Exclude local settings, raw hardware evidence,
diagnostic archives, backups, compiled artifacts, personal paths, device
identifiers, and credentials. Use synthetic fixtures. Inspect filenames,
symlinks, archive contents, and commit author metadata as well as source text.
These project-specific privacy checks complement credential scanners; they
are not claims about everything GitHub secret scanning detects.

Enable and verify GitHub secret scanning and push protection where available.
Push protection blocks supported credential patterns; its account and repository
settings differ, so do not infer repository protection from account defaults.
A clean scan is not proof that every secret or personal detail is absent.
[GitHub push protection](https://docs.github.com/en/code-security/concepts/secret-security/push-protection)

If a credential is exposed, revoke or rotate it first. Removing it in a later
commit is insufficient, and history rewriting cannot erase others' clones.
Pre-publication review is preferable to relying on cleanup afterward.
[GitHub sensitive-data removal](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/removing-sensitive-data-from-a-repository)

## CI and commits

Use minimal workflow permissions and full commit-SHA pins for third-party
actions. Do not run untrusted pull-request code in privileged
`pull_request_target` or `workflow_run` jobs. Pass untrusted event text through
arguments or environment variables instead of interpolating it into shell code.
This project should run non-hardware validation in ordinary pull-request CI;
installation and physical display mutation do not belong in that job.
[GitHub Actions secure use](https://docs.github.com/en/actions/reference/security/secure-use)

Use Conventional Commits: `type(optional-scope): description`, with `feat` for
features, `fix` for bug fixes, and `!` or a `BREAKING CHANGE` footer for breaking
changes. Types such as `docs`, `test`, `ci`, and `chore` are permitted. Suggested
bootstrap message: `chore(repo): initialize public repository and engineering harness`.
Apply the convention to subsequent commits and squash-merge titles; a local
hook provides feedback but does not replace CI or review.
[Conventional Commits 1.0.0](https://www.conventionalcommits.org/en/v1.0.0/)
