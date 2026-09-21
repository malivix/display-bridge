# Native macOS Shortcuts

Display Bridge offers three optional native actions: read status, request a timed
pause, and resume automation. They execute on the Mac running the shortcut.
They do not control the other Mac or change monitor inputs.

## Availability

The standard ad-hoc installation does **not** include these actions. They require
the [optional signed build](install.md#optional-native-shortcuts-build-production-activation-pending),
full Xcode and a suitable existing local signing identity. The graphical installer
has no signing-identity selector. Updating a checkout does not update the installed app.

Private signed integration tests passed for status and pause/resume, including
cold launch and typed results. Production activation, public binary distribution
and broader OS coverage remain unqualified. See [qualification](qualification.md),
[status evidence](log/shortcuts-companion-execution.md) and
[control-action evidence](log/shortcuts-control-execution.md).

## Create a shortcut

After installing the optional build, open Apple's Shortcuts app, create a shortcut
and search for one of the action names below. The installed companion is named
**Display Auto**. Select that app's action if several copies appear.

| Action | Input | Output |
| --- | --- | --- |
| Get Display Bridge Status | None | Structured latest controller observation |
| Pause Display Bridge | Whole minutes, 1–1440; default 30 | Typed request outcome |
| Resume Display Bridge | None | Typed request outcome |

A pause takes effect after any operation already in progress finishes. Its timer
starts when the request is saved; the controller resumes after that timer expires. Resume ends that pause sooner but preserves manual
audio overrides. Both requests use the normal controller checks and may be rejected
while a size preview is unresolved.

## Read status

Start with **Get Display Bridge Status**. Its output exposes these selectable fields:

| Field | Meaning |
| --- | --- |
| Observation freshness | Fresh means the valid observation is less than 15 seconds old. Stale is older; Unavailable means it could not be established. |
| Reported controller state | Ready, Paused, Recovering, or another reported state. This is separate from freshness. |
| Reported arrangement | Both monitors here, Only PG here, Only BenQ here, Both monitors away, or Unknown. |
| Requested pause state | Saved pause intent; it does not prove the controller has finished pausing. |
| Reported recovery state | Pending, None reported, or Unknown. It does not prove audible sound or a correct physical desktop. |
| Observation age in seconds | Age when valid, otherwise absent. |

For a simple read-only shortcut, add **Get Text from Input**, select the status output
and choose **Observation freshness**. Running it produces Fresh, Stale or Unavailable.
For branching, check freshness before relying on controller state or arrangement.
The result represents the latest observation and can be refreshed when resolved;
use transition history for past events. Reading status does not force a monitor scan.

## Interpret pause and resume results

| Outcome | What to do |
| --- | --- |
| Request saved | The request was saved for the controller. Check status for progress; this is not confirmation that reconciliation finished. |
| Request not sent | Check the pause duration, installed controller support and whether the app is a demo. No pause/resume request was dispatched. |
| Outcome unknown | Inspect status before retrying. The request may have been saved even if the caller timed out or its response could not be verified. |

For a 30-minute pause shortcut, add **Pause Display Bridge** with Minutes set to 30.
A following **Get Text from Input** can display its typed outcome. Resume can be a
separate one-action shortcut. These actions return directly without a Show When Run
dialog. Do not add an automatic retry loop for Outcome unknown: stopping the shortcut
or timing out does not cancel work already accepted by the controller.

## If an action is missing or cannot run

Confirm that the installed companion is the optional signed build, not the default
ad-hoc build or an older installation. Launch the installed Display Auto app and
search again. A developer/test copy can register the same action names; verify the
owning app before running a control action. Avoid resetting the system's entire app
registration database.

If the action runs but reports unavailable/unknown state, open Display Bridge and
choose **Check health**. Preserve an unrecognized input mapping for investigation;
Shortcuts does not bypass enrollment, ownership checks or recovery rules. The normal
menu and [CLI commands](usage.md) remain available without native Shortcuts support.
