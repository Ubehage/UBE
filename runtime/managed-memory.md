# Precise managed memory runtime interface

Status: concrete implementation contract for the approved managed text increment
in `compiler/TEXT-SUPPORT.md`. The native substrate and ordinary UBE collector
are implemented; broader fault, rendezvous and graph acceptance remains open.
The normative language contract is `lang-doc/managed-memory.md`.

## Collector boundary

`std-lib/src/portable/ManagedPrimitives.bas` is the exact source declaration
surface. Each role is bound by identity and complete signature, never by a
procedure spelling. Collection traversal, discovery queue and choice of
unreachable allocations are ordinary UBE. Native routines provide metadata
access, allocation/release, rendezvous and publication only.

All Try operations preserve output arguments on False, record Err 5 for an
invalid identity/index/state, and preserve Err on success. Zero is the empty
managed identity and is never a raw address. Nonzero identities are issued
monotonically within a program and never reused. Exhaustion is controlled
allocation failure. Foreign-program identities are rejected. Collector access
requires the calling thread to own the stopped snapshot.

`BeginCollection(PriorWork, PriorError)` elects a coordinator, requests every
registered UBE thread to publish its precise roots, and waits until every other
thread is parked or in a published native-safe transition. It holds no heap,
descriptor or worker-registry lock while waiting. True means the caller owns
the stopped snapshot and must call EndCollection exactly once. False means it
joined a round already in progress; the outputs describe that completed round.
Begin does not allocate and does not change Err. PriorWork is zero for a newly
owned round: numeric-only native retirement is not managed collection work.
PriorError is zero for a newly
owned snapshot. Nested collection by the coordinator is forbidden; allocation
within its callback uses the no-recursion path instead.

The coordinator obtains fixed allocation and root counts, borrows a LongLong
workspace with at least AllocationCount entries, then enumerates roots.
`Managed.Workspace` exposes the state-owned 4096-cell queue through an empty
array descriptor. It permits one coordinator lease, requires Preserve=False,
and allocates nothing during collection. The queue is charged at installation
against the same program quota. Count zero releases the lease and empties the
descriptor; empty cleanup is idempotent. The collector releases this lease
before EndCollection on every exit and never accesses it afterward. An oversized
request records Err 7; an invalid descriptor or competing lease records Err 5.
All indices are zero-based. Allocation slots retain stable indices for the
whole round; a reclaimed slot reads as zero. Roots include exact stack/global
slots, return handoffs, construction candidates, worker captures and managed
fields in native payloads retained by an active external owner or interior
alias. Positive reference counts originating solely within managed containers
do not make those containers roots. Integers and opaque resource handles do
not enter this enumeration.

TryMark returns Fresh=True only on first discovery this round. Zero succeeds
with Fresh=False. The UBE collector queues each first discovery, then reads its
exact edge count and each edge identity; these primitives do not follow those
edges. An empty identity has zero edges. Every nonzero edge must identify a live
allocation. TryMarked(0) succeeds with False. Invalid indices or identities are
errors, never confused with exhaustion or an empty value.

After complete traversal the collector calls SealCollection. This allocation-
free transition permits reclaiming unmarked allocations. Before sealing, any
error ends the round with no managed sweep. EndCollection clears all partial
marks and snapshot state without allocation, records the supplied result for
joiners, restores running admission and resumes parked threads. End itself
cannot fail and preserves the caller's Err; the ordinary UBE entry point
decides whether to publish or preserve the collection error.

TryReclaim rejects zero, marked, unknown and out-of-round identities. It needs
no workspace. A target release failure records Err 57 and retains that
allocation and its quota charge for a later attempt; prior successful releases
remain valid. This is distinct from incomplete marking, where no release is
allowed. Native release failure must not unlink storage that remains owned.
The collector reports Work=1 if any eligible managed storage was
actually released, otherwise zero. Work and ErrorNumber are independent.

## Allocation, layouts and roots

The native integration appends managed state and registered-thread head pointers
at program fields 14 and 15, preserving fields 0 through 13. Thread fields 0
through 3 keep error, depth, program and worker-control meanings; fields 4
through 7 hold the root-frame chain, construction-candidate chain, registry-next
link and safepoint state. Field 8 is the managed return-handoff identity and is
always an exact root. Consequently the program field in the enclosing root
context moves from field 4 to field 9, and its fixed size grows by seven cells.
All launchers, worker allocation sizes and generated context-size calculations
must use this one layout before these fields become executable.

The exact root-frame record is `{ next, base, layout, repeatCount }`.
Each construction candidate records its creating frame and owner thread.
Frame exit unlinks its own unpublished candidates without allocating or
invoking collection. It preserves other frames' candidates, including when a
nested helper has already published an ancestor's candidate. Intrinsic wrappers
do not create ordinary source frames, so their candidates belong to the invoking
UBE frame. Layout
records contain `{ strideCells, referenceCount, referenceOffsets, arrayCount,
arrayEntries, ownerCount, ownerOffsets }`; an array entry contains
`{ descriptorOffsetCells, elementLayout }`. Explicit owner offsets occur in
capsule and lease metadata. Each owner pointer is checked against the program's
registered native blocks before its complete retained payload layout is read.
Positive reference counts alone never establish roots. Native block headers
contain `{ next, references, quotaCharge, layout, repeatCount }` (40 bytes).
Offsets count logical eight-byte cells; they never imply that packed text bytes
are language cells. Layout nesting is finite and decoded with a bounded native
metadata walk. Direct offsets enumerate managed slots; array entries enumerate
the exact element layouts behind live descriptors. This is metadata decoding,
not traversal of managed handle edges. Old payload aliases, including ordinary
ByRef aliases, get direct retained-payload frames so descriptor replacement
cannot erase their reachability. Captures require the same treatment.

Managed allocation records share the existing program allocator and its 64 MiB
and 4096-block bounds. Registry metadata and work storage are charged to the
same budget. There is no separate String heap and no hidden quota enlargement.
Packed UTF-8 payload size is measured in bytes; language array storage retains
its existing logical-cell representation. Record metadata names a validated
immutable layout; layout reference offsets distinguish managed identities from
ordinary cells. Layout repetition describes arrays without conservative scans.

Layout addresses are trusted immutable compiler metadata, and descriptors obey
the language's Long-bound representation. The native boundary validates counts,
offsets, missing lists and registered owner blocks; it is not an API for probing
arbitrary native addresses. Source code cannot forge layout pointers or managed
identities through the language-level String interface.

Allocation candidates are zero-initialized and attached to a construction root
before an identity can be returned. They remain private until initialized and
published through the versioned barrier. Abandoning a candidate removes its
construction root; no partly initialized value becomes language-visible.
Allocation pressure calls the linked ordinary UBE collector outside all locks,
then retries allocation once. During a collection callback numeric allocation
cannot recursively invoke collection; failure retains
the heap and EndCollection clears partial state. Successful allocation retry
restores the incoming Err even if opportunistic collection could not allocate
its workspace.

Generated frames publish exact live managed slots before any safepoint.
The concrete noninterruptible native transfer ABI is:

```
ube.managed.root.push(ctx, frame, base, layout, repeatCount) -> void
ube.managed.root.pop(ctx, frame) -> void
ube.managed.root.restore(ctx, sentinel) -> void
ube.managed.load(ctx, source, destinationRoot) -> identity
ube.managed.store(ctx, destinationRoot, identity) -> void
ube.managed.return(ctx, identity) -> void
ube.managed.take(ctx, destinationRoot) -> identity
ube.managed.discard(ctx) -> void
ube.managed.publish.range(ctx, destination, layout, count) -> void
```

Load and take acquire the identity then release-store it into an already
registered root before returning. Store uses a release barrier; its input must
already be precisely rooted. Return publishes the thread handoff before frame
cleanup; take installs its destination before clearing that handoff. Discard
consumes ignored results. None of these operations polls, allocates or calls
UBE, so the transfer window cannot rendezvous with collection. Callers take a
successful String result immediately before any further call or safepoint;
failed String returns clear the handoff. Every managed-capable procedure has
an empty sentinel frame even if it has no other managed slots, giving private
construction candidates a stable owner frame. Additional typed frames can
register distinct referent storage.

Range publication receives the exact initialized payload layout and element
count and executes a release fence before descriptor installation. Numeric-only
copies bypass that managed boundary. Restore pops through the sentinel,
retiring every frame's private candidates without allocation.

Callee results remain in a return-handoff root until the caller has installed
its result root. No poll may occur in an unrooted transfer window. Ignoring a
worker Function result still consumes this handoff. Every ordinary, FAIL,
handler and cancellation exit retires its frame and temporary roots.

Threads register eagerly before executing UBE code. Worker construction roots
cover the interval before native thread creation through publication and frame
registration. Native waits and foreign transitions publish retained arguments
before leaving running state and pass the reentry gate before reading managed
memory. Worker records contain a persistent capsule root installed before
CreateThread and retired after the worker's source frames. No safepoint parks
while holding a heap, stripe or registry lock.
Managed loads/stores and aggregate copies use barriers and retain precise
ownership across each noninterruptible operation. Replacing an array descriptor
does not discard layout information needed by retained old payload aliases.

Typed array resize/copy completes the private payload, then calls
`ube.managed.publish.range(ctx, destination, layout, elementCount)` before
installing its descriptor. The initial stop-the-world implementation uses a
release fence at this boundary; the exact finite element layout identifies
managed cells without treating numeric cells as references. Numeric arrays
bypass this typed boundary. Scalar and record publication uses
`ube.managed.store` for each exact managed offset.

Typed lowering checks publication facts before choosing raw or managed copy
paths: scalar/nominal type identity, element width, exact reference count and
ordered in-bounds offsets must agree with the completed declaration layout.
This rejects inconsistent publication facts; it is not a general LLVM parser
or proof against arbitrary edits to compiler source.
Orderly shutdown first rejects active owners/resources/workers, then retires
global roots and invokes the ordinary collector. Failed reclamation retains
the installed state for retry. Once no managed records remain, state is detached
and submitted to existing native retirement; failed native release retains its
quota charge for a later disposal attempt.

## Linking and acceptance

### Text storage roles

`std-lib/src/portable/TextPrimitives.bas` records the exact typed storage
interface used by ordinary UBE text algorithms. ByteLength and ScalarLength
read the immutable lengths (zero for empty); String parameters/results remain
precisely rooted through the entire intrinsic operation. ReadByte uses a
zero-based packed-byte offset. Invalid offsets return False, Err 9, unchanged
output. No routine exposes a pointer or decodes Unicode natively.

Create takes byte/scalar counts known from the UBE algorithm's complete UTF-8
validation. Negative counts, ScalarCount greater than ByteCount, or exactly
one zero count return False and Err 5. Zero/zero succeeds with Candidate=0.
Nonempty storage is zero-initialized, charged to the common allocator, and
attached to the current frame's construction roots before return. Allocation
failure after collection and one retry returns False/Err 7, preserving the
previous output. The candidate owner must write every byte with WriteByte
before publication; bounds violations return False/Err 9. Candidate identity,
creating thread and unpublished state are checked (False/Err 5 on mismatch).

Publish performs no allocation or collection. It installs the completed
canonical UTF-8 candidate into the rooted destination with a managed barrier,
then consumes the candidate's construction root. Validation and complete
initialization are obligations of the ordinary UBE construction algorithm;
native Publish does not implement a second Unicode algorithm. Failure leaves
the destination and candidate unchanged. Zero publishes empty. Abandon removes
an owned unpublished construction root and succeeds for zero; eventual tracing
reclaims its storage. Ordinary frame unwinding also abandons remaining private
candidates so a failed helper cannot leak construction roots. Successful text
storage operations preserve Err. Boolean-status roles do not raise FAIL;
the ordinary library wrapper supplies required fresh language failure.

Each managed program receives a validated ordinary UBE collector callback
before initialization executes. Native allocation machinery invokes that bound
callback indirectly; it does not embed a graph algorithm. Programs without
managed support have no unresolved collector symbol. Support linkage and its
validated export roles belong to the compiler's text implementation plan.

The collector callback saves the caller's Err and source-call depth and runs
with independent bounded support invocation depth, restoring both on return.
Paused source frames remain precisely rooted throughout. Exhausted source-call
depth must not prevent the collector from entering or ending its round. This
does not remove call-depth checks from arbitrary private source procedures.
Cleanup intrinsics never acquire source-depth admission. The fixed metadata
walker permits 66 metadata levels: the existing aggregate bound of 64 plus
explicit owner/capsule indirection. Missing nonempty metadata lists are rejected
with Err 5 before dereference;
managed graph depth remains handled by the ordinary UBE iterative queue.

This contract is not evidence of full qualification. Acceptance must exercise
actual UBE collector code with exact roots, cycles/deep graphs, integer lookalike
nonroots, failed workspace without sweep, retry/recovery, byte-packed candidates,
retained old array payloads, simultaneous collectors, running/blocked workers,
return/capture handoffs and orderly disposal at O0/O2. Changed-oracle controls
must demonstrate that the assertions detect the relevant failures.
