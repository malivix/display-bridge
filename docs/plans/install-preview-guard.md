# Guard queued preview work before installation

Reject a queued preview request, unresolved journal or damaged journal before creating
installation directories or changing root permissions. Repeat the check after taking the
exclusive installation lock; request enqueue uses the same lock. Do not consume, delete,
repair or reset pending evidence. No new persistent fields; source rollback is sufficient.
Test early rejection preserves file bytes, directory inventory and permissions. Inject a
request between the initial guard and lock acquisition to prove the locked recheck stops
before compilation or service work. Normal installation still checks live hardware later.

Use an ExitStack for the installation, maintenance and controller lock handles so early
exceptions release them even when a caller retains the exception traceback.
