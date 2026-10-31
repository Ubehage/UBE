# Owned byte buffer contract

Status: adopted contract. Current source-body qualification, exact source/tool
identities, functional and instrumented results are recorded in
[BYTE-BUFFER-EVIDENCE.md](BYTE-BUFFER-EVIDENCE.md). This document fixes semantics
and predeclared cost budgets; changing verification snapshots belong in that
evidence record. It does not claim a released library binary, a built Library
manifest, or an immutable Text datatype.

The approved [managed-storage work](MANAGED-STORAGE-PROPOSAL.md) supplies value
copying, precise roots, barriers and controlled allocation failure. The buffer
algorithm belongs to [ByteBuffer.bas](src/portable/ByteBuffer.bas); strict UTF-8
decoding remains in [Utf8.bas](src/portable/Utf8.bas). Both are ordinary UBE
modules. `UBECore.UBE` now lists both sources; building its full Library envelope
remains a separate qualification step.

## Representation and ownership

`ByteBuffer` is an ordinary value record with `Storage() As Byte` and
`Count As Long`. These fields are reserved implementation state. The zero
record is an empty buffer with zero capacity. Storage created by this module
uses zero-based byte positions. Its invariant is `0 <= Count <= Array.Length(Storage)`.
Every public operation checks that count invariant before accessing logical
contents. Direct field modification is unsupported; detectable malformed counts
receive the explicit rejection behavior below.

The logical bytes occupy `[0, Count)`. Remaining capacity is not logical input
and may retain earlier bytes after clearing. Clearing is not secure erasure.
Assignment, ByVal parameters and results have the language's independent value
semantics, including storage. Mutable instances have one owner; callers
synchronize access to a shared mutable instance. Different instances need no
shared scratch space or user-visible global state. Calls retain no input
reference. Array and record storage is reclaimed by the managed runtime when
unreachable; the module owns no external resources.

## API

| Declaration | Successful result | Rejection/failure |
|---|---|---|
| `ByteBufferLength(ByRef Buffer As ByteBuffer) As Long` | Logical byte count. No allocation. | `-1` for malformed state. |
| `ByteBufferCapacity(ByRef Buffer As ByteBuffer) As Long` | Allocated byte capacity. No allocation. | `-1` for malformed state. |
| `TryReserveByteBuffer(ByRef Buffer As ByteBuffer, ByVal MinimumCapacity As Long) As Boolean` | At least the requested nonnegative capacity; count and logical bytes preserved. A satisfied request allocates nothing. | Fresh `False` for malformed state or negative minimum. Allocation failure preserves contents, count and capacity. |
| `TryAppendByte(ByRef Buffer As ByteBuffer, ByVal Value As Byte) As Boolean` | Appends one byte, including zero, with geometric capacity growth. | Fresh `False` for malformed state, unrepresentable new count or allocation failure; old contents, count and capacity preserved. |
| `TryAppendBytes(ByRef Buffer As ByteBuffer, ByRef Source() As Byte, ByVal SourceStart As Long, ByVal ByteCount As Long) As Boolean` | Appends the original specified source range; SourceStart is a zero-based payload offset from Source's first stored byte regardless of language lower bound. Zero length is valid at the end of Source. Source may be `Buffer.Storage`, including overlap. | Fresh `False` for malformed state, a negative range, a range outside Source, an unrepresentable new count, or allocation failure; old buffer preserved. |
| `ClearByteBuffer(ByRef Buffer As ByteBuffer) As Boolean` | Sets count to zero and retains capacity without allocating. | Fresh `False` for malformed state, which remains unchanged. |
| `TrySnapshotByteBuffer(ByRef Buffer As ByteBuffer, ByRef Result() As Byte) As Boolean` | Replaces Result with exactly Count independently owned bytes. Reusing or clearing Buffer cannot change that result. | Fresh `False` for malformed state or any allocation failure. Both the old Result and Buffer remain unchanged, including failure in the final publication copy. |
| `TryCountUtf8Scalars(ByRef Buffer As ByteBuffer, ByRef ScalarCount As Long) As Boolean` | Strictly validates logical bytes and returns Unicode scalar count. Empty input has zero scalars. No allocation. | Fresh `False` for malformed state, malformed UTF-8 or truncation; ScalarCount is zero. |

All domain rejections and successful calls preserve the incoming thread-local
Err. An ordinary allocation failure returns fresh `False` with Err 7 after the
runtime's specified collection/retry policy; status is never inferred from Err.
`ScalarCount` must not alias Buffer fields. Snapshot Result must not be
`Buffer.Storage`: a caller cannot request an independent output and simultaneously
make that output the builder's own storage holder.

## Primitive boundary and failure atomicity

The source declares functional intrinsic names bound to these explicit roles:

| Role | Required primitive contract |
|---|---|
| `Array.Length` | Returns physical element count; null/default array has length zero. No allocation and preserves Err. |
| `Array.TryResize` | Typed zero-based resize by element count; Preserve retains existing bytes up to the new count. Fresh Boolean status, failure-atomic destination, checked target-sized allocation, collection/retry and Err behavior. |
| `Array.TryCopy` | Independently copies a typed array into the destination. Fresh status, allocation failure leaves the old destination unchanged. |
| `Memory.CopyBytes` | Checked byte-range copy with original-input overlap semantics. Range positions count from zero. Allocation-free and Err-preserving; succeeds for validated in-bounds live Byte arrays. Invalid ranges fail without writes. |

Append validates state, source range and count arithmetic before reserve.
Reserve is the only fallible allocation step. The subsequent checked bulk copy
cannot fail for those prevalidated single-owner ranges and performs no allocation.
When Source is the storage holder itself, resizing preserves its existing prefix
and the ByRef source follows that same holder; the overlapping copy then observes
the original range. This guarantee depends on the stated primitive contract.

Snapshot prepares a separate exact-length array, copies Count bytes into it,
then publishes with failure-atomic `Array.TryCopy`. A failed publication cannot
destroy an earlier Result. No ordinary UBE algorithm is hidden in C: the linked
support implements typed allocation, root-safe access and bulk memory movement.

The generic C program-support implementation is a bootstrap exception for these
irreducible allocation/root/atomic/copy operations. Replace it only after
UBE-emitted or type-specialized support satisfies these same managed, functional,
failure, cost and concurrency gates. All buffer growth, range policy, validation
and UTF-8 algorithms are already ordinary UBE; the exception is not permission
to move those algorithms into C.

## Costs declared before measurement

Capacity starts at 8 and doubles until it reaches the requested minimum. When
doubling would exceed signed Long, the algorithm uses the already-validated
minimum directly. All additions and multiplications are guarded before execution.

For N successful single-byte appends to an initially empty buffer, without
failure injection, preserved payload copying during growth must be less than
`2*N` bytes. For N from 1 through 8 final capacity is 8; for larger N final
capacity is at least N and less than `2*N`. Requested payload allocations follow
the explicit capacity sequence `8,16,32,...`; retries and runtime bookkeeping
must be reported separately rather than concealed inside an algorithmic count.
Appending a range additionally copies exactly its ByteCount payload bytes.

A successful snapshot copies at most `2*N` payload bytes for logical length N:
N into the prepared array and N into independently published Result. Its fresh
array zero-initialization is separate work and must also be measured. Clear,
length/capacity queries, satisfied reserve and UTF-8 validation request no payload
allocation or copying. A successful UTF-8 scan feeds exactly Count bytes and
finishes once. Malformed input can reject before Count bytes or before Finish;
truncated input feeds the available bytes and rejects at Finish. Allocation,
copy, zeroing, live bytes and collection observations must come
from executed runtime operations, not counters inferred from requested sizes.

## Independent acceptance and first consumer

[The fixture oracles](tests/byte-buffer/ORACLES.md) fix observable results and
cost obligations before native execution. Maintained verification commands:
`rtk proxy powershell -NoProfile -File std-lib/tools/check-byte-buffer.ps1`.
`rtk proxy powershell -NoProfile -File std-lib/tools/check-byte-buffer-costs.ps1`.
The combined source-build gate binds both reports to the same immutable compiler
selection before publishing it. Current results and limitations are in
[BYTE-BUFFER-EVIDENCE.md](BYTE-BUFFER-EVIDENCE.md).

The required qualification includes injected
failure during reserve and both snapshot preparation/publication, stale Err,
overlap with and without growth, malformed state, all Byte values, exact snapshot
length, independent record copies, scope cleanup and independent worker instances.
The existing rootless decoder acceptance gate must retain its zero-allocation
result. These obligations are executable acceptance checks, not conclusions
inferred from successful compilation; their recorded executions belong in the
evidence file.

The first intended compiler consumer reads source bytes into one owned builder,
validates logical UTF-8 with `TryCountUtf8Scalars`, and obtains an independent
exact-length byte snapshot. Source token positions continue to use byte offsets.
File I/O, tokenization and builtin String replacement are separate concerns.
Publishing this snapshot does not establish an opaque immutable Text class;
callers own the returned Byte array under ordinary value semantics.
