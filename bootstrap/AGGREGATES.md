# Bounded source-buffer and record storage

This increment implements the next dependency identified in DEPENDENCIES.md.
It extends the existing project pipeline; it is not a separate compiler or a
claim that the complete self-hosting storage model is implemented. Exact test
evidence belongs in `../compiler/Progress.md`.

## Admitted source values

Field-only Type declarations define nominal finite records. Fields may be the
existing scalar types or finite nested records. Recursive records, managed
fields, array fields, opaque native representations and lifecycle hooks remain
unsupported. Fields start neutral. Assignment copies the complete record value
independently, and equality/inequality compare its scalar fields semantically.
Unrelated record declarations do not become compatible because their fields
have the same layout. Ordering is not defined for records.

One-dimensional arrays have compile-time-known bounds and scalar or admitted
record elements. Negative lower bounds are supported; an omitted lower bound
uses zero in this profile, which does not admit Option Base changes. Bounds and
index expressions use LongLong semantics. Runtime indexing checks the complete
range before computing an element address, reporting Err 9 on failure.
Known-invalid bounds and indexes receive compile-time diagnostics.

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

The initial copy boundary admits whole arrays only when both bounds are
statically known and equal. Same-element-type arrays with different bounds are
not different language types: their general assignment must adopt the source
bounds. This implementation reports E_UNSUPPORTED for that replacement and for
whole-array copies through parameters with unknown bounds. It never silently
retains different destination bounds. ByVal aggregates, aggregate results and
grouped aggregate ByRef temporaries remain unsupported until their value and
lifetime paths are implemented. Existing scalar ByVal/results/temporaries work
for individual array elements and record fields.

## Storage and failure boundaries

This profile uses fixed owned storage, with no runtime resizing or heap
allocation. Locals belong to their procedure frame and module storage to its
execution context. Aggregate ByRef borrows end with the call; no escaping
aggregate references or managed roots are admitted. Dynamic arrays, ReDim,
managed String and allocation-failure recovery are separate dependencies.

The private native representation flattens scalar record fields into i64 cells.
An array has two descriptor cells for its current lower/upper bounds followed
by its element cells. Field offsets, element strides and nominal identities are
bound metadata, not reconstructed from field spelling during emission. This
representation is not a foreign ABI or a public memory-layout guarantee.

Copies snapshot source cells before publishing destination cells, preserving
self-aliasing and evaluation order. Failure paths use the existing fresh FAIL
and sticky Err protocol; no incomplete assignment is published. Fixed storage
begins neutral before an initializer runs. Declared records and array elements
containing only scalar values require no tracing collector in this profile.

Admission limits are 4,096 elements per array, 128 flattened cells per record,
64 recursive layout visits, and 65,536 total module storage cells per execution
context. The existing 128-cell frame limit includes four control cells, local
aggregate payloads/descriptors, ByRef pointers, scalar temporaries and aggregate
copy/comparison snapshots. Excessive inputs
receive diagnostics rather than creating uncontrolled stack or memory demand.
The broader language retains its existing array and managed-memory semantics.

The source-buffer fixture retains UTF-8 bytes and source spans as data; it does
not implement Unicode decoding or a complete lexer. It traverses token/tree
arrays using existing labels, comparisons and GoTo. New loop forms and failure
continuations in compound headers are not inferred by this storage extension.

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
