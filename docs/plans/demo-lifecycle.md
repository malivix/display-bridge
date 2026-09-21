# Keep UI reviews separate from the installed menu

Observed: many private demo copies with distinct bundle identities remained running,
each creating a menu-bar icon. The installed menu had one process; its ownership
lock was not the source of the duplicate icons. Old demos were explicitly stopped.

Give all new demo builds one shared per-user temporary ownership lock, separate
from the production lock. A demo creates no status item and exits after its last
window closes. Its More controls menu remains available through an independent
menu reference. Production remains a single menu process that survives window close.

Verify duplicate different-bundle demos cannot both stay running, a demo has no
status item, closing the window exits and releases the lock, and a later review
can start. Keep the installed controller/menu running throughout. No configuration
or service changes; rollback is the previous coordinated app/controller snapshot.
