# Fresh thread status primitives

The owner approved the existing-language threading prerequisite for bounded
compiler work. `src/portable/Threads.bas` exposes fresh Boolean request status
over existing program thread identities and cooperative stop/completion semantics.
This is not an executor, scheduling algorithm or complete threading library.

True preserves incoming Err and publishes a fresh ByRef result. False preserves
that output and records a new error occurrence. Completed=False is a processed
timeout/interruption, not permission to release a live worker's state. A successful
Completed=True wait provides visibility of that worker's preceding actions.
IDs are positive LongLong program identities, never handles or pointers; zero,
unknown IDs, self waits and timeout values outside -1..4294967295 fail.

The public names, argument order and primitive roles are declared next to each
function. Every parameter/output is borrowed for the call. These operations
retain no source, compiler state or managed output array; they copy only fixed
scalar results. Native records/events have explicit native lifecycle ownership.
Cancellation is sticky and cooperative. Callers stop admission and drain their
own workers before releasing shared state. Worker budgets and deterministic
publication are consumer policy, not library platform behavior.

The initial Windows adapter is included by the bootstrap runtime to reach its
existing TLS/registry mechanisms. Its removal condition is an independently
qualified native library/runtime binding for the same contracts, without moving
consumer policy into C. Fresh status compares error revisions, so a stale error
number equal to a new error still cannot masquerade as success. Boolean output
storage is one byte; native status returns are explicitly int32_t.

Before claiming qualification, test every output on success/failure/timeout,
stale Err, actual native/UBE TLS isolation, invalid IDs/timeouts, wait-admission
failure and stop/drain. Verify both source-built stages and preserve earlier
library gates. Implementation alone does not qualify these declarations.
