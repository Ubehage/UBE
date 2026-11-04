# Generated storage ownership and residency

This bounded dependency of First checked native executable closes cross-owner
aliasing and storage residency over the frozen generated definitions. It does
not establish arbitrary CRT object sizes, runtime writes, register provenance,
control/dataflow, stack safety or builder/publication integration.

## Inputs and lifetime

`TryValidateNativeStorageOwnership(Bytes, Layout, Expected, Retained, Order,
Protected, Inspection, Cancellation, Failure)` borrows one immutable PE image,
its admitted layout, the complete frozen `NativeExpectedDefinitions`, and one
aligned `NativeRetainedDefinition` per expected row, previously associated by
the existing producer/object/image binders. The caller retains all owners for
the call. The expected table is the complete pre-tool table, not a table inferred
from candidate symbols. Its status, capacities, names and row shapes are checked;
this consumer does not repeat name lookup or producer binding.

`Order() As Long` contains every present generated storage row exactly once in
RVA order. Families 2/9/10/11/12/16/17/22 own positive storage; functions and
optional absent rows do not. Exact count plus positive, disjoint intervals proves
coverage and excludes duplicate indices without an allocation or bitmap. Caller
ordering uses existing budgeted UBECore ordering when integrated into the builder.

`Protected() As LongLong` holds alternating RVA and positive byte count pairs,
sorted by nondecreasing RVA. These are the complete independently bounded
non-generated storage views already established by the relevant validators:
reference-pointer cells, import descriptors/names/lookup/address spans, exception
and relocation metadata. Completeness and provenance are caller preconditions,
as for existing pointer-association consumers; a subset cannot establish complete
closure. Overlapping/duplicate protected views are legitimate and permitted.
They never include generated pointer fields inside their owning initializer
table, or the TLS template container. CRT labels and empty markers do not imply
positive ownership; next-symbol distances must not be used to invent extents.

TLS directory, template, index and callbacks are independently read and validated
once inside this consumer using `TryReadNativeThreadStorage`; their exclusion
does not depend on the supplied protected list. Families 12/22 must pass existing
TLS member validation, including containment and neutral initialization. They
must remain disjoint from each other. Ordinary generated storage cannot overlap
the template. Every generated owner excludes the other three TLS spans and all
protected views. A reference-pointer cell targets an owner but occupies separate
storage; aliases naming that same cell are not separate generated owners.

## Geometry and residence

Every present storage range must have exactly its frozen size and match its
section's characteristics, section-relative offset, RVA, preferred-base address,
initialized prefix and file offset. Full logical storage lies in the image and
one section. Mutable storage may be fully initialized, partially initialized or
entirely zero-filled; an empty initialized prefix requires FileFirst=-1.
Immutable storage remains fully initialized. Existing permission rules apply,
and all generated storage must exclude IMAGE_SCN_MEM_DISCARDABLE.

The existing contribution-isolation loop is shared with a storage form that
compares the full virtual extent but only its initialized file prefix. It rejects
cross-section virtual/file aliases and symbol/string-table overlap. Existing
fully initialized contribution callers keep their admitted shape and costs.
Within a section exact affine geometry makes file mapping injective; across
sections isolation establishes it, so no second file-order owner is necessary.

## Resources, failure and concurrency

No allocation, array copying, output owner, new cap or sorting implementation.
Only fixed scalar/record workspace is used. All input arrays and caller Err stay
unchanged; only the existing inspection ledger and failure descriptor mutate.
The consumer is reentrant with independent ledgers and immutable shared inputs.
Failure is controlled: invalid borrowed shape uses the existing reset failure,
candidate ownership/residency mismatches use UBE1506, and existing cancellation,
resource and root failures propagate. No partial success is published.

Count one zero-byte inspection event per frozen row, protected pair, ordered
owner and protected sweep comparison, in addition to existing section/TLS
readers and shared isolation costs. Protected validation is O(P); the ordered
sweep is O(G+P), including overlapping views. Geometry/isolation costs O(G*S),
where the admitted section count S is at most 96. Each loop is ledger-bounded
and cancellable through existing inspection visits.

The literal four-section fixture has ten frozen rows and eight storage owners.
Its independent cost oracle is 3996 bytes / 934 events: TLS metadata costs
1924/487, eight geometry/isolation checks cost 1280/328, the two neutral TLS
members cost 792/101, and the frozen-row/owner scans add 18 zero-byte events.
Protected views are empty in that cost fixture; separate cases cover their
ordered sweep, overlapping views and forbidden intersections.

## Independent acceptance cases, fixed before implementation

Positive: initialized, partially initialized and entirely zero-filled mutable
storage; immutable initialized storage; adjacency; arbitrary frozen-row order;
optional absent definitions; function rows outside storage order; legitimate TLS
member/template containment; overlapping protected views away from generated
owners; empty symbol markers and multiple labels of a single qualified owner.

Negative: discardable storage; equal/partly intersecting generated spans;
duplicate, missing, reversed, absent, function and out-of-range order entries;
wrong array lengths/table shape; forged section/file/RVA/address/initialized
geometry; full or zero-tail cross-section RVA alias; file-only section alias;
ordinary global in TLS template; overlapping TLS members; protected overlap;
unsorted, odd, empty or overflowing protected pairs; overflowing range endpoints.

Qualify exact byte/event limits, cancellation boundaries, unchanged inputs/Err,
no allocation/copy, root exhaustion and forced-Boolean controls. Retained
qualification covers both readers and all sixteen images with independent
producer-bound ownership/protected expectations. Rerun affected component,
extent, fixup/target, code/instruction and image-relocation gates; record exact
commands and source/artifact identities. Passing this dependency does not finish
the native executable deliverable.
