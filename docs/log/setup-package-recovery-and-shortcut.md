# Packaged source qualification after recovery and shortcut changes

Built the independent setup app from clean committed source `d78d445`. Its embedded
revision matched HEAD and demo mode was false. The setup binary's self-tests passed
during the build. All 296 Python tests passed when run from the embedded Source directory,
including the process-termination and restore-preparation regressions. Bundled software
preflight reported prerequisites-ready using the package's selected local Python.

The ad-hoc signature verified before and after those checks. No `__pycache__` directories
were left in the bundle. The local package stays in the ignored private build directory;
it is not a published or notarized release and depends on the selected Python installation.

No setup UI activation, installer run, enrollment capture, service restart, or hardware
test occurred. Mac A's unrecognized input still prevents deployment qualification, and
Mac B remains deferred. This records package inclusion and software prerequisites, not
physical switching, audio, rotation, power-loss recovery or cross-machine compatibility.
