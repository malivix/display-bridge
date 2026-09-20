# Installation guards queued preview work

Installation now rejects queued preview requests and unresolved/corrupt preview journals
before creating directories or changing state-directory permissions. It repeats this check
under the exclusive installation lock, which preview enqueue/start also use. Requests and
journals are preserved. Completed previews with recovery queued still permit installation.

An injected failure exposed an unclosed installation lock. All three installer lock handles
now use an ExitStack and close on every exit, independently of exception traceback lifetime.

Validation: `scripts/verify` passed 229 tests after the fixes, without the earlier resource
warning. Regressions cover queued and malformed requests, a dangling request symlink,
active/corrupt journals, byte/inventory/permission preservation, an intervening queued
request, and a completed preview. The lock-release case retains the exception traceback
and successfully reacquires the lock, proving release does not rely on garbage collection.
This is isolated installer coverage; no installed files, services or hardware changed.
