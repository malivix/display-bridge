# Pause/resume execution and noninteractive results

Actual Shortcuts testing of source `93595b1` found a presentation defect: a valid
pause reached the private stub exactly once, but the action remained running with
its default Show When Run option. The companion's process sample showed its normal
event loop. Disabling only Show When Run let the same request complete. This
isolates the observed failure to the optional dialog path in this environment;
it does not establish a general macOS/App Intents defect.

Pause and resume now return their typed outcome directly without ProvidesDialog.
Explanation remains in each outcome's display subtitle. Neither action needs a
result-presentation interaction to complete. Command semantics, validation and
request acknowledgement checks are unchanged.

## Current-build evidence

A private signed copy of the real companion used redirected temporary state and
CLI paths, plus its own bundle identity. The command stub recorded arguments and
returned controlled JSON. No demo flag was set. The updated actions appeared without
Show When Run after package replacement and narrow registration refresh.

- Two-minute pause completed as Request saved, sending exactly the capability
  probe and `pause-for --minutes 2`.
- Zero-minute pause returned Request not sent and made no CLI call.
- A malformed acknowledgement returned Outcome unknown, with exactly one request
  dispatch and no automatic retry.
- Resume completed as Request saved using the canonical `resume` command.
- A following Get Text from Input action consumed the typed Request saved value.
- After the private companion was verified stopped, the same resume/text sequence
  cold-launched the expected build and completed. Its command log contained one
  startup capability check, one action capability check and one resume dispatch.

`./scripts/verify --native` passed: 305 Python tests and native checks. The updated
signed private builder passed its self-tests, metadata validation and signature
verification. Raw captures, process samples, registration dumps and command logs
remain private. The probe was stopped afterward. This qualifies isolated intent
execution, not installed production activation or physical reconciliation.

## Registration lesson

A prior private signed package with the production bundle identifier had become
registered, despite no explicit app activation. Its post-build executable self-test
is a possible cause; this was not isolated conclusively. Before executing control
actions, its exact private registration was removed and the registry was checked:
only the redirected control probe then advertised Pause/Resume metadata. The test
also searched by the private app name before adding its actions. The installed
app's registration was preserved. Future private native tests must check registration
rather than infer absence of registration from absence of an explicit app launch.

No installed controller command, monitor write, audio operation or clipboard action
was used. Real command rejection paths, installed activation, production replacement
and broader OS/distribution coverage remain separate qualification work.
