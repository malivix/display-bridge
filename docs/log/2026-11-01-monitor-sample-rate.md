# Monitor sample rate held at 48 kHz

## Problem

Monitor audio had been set to 48 kHz by hand in Audio MIDI Setup. Nothing in the controller
kept it there: the transition stream refresh toggled to an alternate rate and restored
whatever rate it found, so a monitor that came back at 44.1 kHz stayed at 44.1 kHz.

## Change

- `display-audio rate UID RATE` sets one alive output after checking that the nominal rate
  is writable and in the device's supported ranges, waits for the readback, and prints
  `{"changed","original_rate","rate"}`. Equal rates are a no-op.
- `display-audio refresh UID JOURNAL RATE` restores `RATE` instead of the rate it found. The
  journal records that rate as `original`, so an interrupted refresh recovers to it.
- `audio.sample_rate` (default 48000, `null` disables) is validated at startup. Each audio
  sync (every 30 s and after transitions) sets PG or BenQ when its rate differs, skips the
  monitor just refreshed, and never touches the built-in speakers. A refused change is
  logged once per device and reported as `rate_refused`; routing still completes.
- The installer writes `sample_rate: 48000` into existing configurations.

Rollback: `rollback.py`; an older controller ignores `sample_rate`.

## Validation

- 344 unit tests (3 new), including drifted-monitor, refresh-ends-at-rate, disabled policy,
  refused-once and validation cases; `./scripts/verify --native`.
- On Mac A with the rebuilt helper: `rate` for PG and BenQ at 48 kHz returned
  `changed:false`; an unknown UID and a malformed rate exited 1.

## Not done

Not exercised: an actual 44.1 → 48 kHz change by the controller on hardware, a monitor that
does not list 48 kHz, and an interrupted refresh with a target rate.
