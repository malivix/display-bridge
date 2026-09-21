# Visible unconfirmed monitor requests

A failed command or malformed response now marks the affected monitor's compact summary
as Request unconfirmed while retaining its dated previous readings. Only a validated
response for that monitor clears its warning. A response is attributed to the original
command target, using the same strict option parsing as successful decoding; ambiguous
or unknown targets cannot mark an unrelated monitor. No new hardware request or retry.

Validation: `scripts/verify --native` passed (290 Python tests plus native checks).
Native regressions cover ambiguous/unknown command targets, warning isolation, preserved
reading dates, success on the other monitor, and successful clearing on the affected one.
A new isolated demo at Largest text and minimum window size displayed the warning above
synthetic 30% brightness and 40% volume after malformed-response rejection. The detailed
error remains below the controls; the compact warning is visible without scrolling.
No installed release or physical monitor was changed. Hardware and VoiceOver speech
qualification remain separate.
