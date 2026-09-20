# Preserve timing evidence on failed transitions

Record completed phase durations as each phase finishes. On failure, retain them plus elapsed
application total and an allowlisted interrupted phase and its elapsed time. Never present the
interrupted phase as successfully completed or fill later phases with zero. Keep existing
successful timings and retry/ownership policy unchanged; detection before the first observation
remains unmeasured. Project only fixed phase labels and validated numeric durations publicly.

Exercise failure at rotation, layout and audio through the controller tests, projection validation,
and native report rendering. No journal schema change, hardware test or installation. Existing
readers ignore new optional fields; rollout/rollback remains coordinated.
