# Partitioned byte-key ordering native oracles

This gate checks the actual `std-lib/src/portable/ByteKeys.bas` implementation
for the approved First semantic checking dependency. Partition is an opaque
signed Long grouping supplied by the caller. Value is an uninterpreted caller ID.
Identifiers, Unicode folding, scopes, accessibility and diagnostics stay outside
this generic facility. Inputs are immutable borrowed arrays for each call.

`ByteKey` contains four Long fields: Partition, FirstByte, ByteCount, Value.
`TryOrderByteKeys(Bytes(), Keys(), KeyCount, MaximumKeys, Order(), Failure)`
validates the prefix KeyCount and every selected span before any allocation,
then publishes one independent Long vector containing the selected key indexes.
Sort order is Partition numerically, then unsigned byte lexicographic (shorter
equal prefix first). Equal partition/byte keys retain input-index order; Value
never participates. KeyCount0 atomically empties old Order. Arrays have natural
nonnegative Long lengths; there is no compiler-specific key cap. Count above
MaximumKeys is caller budget2; invalid count/cap/span is domain1. Storage/root
failure is5; caller seeds5 before managed entry. Success is0. Logical failures
preserve Err; all failures preserve the old Order.

`TryFindByteKeyRange(Bytes(), Keys(), Order(), Partition, FirstByte, ByteCount,
FirstMatch, MatchCount, Failure)` finds an equal-key contiguous group or returns
its insertion position and count0. The query is an arbitrary validated byte span
in the same arena, not necessarily an existing Key record. It validates input
span, order length, every visited order index and visited key span. Sorted,
immutable builder-produced Order remains a precondition; detecting corruption
in every unvisited entry would require the forbidden per-query full scan.
Both scalar outputs commit only after lower and upper boundaries succeed.
Outputs must be distinct and not alias inputs/Failure. No references are retained;
independent calls have private scratch. Sharing frozen arrays is safe with owner
lifetime retained; caller synchronization is required for mutation.

Before native observation, fix these bounds for N selected keys, L=ceil(log2 N)
(L=0 at N0/1), byte length maximum M, and observed array/GC headers A/G:

- Stable bottom-up sorting uses at most N*L comparisons, N*(L+2) executed scalar
  ordering writes, two N-entry scratch/order arrays and a final independent
  publication. At most 3*N allocated Long payloads are physically retained per
  attempt, including uncollected scratch; exact successful publication copies
  4*N bytes and no other payload. Original source/key byte copying is zero.
- At most four allocator calls for nonempty construction and zero for empty
  construction; at most 12*N+3*(A+G)+8 requested bytes. Physical additional
  collector payload is at most 12*N+3*A. The8 bytes is existing publication
  workspace. Callback-observed peak includes every live-byte increase. Report
  requested bytes, actual calloc zeroing, reachable arrays and retained garbage
  separately. Scratch is released before publication.
- Every comparison reads at most twice the smaller compared byte length;
  distinct partitions read zero key payload. Constructor validation uses at most
  8*N+16 key-record accesses and does not allocate. All total record accesses
  remain O(N + comparisons), tested with an explicit 16*(N+comparisons)+32 cap.
- Each query performs two binary boundaries, each at most
  ceil(log2(N+1))+1 comparisons, with zero allocation/copy/order writes.
  No scan to find a partition or equal-key group. At most eight key-record
  accesses per comparison plus16 fixed accesses. Serial peak additional roots
  are bounded by512 independently of N, including construction and lookup.

Merge endpoints are formed using remaining-count subtraction; width doubling
uses Count/2 rather than unchecked multiplication. No recursive sorting or
source-controlled native stack is allowed. Validation uses Length-First spans
before forming offsets. Ordinal indexes and partition comparison never subtract
arbitrary signed operands.

Preset cohorts N0,1,8,64,1024,16384 include reverse/ordered keys, stable duplicate
groups with duplicate Values, extreme signed partitions, same bytes in different
partitions, empty/NUL and long common prefixes, nonzero query spans and misses.
Independently authored complete small oracles and known larger constructions
must pass both source-built stages with raw LLVM equality. Exercise invalid
count/budget/record/order/query, exact/below/above caller budgets, every actual
allocation-denial site and real root capacity zero through exact-plus-one for
constructor and query. Retain an unrelated old order and source/key owners,
check complete preservation, cleanup and recovery. Wrong expected order and
native counter/copy/heap controls must be rejected.

Run `powershell -NoProfile -File std-lib/tools/check-byte-keys.ps1
-SelectionPath <selection.json>`. Both source-built stages must pass exactly
4,827,069 assertions and 90 observation rows, with identical complete streams;
the four altered native expectations/counters must each fail. Actual malloc,
calloc, realloc, deep-copy callbacks and array-element accesses are counted.
The maintained observer helper audits all five live-byte mutations, both growth
sites and all seven atomic root-state accesses before creating a private runtime.
Nine deliberate source corruptions exercise increment, subtraction, reset,
address escape, reservation, removal, closure and extra-access rejection. The
native copy/heap control independently observes 16 actual copied Long bytes and
one actual heap increment. Callbacks contain only TLS scalar bookkeeping.

Each invocation emits exactly one `Evidence:` report path beneath
`bootstrap/out/byte-keys/`. The report records accepted selection, all maintained
inputs, tools, commands, generated source/LLVM/object/executable identities,
positive and negative native outputs, and assertion checks. Missing or invalid
selection fails with a report before source emission. Historical draft evidence
remains under `bootstrap/out/byte-key-order/`; maintained gates never depend on it.
