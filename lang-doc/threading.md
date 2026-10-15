# UBE 1.0 threading and memory model

**Status:** normative UBE 1.0 contract for Compiler v3

This contract supplements the source forms and lifecycle rules in
`v3-language-definition.md`. Thread support is linked into programs that use it;
there is no external scheduler or VM.

## Ordinary shared access

All normally visible program state remains accessible from every UBE thread.
Scalar and managed-reference reads/writes are non-tearing and observe a
complete value written by some thread. The implementation cannot invent an
out-of-thin-air value, access freed storage, introduce LLVM undefined behavior,
or corrupt collector metadata because user synchronization is absent.

Unsynchronized competing accesses are nevertheless a logical data race. Their
relative order and final result are unspecified. Custom values and arrays may
expose a mixture of complete field/element writes unless protected; no mixture
may contain an invalid managed reference. Programs requiring an invariant use
`SyncLock`, atomics, or message passing.

## Happens-before ordering

The following establish visibility in addition to each thread's source order:

- evaluation of `CallNew` arguments happens before the worker begins;
- a worker's actions happen before a successful `ThreadWait` returns;
- outermost `SyncLock` release happens before the next successful acquisition
  of the same object monitor;
- all approved atomic operations participate in one sequentially consistent
  order;
- `ThreadEvent.Set` happens before a waiter released by that signal;
- `Semaphore.Release` happens before the acquisition consuming that permit;
- enqueue happens before the matching FIFO dequeue exposes a message; and
- synchronous event dispatch completes before `RaiseEvent` returns.

Compiler/backend transformations must preserve these relationships and the
observable ordering of errors, callbacks, hooks, volatile foreign transitions,
and synchronization.

## Coordination library

Because UBE 1.0 constructors are parameterless, configured synchronization
objects use factories:

```ube
Function CreateThreadEvent(Optional ByVal ManualReset As Boolean = False, _
                           Optional ByVal InitiallySignaled As Boolean = False) _
                           As ThreadEvent
Function CreateSemaphore(ByVal InitialCount As LongLong, _
                         ByVal MaximumCount As LongLong) As Semaphore
```

`ThreadEvent.Wait(timeout)` follows the common 1/0 wait convention. Auto-reset
events release at most one waiter per signal and consume the signaled state;
manual-reset events release all current/future waiters until `Reset`. `Set` and
`Reset` are idempotent and return `Long` 1 on success, 0 plus `Err` on an invalid
or unloaded object.

`Semaphore.Wait(timeout)` consumes one permit. `Release(Optional Count = 1)`
adds permits and returns 1; nonpositive release, overflow beyond maximum, or an
invalid object returns 0 plus `Err`. Waiter selection is fair FIFO subject to
cancellation and host scheduling.

`MessageQueue.Enqueue(ByVal Value As Variant)` copies a value into the FIFO;
object payloads retain their shared reference. `Dequeue(ByRef Value As Variant,
timeout)` returns 1 and writes `Value` only on success. Timeout/cancellation
returns 0 and leaves the destination unchanged. Queue unload wakes waiters with
0 plus `Err`.

## Cancellation and errors

`ThreadRequestStop` is a sticky cooperative flag. It wakes all approved UBE
waits for that thread. Cancellation itself does not set or clear `Err`; the
worker detects it with `ThreadStopRequested()` and returns normally. A genuine
wait failure sets that thread's `Err`; timeout does not.

`On Error` state and active handlers are per thread and per procedure under the
core specification. A handler runs on the thread where the error occurred.
Cancellation never jumps into a handler. Returning after cancellation releases
locals and monitors on the ordinary compiler-generated cleanup edges.

## Callbacks, locks, and unload

Assignment to a `WithEvents` field changes its subscriptions as one ordered
operation. Event dispatch observes the subscription set present when that
dispatch begins. Removing a connection before its handler's turn skips that
handler; adding one during dispatch affects the next dispatch. Concurrent
assignment, dispatch, and unload must remain memory-safe and must not call
through a stale object identity.

Linked support never holds an internal collector, handle-table, dispatcher, or
queue lock while invoking arbitrary user code. Explicit user `SyncLock`
ownership remains visible and is not silently dropped around callbacks.
Recursive synchronous events are allowed as specified.

A raw native callback admitted through an `AddressOf` entry thunk registers an
otherwise unknown native thread for the duration of the call, establishes its
thread-local `Err`, publishes a GC transition record, and rejects admission
after orderly shutdown has closed callbacks. It cannot unwind an error through
foreign frames. User code remains responsible for unregistering the external
callback before its UBE code or foreign recipient is unloaded.

Accepted form/control unload prevents new calls and callbacks, releases native
UI resources, and lets active procedures on all threads drain. Final
termination waits for active calls and monitor users without blocking the
initiating thread on another UBE thread. Transparent UI dispatch detects a
direct dispatch-wait cycle and reports controlled failure; general user lock
cycles are not required to be detected.

## Limits and cleanup

Thread creation is bounded by available address space, host facilities, and a
documented configurable program limit. Failure returns ID 0 plus `Err` and
leaves no partial thread. Each thread has guarded stack growth or an equivalent
checked maximum; exhaustion records a controlled error and unwinds rather than
crossing a guard page uncontrolled.

Identifiers increase monotonically as nonnegative `LongLong` values and are
not reused during the process. If the positive ID space is exhausted, further
creation fails permanently with 0 plus `Err`. Completed threads release native
handles, stacks, roots, wait registrations, and transient errors while keeping
only bounded completion metadata needed by the public API.

## Orderly shutdown

Normal process shutdown begins only after the agreed live-thread and active-
event-source counts reach zero. Shutdown then rejects `CallNew`, new callbacks,
and new exported calls; drains already admitted linked-support work; runs module
termination in reverse order; releases roots; performs final collection; and
returns the process code. Module termination cannot start new threads or event
sources. Attempts return neutral failure plus `Err` and cleanup continues.

Forced host termination, power loss, or library removal that bypasses the
generated orderly shutdown entry cannot guarantee user cleanup.
