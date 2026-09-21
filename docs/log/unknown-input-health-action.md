# Make unknown-input guidance actionable

The Overview already showed the unexpected input, enrolled mapping and a warning
against guessing or automatic remapping. Its action policy nevertheless returned
no action for a fresh `waiting-for-known-input` observation, including the ordinary
case with no recovery pending. Users had to find Health elsewhere.

That state now selects the existing read-only Check health action, alongside saved
state errors. No new UI dispatcher, controller command, hardware permission or input
mapping was introduced. Settling, active recovery and DDC waiting retain their
existing behavior. Exhausted recovery with unknown ownership also offers inspection,
not audio repair. Click-time state and busy checks remain canonical.

Validation:

- `./scripts/verify --native` passed with 305 Python tests and native checks.
- Native regressions cover the unknown state without recovery, read-only command
  selection, busy rejection, state change before click and exhausted recovery.
- The current-source isolated demo showed mapping guidance and Check health.
  At Largest text and minimum window size, keyboard navigation revealed and focused
  the button. Space opened Details with Health check selected and a synthetic report.
- Private capture remains ignored. No hardware, local diagnostic data, installed
  service or user mapping was read or changed by the demo. VoiceOver speech and
  installed UI qualification are separate.

Rollback is the prior source/bundle; there is no state migration. This presentation
fix does not resolve or reinterpret an unrecognized physical monitor input.
