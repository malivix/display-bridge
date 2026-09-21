# Recover when stopping the prior controller fails

While reviewing coordinated activation for guided setup, the initial controller bootout was
found outside the installer's exception/recovery boundary. If launchctl failed or timed out
after stopping the service, installation exited without attempting its prior-service restart.

The initial stop is now inside the existing recovery handler. Before activation, prior files
stay untouched and the existing cleanup/restart path is attempted. A restart failure remains
an error; this does not guarantee recovery from repeated launchctl failures or forced termination.

A regression first reproduced the missing restart for stop errors and timeouts. Isolated tests
now also cover a Python KeyboardInterrupt, preserved prior config/release symlink/launcher,
restart using the prior launcher and propagation of the original stop failure after successful
recovery. All 268 Python tests and staged privacy checks passed. No native code, installed
services or hardware changed. Graphical activation remains planned in
[the setup activation plan](../plans/guided-setup-activation.md).
