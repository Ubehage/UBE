# Partitioned byte-key ordering

Implementation: [ByteKeys.bas](src/portable/ByteKeys.bas). This reusable facility
supports the approved semantic-checking foundation. Its maintained native gate is
`powershell -NoProfile -File std-lib/tools/check-byte-keys.ps1 -SelectionPath <selection.json>`.
The gate compiles the actual module through both verified source-built stages;
reports and private instrumentation are written beneath `bootstrap/out/byte-keys/`.
Coordinated source-cohort acceptance remains necessary after a source change.

## Values and ownership

`ByteKey` is a caller-owned record with four Long fields:
`Partition`, `FirstByte`, `ByteCount`, `Value`. Partition is an opaque signed
grouping. Value is an uninterpreted caller ID and never influences ordering.
The module knows no identifier, case-folding, package, scope or access policy.
Bytes may contain any unsigned byte, including zero; no encoding or locale is
applied. FirstByte/ByteCount address zero-based payload positions.

Inputs are immutable borrowed arrays during an operation; the module retains no
reference. The caller keeps the arena and key metadata alive and unchanged for
each lookup. Mutable instances have one owner or caller synchronization; frozen
input arrays can be shared by independent calls with private scratch/results.
The module allocates no external resource or global mutable state.

The returned Order vector is independently owned Long storage. An element is a
key's input index, never its Value. The array's physical length is the selected
key count. The caller must retain suitable arena/key owners; owning indexes alone
does not retain their targets. Ordinary array assignment retains its established
independent value semantics.

## API

`TryOrderByteKeys(ByRef Bytes() As Byte, ByRef Keys() As ByteKey,
ByVal KeyCount As Long, ByVal MaximumKeys As Long, ByRef Order() As Long,
ByRef Failure As Long) As Boolean`

Selects the prefix `[0, KeyCount)`. Sorts by Partition numerically, then by unsigned
byte lexicographic order (a shorter equal prefix comes first). Equal partition
and byte keys retain their original input-index order, irrespective of Value.
Empty keys are valid at any valid position, including the arena's end.
Successful KeyCount0 atomically empties old Order. No compiler-specific cap is
imposed; natural nonnegative Long ranges and actual storage limits apply.

Domain1 rejects negative counts/caps, KeyCount beyond physical Keys length or
an invalid selected span. Caller budget2 reports KeyCount above MaximumKeys.
Count/cap admission precedes selected-span traversal; every selected span is
validated before allocation. Unselected key records are not inspected.
All failure paths preserve the complete prior Order; success replaces it once.

`TryFindByteKeyRange(ByRef Bytes() As Byte, ByRef Keys() As ByteKey,
ByRef Order() As Long, ByVal Partition As Long, ByVal FirstByte As Long,
ByVal ByteCount As Long, ByRef FirstMatch As Long, ByRef MatchCount As Long,
ByRef Failure As Long) As Boolean`

Accepts an arbitrary query span in the same arena; no query Key record is needed.
Returns the contiguous equal-key range as a position/count into Order. A miss
returns count0 and the insertion position. Both scalar outputs commit only after
both boundaries succeed. They must be distinct and not alias Failure or inputs.
Every failure preserves both scalar outputs and all inputs.

Order must be a sorted, immutable result of the constructor (or an unchanged
independent copy) for the same arena/key prefix. Lookup checks its physical length
against Keys, every visited index against `[0, Order.Length)`, and every visited
key span. Detectable invalid query/index/span data reports domain1. It does not
scan unvisited records or re-prove sorting/permutation on each use; such a scan
would defeat the bounded lookup contract. Mutating keys/order can violate this
precondition even when the resulting corruption is not visited by a query.

Both APIs return fresh Boolean status. Success sets Failure0 and preserves Err.
Logical domain/budget failures preserve Err, including old Err7. Managed
admission/allocation failure reports5 with runtime Err7 and preserves old outputs.
The caller initializes Failure5 before managed entry because entry can fail
before the body executes. No success is inferred from Err.

## Work and memory

### Bounded operations for native identity inspection

`ByteKeyBudget` is a caller-owned scalar ledger with LongLong fields
MaximumBytes, MaximumEvents, Bytes and Events. Nonnegative limits and counters
are required. Admission uses subtraction before addition and counts actual
comparison-byte read attempts (including rereads), not arena length. Each
admitted input-key visit, key comparison, byte-pair comparison, output-vector
write, lookup step or allocation/publication boundary consumes one event.
Counters survive failure; an event refused by a limit changes neither counter.

`TryOrderByteKeysBudgeted` takes the existing ordering arguments followed by
`ByRef Budget As ByteKeyBudget, ByRef Cancelled As Boolean`. It shares the same
ordering implementation and storage contract. `TryFindByteKeyRangeBudgeted`
additionally takes `ByRef QueryBytes() As Byte` immediately after Bytes; its
query span addresses QueryBytes while keys still address Bytes. It takes the
same final budget/cancellation arguments. Query arrays may be separate immutable
owners; no concatenation, retained reference or query copy is required.

Bounded operations poll the borrowed cancellation Boolean at every admission.
Its owner remains alive through the call and may only set it True concurrently,
under the existing cooperative scalar-request contract. Failure3 is cancellation;
Failure2 includes byte/event exhaustion, Failure1 malformed budget state and
existing domain errors, Failure5 managed entry/allocation refusal. The caller
seeds Failure5 before entry. Earlier result arrays/scalars remain unchanged on
all failures. Success/ordinary rejection preserve Err. Budgets are not global,
and a mutable ledger has one writer. The original APIs retain their existing
unmetered behavior through the same implementation; no compiler policy enters
the library.

Only admitted two-byte comparison attempts can read payload. A managed refusal
between their two reads may retain the admitted pair charge. Publication occurs
after its last cancellation/budget admission; a later request cannot roll it
back. There is no input-controlled recursion or unbounded indivisible scan.

The implementation uses stable bottom-up merging with no recursion. Endpoint addition is
guarded by remaining-count subtraction; width doubling is guarded by Count/2.
For N selected keys it uses at most N*ceil(log2 N) key comparisons and
N*(ceil(log2 N)+2) scalar writes. Comparing unequal partitions reads zero key
payload. A same-partition comparison reads at most twice the shorter byte length.

Construction keeps two private N-entry vectors, releases scratch before one
atomic independent publication, and copies exactly4*N publication payload bytes
with zero other payload/source/key copying. Uncollected scratch can still occupy
physical storage: at most three N-entry allocated Long payloads per attempt,
plus their measured array/collector headers and an8-byte publication workspace.
Successful empty construction allocates and copies nothing. Nonempty construction
uses at most four allocator calls under the currently qualified substrate.

Lookup performs two binary boundaries, each at most ceil(log2(N+1))+1 comparisons,
with no allocation, payload copy, vector write or per-partition/equal-group scan.
Actual record accesses and payload bytes are measured separately. Root depth is
bounded independently of N; failure/resource/lifetime/sharing claims require
their actual native gates, not compilation alone.
