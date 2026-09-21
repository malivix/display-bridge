# Stage restore payloads before replacing live files

Restore currently deletes each destination before copying the validated backup. A write
failure can leave a partial file or bundle and discard the previous destination. Stage
each existing backup payload in a private temporary directory beside its destination,
then replace the destination only after copying succeeds. Files and symlinks use rename;
nonempty directories still require removal before rename. Absent backup entries retain
their intentional removal behavior.

Test partial-copy failures for files and bundles, preservation of current contents, temporary
cleanup and successful retry. Keep snapshot validation before mutation. This is per-payload
protection, not a whole-restore transaction: earlier entries and the release pointer can
already have changed, and directory replacement retains an interruption window. No schema
change; old backups and previous source remain compatible. Tests use temporary files only.
