# Storage capacity planning

Implementation: [StorageCapacity.bas](src/portable/StorageCapacity.bas).
The maintained native gate is `powershell -NoProfile -File
std-lib/tools/check-scalar-storage.ps1 -SelectionPath <selection.json>`;
it compiles the actual capacity and UTF-8 modules through both verified source-built
stages and writes reports beneath `bootstrap/out/scalar-storage/`. Coordinated
source-cohort acceptance remains necessary after a source change. This reusable
scalar policy supports semantic-checking arenas; callers choose resource budgets.

`TryGetStorageCapacity(ByVal Capacity As Long, ByVal Required As Long,
ByVal Maximum As Long, ByRef Prepared As Long) As Boolean`

Rejects any negative input or Required above Maximum, returning False while
preserving Prepared and Err. Otherwise True returns a sufficient geometric
capacity in Prepared. Already sufficient Capacity returns unchanged, including
when it exceeds Maximum: Maximum limits the logical requested count, not storage
already owned by the caller. Required0 therefore needs no new storage.

When growth is needed, empty capacity starts at8 clamped to Maximum. A positive
existing capacity doubles from its existing size; it is not rounded to8 or to a
power of two first. Each step doubles only when current capacity is at most
Maximum\2; otherwise it clamps to Maximum. All arithmetic remains within the
natural nonnegative Long domain through INT32_MAX, with at most31 growth steps.

The function allocates/copies nothing, registers no managed roots, retains no
reference or state, and preserves Err on success and failure. Different calls
have private scalar state and can run concurrently with independent outputs.
Prepared must denote caller-owned writable scalar storage; normal caller lifetime
and synchronization rules apply when it is a field/array element. This routine
does not allocate arrays, release excess capacity, publish results, choose caller
budgets or interpret a failed allocation. Those remain caller responsibilities.

The reviewed policy comes from active SyntaxTree.TrySyntaxCapacity and the
qualified ByteBuffer geometric reserve code. The parser's existing wrapper can
continue assigning Prepared=Capacity before delegating, preserving its current
failure-output behavior. Parser delegation is a separate caller change.
