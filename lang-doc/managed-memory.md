# UBE 1.0 managed-memory contract

**Status:** normative UBE 1.0 contract for Compiler v3

UBE has automatic, cycle-safe, precise tracing garbage collection. The
collector and its target-specific primitives are linked into each native
program that needs managed memory; there is no external runtime or VM.

## Managed values and roots

Managed values include variable strings, arrays containing managed data,
objects/classes/forms/controls, boxed Variant payloads, and hidden storage for
recursive custom-type edges. The compiler emits exact layout metadata; the
collector never guesses pointers by scanning arbitrary integer bytes.

Roots are:

- initialized globals, module variables, and Static locals;
- live managed locals, parameters, results, and compiler temporaries on every
  UBE thread;
- active forms, controls, callback registrations, monitors, waits, and message
  queues that retain managed values;
- exported foreign-ownership leases; and
- explicitly pinned values held across a documented foreign call.

Ordinary native integers, opaque OS handles, unmanaged buffers, and resources
owned by user code are not collector roots unless represented by one of those
managed containers.

A live `WithEvents` connection is a precise managed edge from the event source
to the receiving module or object. It keeps an object receiver valid while the
source is reachable, but it is not independently a root. Consequently a source
and receiver that retain only one another remain collectible as a cycle. A
standard-module receiver is already retained by its module root.

A populated form default-instance slot is a precise managed root. A loaded
form or control is additionally retained by its active framework/event-source
registration until accepted unload. Merely declaring a form/control type, or
allocating an identity that has never been loaded, does not create an active
event-source root. Accepted unload clears the matching default slot and aliases
under the identity-wide lifecycle before reclamation can occur.

## Safe points and thread coordination

Compiler v3 emits safe points at allocation, UBE call boundaries, loop
backedges, blocking waits, `ThreadYield`, callback transitions, and explicit
`CollectGarbage()` calls. Root locations are published before a thread blocks
or enters foreign code.

The initial implementation may use coordinated stop-the-world tracing. A
thread reaching a collection request rendezvous completes its current
noninterruptible primitive, publishes roots, and pauses. A thread blocked in a
known UBE wait is already safe. A foreign call uses a transition record so
collection can trace its pinned arguments without interpreting the foreign
stack. Later concurrent/incremental collectors may replace this algorithm only
if every observable contract remains unchanged.

## Barriers and movement

Every write of a managed reference into a heap/global/static container passes
through the versioned write-barrier intrinsic. Bulk array/custom-value copies
perform the equivalent range barrier. Compiler verification rejects IR paths
that can publish a managed reference without the required barrier.

Object identity and recursive-edge identity never expose raw addresses. The
collector may move managed allocations. Foreign code receives handles or
explicitly scoped pins, never an address whose stability is assumed after the
pin ends. Pinning is bounded and cannot be used as permanent general storage.

## Collection and finalization

Automatic collection is mandatory and scheduled by allocation/memory pressure,
cycle work, and orderly shutdown. `CollectGarbage()` requests a full synchronous
pass over the snapshot and returns the approved 0/1 status.

Unreachable classes with `Class_Terminate` enter a once-only finalization
queue. Their storage stays valid through the callback, but resurrection is a
controlled error and cannot restore reachability. After finalization, the
collector rechecks only references needed for safety and reclaims the object.
Unrelated finalizer order is unspecified. Deep/cyclic traversal uses bounded or
iterative work storage and must not overflow the native call stack.

When a receiving object leaves scope or becomes eligible for finalization, its
`WithEvents` connections stop admitting new callbacks and are disconnected
before `Class_Terminate` begins. A callback already admitted remains an active
call and drains under the ordinary unload/finalization rules. Disconnecting the
event edge does not clear unrelated aliases to the event source.

## Low-memory behavior

Allocation failure first requests collection and retries once after eligible
termination. If the requested allocation still cannot be satisfied, the
operation returns its neutral result and records an out-of-memory error when
execution can safely continue. Partially constructed values are unwound and
their initialized managed fields released.

If the program cannot allocate the minimum bookkeeping required to preserve
memory safety or report a recoverable result, linked support enters the
controlled noninteractive fatal-failure path. It emits a bounded diagnostic
through the configured diagnostic sink when possible, performs only cleanup
that requires no unsafe allocation, and terminates without memory corruption,
panic UI, or continued execution in an invalid state.

## Required verification

Conformance includes roots in every storage class, cycles, deep graphs,
cross-thread publication, barriers during bulk copy, waits/foreign transitions,
exactly-once termination, forbidden resurrection, pin expiry, allocation retry,
partial construction, `WithEvents` receiver cycles and disconnection, and
synthetic bookkeeping exhaustion.
