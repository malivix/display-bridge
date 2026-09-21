# Distinguish retained failures from live status

Size preview and size/brightness preset dialogs retain their first readiness failure so
later recovery cannot silently revive stale actions. Their text now labels that reason
as an earlier failed check and directs reopening for a fresh check. This avoids presenting
the retained reason as a current monitor-status assertion. Eligibility behavior is unchanged.

`scripts/verify --native` passed, including 293 Python tests and native self-tests. A new
signed fixture used the real brightness chooser at 24-point text, with readiness failing
then recovering. After recovery the historical explanation fit, Apply/Save remained disabled,
and keyboard Tab reached the independently eligible Remove action. Escape cancelled.
No hardware, installed services, or clipboard changes. The other two copy changes compiled;
their full appearance/VoiceOver matrix was not repeated. No text-matching test was added
for this presentation-only change.
