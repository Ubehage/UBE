# Native definition ranges and immutable integer data

This consumes the bounded symbol inventory for the existing object/image and
frame-metadata binding obligations. Expected names, lengths and values come from
the build owner's frozen lowering/analysis records, never from the candidate.
It adds no new stage, production inspector, host primitive or worker pool.

NativeDefinitionRange is a scalar result: raw symbol index, zero-based section,
file offset (-1 for an entirely zero-filled range), requested byte count,
initialized byte count, COFF type, section-relative offset, image RVA/address
(zero for a relocatable object), and section characteristics. A caller-specified
positive extent must fit the section's logical storage: object RawBytes or image
VirtualBytes. Only the initialized prefix can be read from the file; PE raw
alignment padding never satisfies a request. RVA, image extent and absolute
address arithmetic are checked before addition. The result is published only
when the complete location is valid. This establishes a requested span, not a
function's inferred length or uniqueness of all image section mappings.

TryValidateNativeIntegerData locates one positive-section EXTERNAL/STATIC name
through the shared inventory. It requires a nonempty expected LongLong array,
COFF type zero, initialized readable data without execution/write permission,
and a fully initialized extent of exactly eight bytes per expected entry. It
rejects every non-ABSOLUTE relocation overlapping that extent, because these
immutable integer values must survive linking without fixups. Disjoint relocations
remain the full candidate validator's responsibility. It reads each little-endian
64-bit pattern and compares it to the borrowed expected entry, preserving the
old output range on any mismatch. This is used for frame/reserve metadata; its
caller must separately derive and qualify the expected complete footprints.

All snapshots, layouts, inventories, query bytes and expected arrays are immutable
and retained by the caller. The supplied inventory and layout describe the same
snapshot; arbitrary external mutation is unsupported. Calls own only fixed
scalar workspace, allocate no arrays and copy no payload. Each call has private
outputs and shares the caller's NativeInspection budget and cancellation token.
Every scalar read, Core name lookup and relocation visit is charged through the
existing bounded readers; all failures preserve the old output. Malformed or
missing data uses 1506, inspection exhaustion 1502/token7, cancellation 1507 and
invalid caller/internal state 1509. No numeric cap changes.

This does not infer expected compiler identities by a name prefix, derive code
extents, apply relocations, prove complete retention or compare instruction
bytes. Those consumers remain required, along with auxiliary semantics, overlap
validation, held-file identity, stack/debug analysis and publication integration.

## Object-to-image definition retention

TryBindNativeDefinition consumes one frozen NativeExpectedDefinition and its
name arena, the matching output unit's checked object inventory/snapshot/layout,
and the checked image inventory/snapshot/layout. The caller walks frozen rows
once and selects their output owners; this operation does not scan the whole
expectation table per module or infer ownership from a prefix. All inputs remain
immutable and retained. It uses only fixed scalar workspace, no allocations or
payload copies, and the shared inspection byte/event/cancellation budget.

NativeRetainedDefinition contains a Long Present flag followed by the object
and image NativeDefinitionRange records. Optional absence before object emission
publishes Present=0 with neutral ranges. Required absence fails. Every present
object definition must have exactly one positive-section EXTERNAL/STATIC match
in the image; missing/ambiguous definitions fail. A matching undefined symbol
is not a definition. The inventory's optional unique-selection helper preserves
the existing required-lookup behavior without duplicating lookup algorithms.

Data spans use the frozen positive StorageBytes. Procedure spans initially cover
one initialized byte at their definition anchor, explicitly not an inferred code
extent. Both sides must have the selected COFF function/data type and appropriate
read/execute/write section permissions: code is readable executable code without
write; mutable globals/states/latch/stack floor/error TLS are readable writable
data; initializer/frame/reserve tables are fully initialized read-only data.
Storage spans fit object logical bytes and image virtual bytes under the existing
range resolver; file padding cannot satisfy them. This establishes symbol/anchor
and storage-span retention. Complete code extents, data contents and relocated
instruction comparisons remain separate required consumers, not inferred from
this result. Neither final symbols alone nor a name prefix establish retention.

Result publication is atomic, including optional absence. Missing, duplicate,
wrong-kind or unusable candidate ranges fail with 1506; budget/cancellation use
1502/token7 and 1507; invalid expected-row or owner state uses 1509. No numeric
cap or declaration/body/argument work bound changes. Failed calls retain the
previous result, and do not change Err or incoming snapshots.

## Contribution isolation

TryValidateNativeContributionIsolation checks a fully initialized contribution
range against its immutable object's/image's other sections and metadata. It
rejects initialized file aliases, image virtual aliases, and overlap with the
symbol/string table; object relocation tables also cannot alias the contribution.
The caller already decoded and associated the selected section. Scalar workspace,
one zero-byte admission and at most one walk of the section table use the shared
inspection budget; no allocation/copy or retained ownership is added. Invalid
caller ranges use 1509, overlaps use 1506 and existing read/budget/cancel failures
pass through. Constant binding and code comparison share this check.
