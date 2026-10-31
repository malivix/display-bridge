# WindowServer connection churn and DDC flapping

## Incident

On Mac A, WindowServer exited twice, at 2026-10-30 16:08:49 and 2026-10-31 21:54:56, after
about 27 h and 30 h of uptime. loginwindow logged `directLogoutReason:WindowServerExited`
both times, so the session was logged out. launchd reported an unexplained exit reason
(`namespace 30, code 0xc40000000004aaaa`) and "crashed 3 times in a row". No panic, no
reboot and no WindowServer crash report were written.

In the minute before the second exit, all 187 new WindowServer client connections came
from `display-ddc`. With `poll_interval` 0.25 the controller started four or five helpers
per poll (`display-layout status`, `display-ddc display list`, two `get input` reads and
an orientation read). Each opened and closed its own WindowServer connection and triggered
a TCC check inside WindowServer: about 270,000 connections a day. The cause is inferred
from that correlation and the uptime-shaped failure; the exit reason does not name it.

The controller log for 2026-10-30/31 also showed 1,659 "DDC unavailable" / "DDC recovered"
pairs, up to 274 an hour, mostly the RD280UG missing one reply. Each flap reset the
verified state and forced a full reconciliation (more helpers). 697 "Recovery failed:
benq: display-ddc" lines came from a missed reply during a transition's input confirmation,
which spent the three-attempt retry budget. No repeated layout readback failure was found,
so a reconfiguration loop is not supported by the evidence.

## Change

- `display-ddc serve` answers line requests from one long-lived process; the controller
  (`DDCServer`) owns it only while watching, recycles it every 10 minutes and after any
  timeout, exit or malformed reply, and rejects arguments containing whitespace. One-shot
  commands still use separate processes. `display-ddc display keys` replaces the per-poll
  `display-layout status` in the topology check; both report vendor:model:serial.
- Up to two consecutive failed reads are transient: the debounce still needs two fresh
  samples, but the verified state is kept and nothing is reported. From the third, the
  existing "waiting for monitor response" path applies, with backoff up to 4 s (below the
  5 s wake-gap threshold).
- `DDCReadFailed` during a transition is handled like `InputsChanged` (settling) and does not
  spend recovery attempts.
- `display-layout apply` returns `{"changed":false,"deferred":"asleep"}` when the layout
  differs and any online display is asleep. The controller raises `LayoutDeferred`, reports
  `waiting-for-ddc` with `layout: deferred-display-asleep`, and retries on a new input state
  or after 30 s. Apply timeout raised from 8 s to 20 s.
- DDC tool hardening (see vendor/m1ddc/LOCAL-CHANGES.md), audio inventory skips vanished
  devices, rotation refusals are explained.

Rollback: reinstall the previous release with `rollback.py`; no configuration format changed.

## Validation

- 341 Python tests (15 new) and `./scripts/verify --native` passed, with the system clang
  first on PATH (the Homebrew LLVM clang on this machine cannot link against the SDK).
- New native assertions cover ambiguous, missing, zero, negative, past-the-end and empty
  display selections.
- Read-only on Mac A hardware with the built tool: `display keys` matched `display-layout
  status`; `display list` and both `get input` reads matched the installed tool; one serve
  process answered 3,000 list and 3,000 key requests with flat RSS (9.9 MB) and 150 PG input
  reads (149 succeeded); 60 complete controller `read_inputs` polls through the reader took
  0.18 s each (59 succeeded). `display-layout check` on the live baseline matched; the
  rebuilt audio helper's inventory equals the installed one.

## Not done

Not installed; the running controller is still 2.10.2. Not physically exercised: hotplug or
power-cycling a monitor with the long-lived reader running (enumeration freshness relies on
the run-loop pump and the 10-minute recycle), the asleep deferral, a full input transition
and listening check, and whether WindowServer stays up beyond 30 h. Proxy matching by
registry iteration order in `getDisplayDDCTransport` was reviewed but left unchanged, since
changing it needs hardware qualification.
