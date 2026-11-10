# Growing scalar and finite-record arrays

This increment extends the existing rank-one array pipeline. It admits dynamic
declarations (`Dim Values() As Byte`, for example), Array.TryResize,
Array.TryCopy and independent ordinary whole-array assignment. Elements may be
the admitted scalars or finite records containing only those scalars. Existing
field/index, Byte copy and ByRef paths use the same representation.

## Values and shape

Dynamic owners begin empty; Length returns zero and indexing fails with Err 9.
TryResize takes a zero-based element count, preserves the complete coordinate
intersection when requested, and neutralizes new elements. Preserve False
neutralizes every element. Count zero produces an empty value. A fixed-bound
declaration can also receive a replacement; its written bounds are not part of
the array's type. TryCopy and assignment copy the source bounds and independent
element values. Nominal record identity and element type/rank must match.

Symbol metadata retains declaration bounds; node bounds are usable for static
index diagnostics only while proven stable. A conservative project effect fact
invalidates current-bound facts when resize/copy roles or whole-array replacement
are present. Runtime indexing always checks the descriptor. This may reject
additional array accesses in If headers under the existing unresolved compound-
header failure boundary; no stale initial bounds are used to omit a check.

TryResize and TryCopy have the exact existing attributed intrinsic signatures.
They return usable Boolean status, not language FAIL. Invalid negative resize
count returns False with Err 5. Requests beyond admitted storage or a failed
allocation retry return False with Err 7. Success preserves incoming Err.
Ordinary array assignment converts a failed replacement into language FAIL and
does not commit. Replacement is fully prepared before publishing any destination
descriptor changes, including self-copy while an old element alias is live.

## Owner-approved alias lifetime

On 2026-11-10 the owner selected retention of the original element storage.
A prepared element/field alias remains attached to that storage if later
arguments or the callee replace its array. Its writes do not modify the new
array. Whole-array ByRef parameters refer to the stable variable descriptor and
observe replacements. Prepared indexed assignment destinations similarly retain
their selected storage until commit or abandonment after RHS evaluation.

Borrow retention starts when the address is prepared, not at callee entry. It
ends on successful call completion or abandonment, including later-argument
failure. Assignment borrows end after commit/abandonment. Local array owners are
released on normal returns, Err.Raise, other FAIL returns and redeclaration.
Module owners belong to the execution context and are released by context
disposal. This bookkeeping handles compiler-owned memory; it does not perform
user-owned resource cleanup or admit escaping references.

## Private representation and target support

Every array descriptor has four cells: lower bound, upper bound, payload
pointer and owning-block pointer. Initial fixed payloads remain inline after
the descriptor; dynamic payloads belong to separately allocated blocks. Empty
descriptors have bounds 0 through -1 and null payload/owner pointers. Borrowed
array parameters point at the caller's descriptor rather than copying it.

Owned blocks retain a context-list link, exact owner/borrow count and charged
size. Only blocks with no owner or borrow are reclaimable. These scalar/finite-
record payloads contain no managed references or cycles; leaf reclamation is
not evidence for the full tracing collector, roots, barriers or finalizers.
Allocation failure requests eligible-leaf reclamation and retries once. Failed
replacement retains the old descriptor and payload; successful retry preserves
the previous Err record.

The Windows target uses VirtualAlloc/VirtualFree through a narrow target wrapper.
The installed LLVM llvm-dlltool builds a small KERNEL32 import archive offline;
no Windows SDK import library, CRT, download or new third-party package is
required. The backend bounds both import-tool and Clang execution and publishes
only after successful linking and x64 validation. Target details follow
[VirtualAlloc](https://learn.microsoft.com/en-us/windows/win32/api/memoryapi/nf-memoryapi-virtualalloc)
and [VirtualFree](https://learn.microsoft.com/en-us/windows/win32/api/memoryapi/nf-memoryapi-virtualfree).

Admission limits are 4,096 elements per array, 128 cells per finite-record
element, 64 MiB of live charged allocation storage rounded to 4,096-byte pages,
and 4,096 live blocks, including blocks retained solely by borrows. Existing
source, symbol, context and frame limits still apply; prepared borrow slots
count toward the bounded frame. Exact acceptance evidence belongs in Progress.md.

## Explicit later work

ReDim/Erase source syntax, array fields, arrays of managed values, recursive
records, aggregate ByVal/results, multidimensional arrays, full collection,
foreign array layouts and target concurrency are not admitted by this step.
The owner directs minor unspecified behavior to follow VB6 unless that conflicts
with already defined UBE behavior or architecture. Explicit UBE copy, FAIL and
alias rules above take precedence.
