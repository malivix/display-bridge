# Explain unknown monitor inputs

A fresh installed heartbeat remained waiting-for-known-input with PG reporting 15 and BenQ
19. This is controller readback, not proof of the physical source. Deployment was not attempted
and no input mapping was changed. Improve the source UI to describe the unknown value and
the enrolled Mac A/B mapping, with a check-input/cable and Health next step. Malformed numeric
values are described as unavailable. Show guidance only for fresh ownership-waiting status.

Validation: 242 Python tests and all native builds/self-tests passed. Added native cases for
the observed unknown PG value, recognized inputs, stale status and boolean-as-number rejection.
In the Largest synthetic demo, the explanation and mapping were readable in the Overview,
Health remained available and Preview size was disabled. No installed services or monitor
settings changed. Source work can continue; deployment still requires recognized local inputs.
