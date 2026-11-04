# Code contribution ownership

Implementation contract for the next part of the existing native validation
work. This document does not claim implemented or qualified ownership checks.
It builds on NATIVE-CODE-IMPLEMENTATION.md and the immutable expected-definition
inventory. No language, architecture, numeric cap or resource-bound change is
introduced.

## Per-output ownership

The build owner selects code anchors from frozen expected rows for each output
unit. It binds every retained anchor through TryBindNativeDefinition, and calls
TryValidateNativeCodeContribution once per nonempty executable object section.
A private section-indexed array records those complete contribution results.
The array has exactly the object's qualified section count (at most 96); its
owner charges the existing payload ledgers and retains it until consumed.

Move the current test driver's anchor consistency and coverage checks into
production consumers. Every subsequent anchor in a section must agree with the
same image placement: section identity, object offset, file offset, image
section offset, RVA and VA. Check ranges before additions, and require matching
code characteristics and one-byte function-anchor shapes. An anchor outside the
complete contribution or a second inconsistent placement rejects with 1506.
A section walk must require one present map entry for each nonempty executable
section, and no present entry for empty or non-executable sections. The existing
whole-contribution validator remains responsible for admitted flags, isolation,
relocations and content equality. Neither a symbol name alone nor a candidate
image address can supply expected ownership.

## Complete image ownership

Collect the per-output contributions with their frozen UnitKind and SourceId.
The identity key is (UnitKind, SourceId, object SectionIndex). UnitKind is 0..6;
kind 0 uses a valid source identity, and support kinds use SourceId=-1. All
records must belong to the same immutable image owner. Do not merge distinct
owners merely because their bytes or scalar ranges happen to agree.

Use the existing UBECore budgeted byte-key order to check owner-key uniqueness,
image file-range nonoverlap, and image RVA-range nonoverlap. This avoids pairwise
scans. Reject duplicate owners, including identical duplicate records, and
reject any positive-length overlap; adjacent half-open intervals are valid.
Keep the resulting RVA order for later code-owner lookup by branch/call targets.
The caller retains immutable contribution records for the index lifetime.

The concrete input record is NativeOwnedCode: UnitKind and SourceId as Long,
followed by NativeRetainedDefinition (128 bytes under the existing record ABI).
NativeCodeIndex owns Keys() As ByteKey, Bytes() As Byte and Order() As Long,
followed by six Long fields: KeyCapacity, ByteCapacity, OrderCapacity, Count,
SourceCount and Status (48 bytes). The build owner retains and charges the
borrowed input records; the index does not copy them.

For C input contributions, allocate C keys (16C bytes) and C key bytes. Before
each sort, release any preceding order, then reserve 8C bytes for the existing
Core result and temporary orders. On success retain 4C and release the temporary
4C reservation; on failure release the full sort reservation under Core's
unchanged-output contract. Peak index workspace is therefore 25C bytes. After
the third order and overlap check, release Keys and Bytes; ready state owns only
4C bytes of RVA order. Empty input is a valid empty index, but cannot establish
required-code coverage. Ready publication is all-or-nothing; partial state must
be explicitly disposed using the existing fresh/partial/ready lifecycle.

Reuse the same workspace for these orders:

- Owner identity: Partition is SourceId for kind 0, otherwise
  SourceCount + UnitKind - 1; a one-byte key contains object SectionIndex.
  Require SourceCount in 0..2147483641 before forming partitions.
- Image file position: Partition is ImageRange.FileFirst, with an empty key.
- Image RVA: Partition is RVA divided by 2; a one-byte key contains RVA modulo
  2. This orders the admitted unsigned 32-bit RVA domain without narrowing it
  to signed Long or allocating a separate encoding buffer.

Each key's Value is the original input index. Validate scalar range shapes and
bounds before construction, and check sorted adjacent intervals with widened
arithmetic. Key construction, record validation and adjacency checks each admit
an event per visited record; Core sorting uses the same byte/event ledger.
Every allocation uses the existing shared inspection-storage/global-usage
ledger, and every partially owned buffer remains accounted until disposal.
Invalid caller shape uses 1509; duplicate ownership and image aliasing use 1506;
resource refusal uses 1502/resource 7 and cancellation uses 1507. Err and borrowed
records remain unchanged. Do not substitute an uncharged dictionary, repeated
scan of all expected declarations per unit, or a new generic sorting algorithm.

## Independent acceptance

Synthetic cases must cover arbitrary input order, exact duplicate identities,
different owners with overlapping file or RVA spans, adjacency, empty and single
inputs, safe numeric endpoints, invalid caller state, exact/insufficient budgets,
each allocation refusal and cancellation admission, immutable input, Err
preservation, partial cleanup and root pressure. Per-output tests must cover
missing and spurious coverage and inconsistent later anchors.

The retained matrix has 16 images and 112 code contributions. Its existing
placement diagnostic reports no contribution overlap, while the maintained
byte-comparison gate already compares every original code byte. Refresh the
actual gate to exercise the production ownership consumers and reject mutated
owners, placements and missing coverage; C-only assertions are not production
qualification.

A further diagnostic in bootstrap/out/native-branch-boundary-diagnostic.json
checks 5,224 unrelocated jumps against instruction starts and COFF function
fences, with no mismatches. Sixteen relocated tail jumps target ube.f35 or
ube.program.run; bootstrap/out/native-relocated-branch-diagnostic.json records
them. These diagnostics guide the next control-flow tests. They do not establish
function extents, reachability, effective targets, termination-call closure,
stack safety, build integration or final native-executable acceptance.

## Implemented API shape

TryValidateNativeCodeAnchor borrows one present one-byte retained anchor and a
whole contribution, and admits one zero-byte event after caller-shape checks.
It owns no payload and compares all placement coordinates and characteristics.
TryValidateNativeCodeCoverage borrows object bytes, their qualified object layout
and a section-indexed NativeRetainedDefinition array of exactly SectionCount
entries. It admits an initial zero-byte event and reads each section through
the existing reader. Missing/spurious entries or mismatched section placement
use 1506; malformed present contribution shapes use 1509. Neither helper mutates
its inputs or owns storage.

ValidNativeCodeContribution validates the scalar record shape shared by those
consumers and the index: present full initialized code ranges, section indices
0..95, SymbolIndex=-1, positive equal counts, bounded file ends, zero object
section offset/RVA/VA, bounded image offset/RVA/VA and admitted resident code
flags. It does not replace content or section-isolation qualification. The index
also requires a consistent image base (VA minus RVA) across borrowed records;
association with the same immutable image remains the build owner's obligation.

TryPrepareNativeCodeIndex accepts State, borrowed NativeOwnedCode array,
SourceCount, Inspection, Storage, Limits, Usage, Cancellation and Failure.
TryDisposeNativeCodeIndex accepts State, Storage, Usage and Failure. The sort
bridge reuses ReadNativeKeyBudget and FinishNativeKeyBudget from inventories.
Core copies each final order once, so successful construction copies 12C bytes
of index positions across three sorts; contribution records are never copied
into retained payload. Qualification is pending until its evidence is recorded.
