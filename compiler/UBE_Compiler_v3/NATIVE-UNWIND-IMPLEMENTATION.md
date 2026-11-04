# Declared native function extents

This implements the object-side runtime-function range prerequisite of the
reviewed stack and object/image binding contracts. NativeUnwind reads the selected
AMD64 COFF runtime-function table supplied by the build owner. The owner identifies
the table through the bounded section-name reader and retains the same immutable
snapshot/layout/primary-symbol inventory. It walks records once; this routine
never searches the entire table per source procedure.

NativeFunctionExtent holds zero-based code/unwind section IDs, code file offset
and positive byte count, unwind header file offset, and code/unwind section-relative
offsets. It describes the range declared by one runtime-function record. The caller
must match it to the frozen retained definition and later validate instruction,
linked-image, unwind-code and stack behavior. A leaf without a record has no
invented extent or zero-cost claim; instruction analysis remains required there.

The finite selected object profile is a fully initialized read-only table of
12-byte records, with exactly three ordered ADDR32NB relocations per record at
its start/end/unwind fields. Each target must be a primary positive-section
EXTERNAL/STATIC symbol. Resolve its unsigned addend only after checking it against
the target section's initialized extent. Begin/end must reference the same readable
executable nonwritable code section and form a nonempty interval. The unwind target
must be read-only initialized data, DWORD aligned within its section, with at least
four initialized header bytes. Reading the full unwind header/operations is a
separate consumer. No function length is inferred from the next symbol or padding.

The operation owns fixed scalar workspace only, allocates/copies no payload, and
publishes its scalar result only after all checks pass. Every binary/relocation/
primary-index/section read uses the existing shared inspection budget and
cancellation token; all incoming owners and Err remain unchanged. Malformed records
fail 1506, resource/cancellation use 1502/token7 and 1507, and invalid internal owner
or record-index arguments fail 1509. Numeric caps and declaration/body/argument
work bounds do not change. Unsorted, extra, missing or overlapping table relocations
fail this selected profile rather than being silently ignored.

References: [Microsoft x64 runtime-function records](https://learn.microsoft.com/en-us/cpp/build/exception-handling-x64)
and [COFF relocations](https://learn.microsoft.com/en-us/windows/win32/debug/pe-format#coff-relocations-object-only).
Actual selected Clang output must pass the independent LLVM oracle; these format
references alone are not implementation evidence. Complete image-side binding,
leaf ranges, instruction/fixup comparison, reserve derivation and publication remain
acceptance work.

## Linked image range reader

The image reader obtains its table from PE32+ exception data-directory entry 3,
not a section-name guess. NativeImageFunctionTable owns FileFirst, Count,
snapshot Length and Status scalars. Absent/zero directories publish a neutral empty table;
a nonzero address with zero size, misalignment or partial record is malformed.
A table must be wholly within one initialized read-only data section.

TryReadNativeImageFunctionExtent consumes that table and validates the selected
record's positive code interval and DWORD-aligned four-byte unwind header. It
uses the same NativeFunctionExtent result as the object reader. Each nonfirst
record also checks its predecessor's positive interval and nonoverlap/order.
The owner traverses every record before using the table as a sorted search index.
An indexed read alone does not certify records it has not read.

Image RVA resolution scans the at-most-96 section descriptors admitted by the
existing PE layout once per requested span, charging every descriptor byte/event.
It rejects any intersecting section that does not wholly contain the span,
multiple matches and spans crossing the initialized virtual extent. This fixed
host-format bound avoids an additional allocated index; no scan of all function
records is performed per function. All loops use existing inspection/cancellation
admission. Operations retain fixed scalar workspace and publish only on success;
input owners, Err, allocation/copy and failure contracts remain as above. This
adds no production numeric cap or declaration/body/argument traversal change.
The image reader still does not prove unwind operations, leaf ranges, code/fixup
identity or correspondence to a frozen retained object definition.

## Retained definition range binding

TryPrepareNativeImageFunctionTable performs the existing directory read and one
complete record-validation walk before publishing Status=1. The scalar descriptor
from TryReadNativeImageFunctionTable has Status=0 and cannot serve as a search
index. Empty prepared tables are valid and contain no function. The caller retains
the same immutable image snapshot/layout throughout preparation and lookup.

TryBindNativeFunctionExtent consumes a successful required/present function
binding from TryBindNativeDefinition, its matching declared object extent, and
the prepared image table. Both retained ranges must be initialized one-byte
function anchors. The object section, section offset and file start must match
that frozen binding. Binary search then finds the exact retained image RVA,
validates the selected image extent and requires matching section/offset/file
anchor plus identical positive code length. A missing, shifted, resized or
mismatched range fails 1506; invalid internal inputs or an unprepared table fail
1509. It never synthesizes an extent for a function lacking a runtime record.

Preparation walks each image record once. Each subsequent bind uses logarithmic
four-byte start-address reads plus the existing selected-record validator; there
is no full function-table scan per declaration. Preparation and binding allocate
or copy no payload, charge every byte/event under the shared inspection owner,
check cancellation at those admissions and preserve prior results on failure.
No new production caps or declaration/body/argument work bounds are required.
The production owner must associate object extents with frozen definitions without
repeated full-table searches; the bounded fixture transport is not that owner.

This establishes declared extent correspondence only. Leaf boundaries, complete
unwind records, instruction bytes/relocation fixups and full stack/debug safety
remain separate acceptance obligations.
