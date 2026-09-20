# Copy a reviewed support summary

Details now provides Copy reviewed summary only for Support summary. The copy target is
the displayed body, excluding the view's timestamp/header, and never reads diagnostic files
or other report text. Selecting another report or starting a summary refresh clears it.
The action requires an explicit click, reports copy success/failure and uploads nothing.
Clipboard content is not added to controller state or logs. Review before sharing remains
necessary; this button is not a new sanitizer of arbitrary report data.

Validation: corrected an initial pasteboard API naming compile error, then
`scripts/verify --native` passed 232 Python tests and all native builds/self-tests. New native
cases cover report scope, invalidation and output-size bounds without clipboard access.
A rebuilt demo showed Copy disabled before Refresh, enabled after displaying the synthetic
summary and readable at Largest text size. Clicking showed the demo's clipboard-disabled
notice. The real general-clipboard write was not exercised; user clipboard contents and
installed code were unchanged. Full VoiceOver qualification remains pending.
