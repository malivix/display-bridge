# Current arrangement speaker preference

Audio previously required scrolling to learn which saved profile preference explained
the selected output. It now presents that preference beside the observed output, using
existing profile choices and defaults. The summary does not claim routing succeeded.
Unknown profiles, unreadable controls, malformed preference dictionaries and disallowed
speaker values report unavailable. Stale arrangements are labeled last-known; pause
explicitly says the preference is not being applied. Temporary preservation retains its
expiry/Resume presentation and blocks repair through the unchanged policy.

Routine repair guidance moved to the button's tooltip/accessibility help. Blocking
reasons and listening-check responses stay inline. This is presentation only; no routing,
recovery, headset-preservation or persistence behavior changed.

Validation: `scripts/verify --native` passed, including 297 Python tests and native
builds/self-tests. New summary cases cover all four default profiles, preservation
preferences, stale status, pause, unknown profiles and malformed/disallowed preferences.
The current-build isolated demo at Largest text/minimum window showed selected output,
current preference and the three audio actions together. Manual preservation showed
expiry, Resume and disabled Repair with its blocking reason. Screenshots remain ignored.
No playback, routing, notification, clipboard or installation command was submitted.
VoiceOver speech, light appearance, headset hardware transitions and actual audio remain
unqualified; no new CI run is claimed.
