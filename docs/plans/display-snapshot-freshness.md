# Display snapshot freshness

Keep the last valid reading separate from refresh status. A failed or malformed refresh
preserves it and marks the failure. Add a persistent status label above the Displays
report, comparing snapshot inputs with fresh controller input observations. Missing or
invalid inputs, unavailable controller and non-ready states must not imply current modes.
Even equal inputs do not prove unchanged sizing, rotation or physical quality. No hardware
polling is added; use the existing health timer. There is no persisted-state migration.
