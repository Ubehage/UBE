# Bounded source-buffer and record storage

This increment implements the next dependency identified in DEPENDENCIES.md.
It extends the existing project pipeline; it is not a separate compiler or a
claim that the complete self-hosting storage model is implemented. Exact test
evidence belongs in `../compiler/Progress.md`. The dynamic-storage extension
described below has its separate dynamic-storage gate; earlier fixed-storage
evidence alone does not qualify it. Its detailed contract is in
[DYNAMIC-STORAGE.md](DYNAMIC-STORAGE.md).

## Admitted source values

Field-only Type declarations define nominal finite records. Fields may be the
existing scalar types or finite nested records. Recursive records, managed
fields, array fields, opaque native representations and lifecycle hooks remain
unsupported. Fields start neutral. Assignment copies the complete record value
independently, and equality/inequality compare its scalar fields semantically.
Unrelated record declarations do not become compatible because their fields
have the same layout. Ordering is not defined for records.

One-dimensional arrays have scalar or admitted record elements. Fixed declarations
have compile-time-known initial bounds; dynamic declarations such as
`Dim Values() As Byte` begin empty. Negative lower bounds are supported; an omitted lower bound
uses zero in this profile, which does not admit Option Base changes. Bounds and
index expressions use LongLong semantics. Runtime indexing checks the complete
range before computing an element address, reporting Err 9 on failure.
Known-invalid declaration bounds receive compile-time diagnostics. Index
diagnostics use known current bounds only: a conservative project effect fact
invalidates node-bound proofs when mutating primitive declarations or whole-array
replacement occur. Declaration symbols retain their initial bounds.

Ordinary element/field reads and writes, direct ByRef element/field arguments,
and whole-record/whole-array ByRef parameters preserve caller storage identity.
Array parameters declare rank only (`Values() As Byte`, for example) and use
the actual caller's bounds. Receiver/index expressions evaluate once in source
order. A failed destination index prevents RHS evaluation; a failed argument
prevents later arguments and callee entry.

Bare indexed assignment uses adjacent parentheses (`Values(Index) = Value`).
Use explicit `Let Values (Index) = Value` when separating the parentheses.
This bounded parsing rule preserves existing no-parentheses procedure calls
such as `Take (Value) = 1`, whose argument is a Boolean comparison.

Whole-array assignment adopts source bounds and copies independent element
values, including different bounds and unknown caller shapes. Array.TryCopy
provides the same replacement as a Boolean-status operation; Array.TryResize
changes the zero-based element count and optionally preserves the coordinate
intersection. Element type and rank must match, including nominal record identity.
ByVal aggregates, aggregate results and
grouped aggregate ByRef temporaries remain unsupported until their value and
lifetime paths are implemented. Existing scalar ByVal/results/temporaries work
for individual array elements and record fields.

## Storage and failure boundaries

Array descriptors belong to their procedure frame or execution context; dynamic
payloads use separately owned blocks. Prepared element/field aliases retain
their original storage through call completion or abandonment, including later
argument failures. Replacement storage is independent of subsequent old-alias
writes. Indexed assignment destinations retain storage through RHS evaluation
and commit/abandonment. No escaping aggregate references or managed roots are
admitted. ReDim/Erase syntax and managed String remain separate dependencies.

The private native representation flattens scalar record fields into i64 cells.
An array has four descriptor cells: current lower/upper bounds, payload pointer
and owning-block pointer. Initial fixed payload cells follow the descriptor;
dynamic owners occupy only the descriptor, and ByRef parameters borrow it.
Empty dynamic descriptors have bounds 0 through -1 and null pointers.
Field offsets, element strides and nominal identities are
bound metadata, not reconstructed from field spelling during emission. This
representation is not a foreign ABI or a public memory-layout guarantee.

Record copies snapshot source cells. Array replacements prepare independent
payloads before publishing descriptors, preserving self-aliasing and evaluation
order. TryResize/TryCopy return usable Boolean status and record Err on failure;
ordinary assignment translates failed replacement into fresh FAIL without commit.
Allocation failure collects eligible unowned/unborrowed leaf blocks and retries
once. Success preserves sticky Err. Fixed storage
begins neutral before an initializer runs. Declared records and array elements
containing only scalar values require no tracing collector in this profile.

Admission limits are 1,048,576 elements per array, 128 flattened cells per record,
64 recursive layout visits, and 65,536 total module storage cells per execution
context. The existing 128-cell frame limit includes four control cells, local
aggregate payloads/descriptors, ByRef pointers, borrow slots, scalar temporaries
and record copy/comparison snapshots. Dynamic payloads have separate 64 MiB
charged-storage and 4,096-live-block limits, including retained borrows. Excessive inputs
receive diagnostics rather than creating uncontrolled stack or memory demand.
The broader language retains its existing array and managed-memory semantics.

The original storage fixture retains bytes and spans as data. The subsequent
[scanner](SOURCE-SCANNING.md) and [module parser](MODULE-PARSING.md) now use these
arrays for actual retained source and syntax. Their separate gates establish
decoding and parsing; the original storage gate alone does not. Do traversal
and failed-condition continuation are defined by the source-scanning extension.

## Inspection and acceptance

SYMBOL inspection records retain their original 14 fields and append
TypeSymbol, ArrayRank, HasBounds, LowerBound, UpperBound, ElementCells,
StorageCells, FieldOffset, FirstField and NextField. BOUND records retain their
original eight fields and append TypeSymbol, ArrayRank, HasBounds, LowerBound,
UpperBound, ElementCells, StorageCells and AccessKind. These are development
records, not a stable serialization or public ABI.

`tests/aggregate-storage/check.ps1` checks source bytes and token/tree records,
nominal identity, field/index bindings, copy independence, aliases, actual
parameter bounds and failure preservation at O0/O2. Earlier scalar, integer,
parser and project-loading gates must continue passing on the same executable.
