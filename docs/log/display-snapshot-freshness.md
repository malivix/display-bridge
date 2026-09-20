# Persistent display snapshot freshness notice

Displays now keeps the last accepted reading separate from refresh state. Failed or
malformed responses preserve that reading and show an explicit warning above the report.
The notice uses existing health updates to distinguish changed inputs, unknown input
comparison, unavailable controller, non-ready state and matching input reports. It never
claims matching inputs establish unchanged display modes. No new hardware polling occurs.

Validation: the first native build caught an incorrect Swift dictionary keys call; it was
fixed before rebuilding. `scripts/verify --native` then passed 223 Python tests and all
native checks. Native regressions cover initial/no-reading state, input mismatch, invalid
input types, stale health, refresh failure preservation, refreshing and successful retry.
The rebuilt hardware-free demo showed changed-input and failed-refresh notices at Largest
text size without clipping, with the previous reading retained. Full VoiceOver and physical
switching qualification remain pending. Installed code was not changed.
