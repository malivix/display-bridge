# Share demo isolation with the status intent

Review of the companion startup found that the menu recognized both `--demo`
and the demo bundle flag, while the new status intent recognized only the latter.
A running command-line demo could therefore return real allowlisted controller
observations if its native action was invoked. No hardware mutation path was added.

A regression calls the actual entity reader against a disposable ready-state file.
Before the fix the compiled self-test passed normally and exited with a failed
precondition in `--demo` mode. The same synthetic fixture is used for both cases;
no real controller state was read. The reader accepts an explicit file root and
clock for isolated testing; production callers retain the fixed default root.

Both the menu and intent now use `menuDemoMode`. Tests cover command-line and
bundle flags, their combination and a nonmatching argument. Native verification
runs the full menu self-test normally and with `--demo`. Both pass after the fix,
as does `./scripts/verify --native` with 305 Python tests. This is a source-level
regression, not a Shortcuts discovery or companion-process execution test.

No installation, monitor change, sound, notification or clipboard operation was
performed. Rollback is reverting this source slice before deployment; no state
migration exists. Companion integration remains the active feature qualification.
