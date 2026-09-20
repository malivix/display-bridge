# Preserve damaged transition history without blocking switching

Reproduced record() replacing malformed history with a fresh list. Bound history JSON reads,
reject nonregular files/symlinks without blocking, and preserve existing unreadable/non-list
history by raising the error already caught by the controller's logging wrapper. Summary
reports unavailable for rejected history. Missing history still starts a new bounded list.

Serialize within the 1 MiB bound before writing; reject nonfinite values. Use a private unique
temporary file and atomic replacement, cleaning the temporary on failure. Keep the existing
200-event retention policy. No automatic corruption repair, history deletion or hardware
changes. Validate pipe/link rejection in bounded child processes, malformed bytes, oversized
new events, file privacy and ordinary append behavior. Rollback restores the module; no schema migration.
