# Explain optional Shortcuts in the everyday guides

Added a user-facing guide for availability, action discovery, the six status fields,
request outcomes, and simple status/timed-pause workflows. It distinguishes saved
intent from reported controller state and explains uncertain outcomes without
suggesting automatic retries. Timers start when the request is saved, and resume
preserves manual audio overrides.

README, usage, installation and the documentation index link to the guide. The
changelog now identifies the 2.11.0 source milestone and includes the recent UI and
installer-interruption changes. Neither the guide nor changelog claims production
activation or a qualified binary release.

Action names, fields, limits and semantics were checked against current Swift and
controller source and the recorded isolated Shortcuts execution. Local link
destinations and whitespace were checked. This documentation change needs no new
runtime tests; it does not install anything or run a pause/resume command.
