# Installed services survive an interpreter patch upgrade

The installer recorded `Path(sys.executable).resolve()` in the LaunchAgent
`ProgramArguments`, the shell wrapper and the manifest. With a package-managed Python
that resolves through the stable prefix into a single patch release, so upgrading the
interpreter deletes the recorded path and both services stop starting. Nothing reads the
manifest's `python` field, and the wrapper cannot report the fault because it needs that
same interpreter to run, so the failure is silent.

`interpreter_path()` now keeps the path the running interpreter reports and requires it to
be absolute and executable, rejecting a relative or missing interpreter at entry instead of
writing an unusable service. Observed locally: `sys.executable` is the stable prefix path
and only `resolve()` introduced the patch-release component.

Tests assert the recorded path is the stable one when it is a symlink into a versioned
directory, and that an empty, relative or missing interpreter is rejected. The first fails
against the previous implementation, which returned the link target.

Rollback restores the resolved path and the upgrade fragility with it. No state format
changed; an existing installation keeps its recorded interpreter until it is reinstalled.
