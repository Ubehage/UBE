# Initialization-warning implementation contract

This implements the already selected dependency/SCC/witness behavior in
`NATIVE-BUILD-DIAGNOSTICS.md`. It is an internal compiler consumer of UBECore's
bounded directed-component operation, not a new public phase or source graph.
Source discovery and ByRef propagation will supply the dependencies. This
component does not invent dependencies or enforce runtime initialization.

For M canonical source modules, retain a row-major Long matrix of M*M cells.
Zero means no dependency; a positive value is its witness SourceId+1. A parallel
eight-byte span array retains FirstByte/LastByte. Duplicate dependencies select
the lexicographically earliest source/start/end span. End-byte comparison only
breaks an identical source/start tie and preserves a deterministic original span.
Each edge is supplied with valid zero-based source and byte identities; the
source extractor remains responsible for checking spans against original owners.

An M-element Long array records the library's component label for each module.
An M-element warning array first holds private candidates indexed by component.
Each twenty-byte record has Code, SourceId, FirstByte, LastByte and SmallestModule.
Code 0 means unused and -1 means members without a qualifying edge; neither is
published. After one label pass, inspect the dependency matrix exactly once to
choose each component's earliest internal-edge witness. A singleton is selected
only by its self-edge. A downstream module is excluded. Compact selected records
in place and order them by source/start, breaking ties by smallest module.
The bounded in-place ordering uses O(M*M) comparisons and no additional payload.
Published records have Code 1514 and retain their full source spans. Formatting,
warning severity transport to the IDE and stderr delivery remain later consumers.

The compiler-owned payload is 12*M*M + 24*M bytes. Component traversal adds
20*M bytes while its workspace is owned. Reserve each exact allocation before
calling the allocator; retain separate capacity shadows for partial failure and
release only when ownership ends. No array value is copied or returned ByVal.
All mutable state is private to one build. Canonical source owners remain
immutable and retained by the caller. There are no external resources here.

Charge each supplied dependency, each component transition attempt, each label
read, each witness-matrix cell, each compaction candidate and each ordering
candidate/comparison to the shared work limit. The library supplies chunks of
at most 4096 actual transitions; derive each chunk's work/pending allowances
from the remaining shared budget and reconcile returned actual work/live/peak
counts even on failure. Check cancellation before and after chunks and allocation,
and at the existing counted-work boundaries during scalar loops. Graph stack
entries consume pending-work; they are not source-body structural nesting.

No complete matrix scan is repeated per component. Work after dependency
collection is O(M*M); storage is O(M*M+M), with checked arithmetic and array-index
admission. Resource rejection is UBE1502 with its actual category; cancellation
is UBE1507; invalid internal inputs are UBE1509. Managed admission and allocator
failure remain controlled. A failed graph is only disposable, and partial
warnings are never published. Reading is allowed only after successful finish.

Qualification must independently check directed cycles, self cycles, multiple
components, downstream exclusions, deduplicated witness choice, tied warning
locations, reversed edge arrival, real resource boundaries and exact cleanup.
Use actual library pending peaks, work events and allocation/copy observations;
reject changed expected witnesses and omitted charges. Successful component
tests alone do not qualify source/ByRef discovery, emitted CLI/IDE warnings,
runtime initialization or the complete native executable.

## Checked-source extraction

NativeDependencies consumes immutable SemanticResult, its retained catalog
and per-module checked nodes/facts. It must not re-resolve names, reparse source
or build another public graph. Only complete warning records are publishable;
all extraction owners are build-private and failure-disposable. Runtime
initialization and warning presentation remain separate required consumers.

NativeDeclarationPlan assigns dense ordinary FrameIndex and ByRefIndex values
in its existing ordered declaration pass. The ByRefIndex field uses the spare
Long before the target's two LongLong identities; ByRefCount uses the owner's
trailing padding. Target and owner sizes stay 72 and 24 bytes. All ByRef formals
have indexes, including applicable intrinsic formals; other declarations have
-1. No extra declaration scan, target identity or payload allocation is needed.
Both indexes reset during disposal. This supports scratch proportional to
procedure bodies and ByRef formals without a second declaration-sized array.

Index ordinary procedure roots from the checked module roots' immediate child
lists. The current checker flattens module declaration groups, retains ordinary
procedures as kind 101 and omits intrinsic bodies. For each module root M, clear
only compact procedure/formal scratch. Traverse its executable declaration
initializers, then use an explicit procedure queue to traverse each reachable
ordinary body once. The existing NativeTraversal cursor provides bounded body
events. Do not walk unrelated procedure subtrees while indexing roots.

Cross-module storage targets are resolved directly from kind 3 reads and kind
104 assignments; module declarations are kind 2 with module scope. An assignment
node retains the whole statement's syntax identity, so take the first syntax
child's full span for its destination access. Calls are kind 6; their Auxiliary
is the checked call-fact identity. Its contiguous parameter maps are already
resolved. Read original syntax through retained source owners and validate span
bounds. No diagnostic span may come from a fabricated or copied source text.

For exact ByRef association, a call-local Long workspace can map written
ordinal to parameter-map identity. Populate it from the contiguous maps, then
walk nonempty written positions alongside the actual child chain. An explicit
omitted argument consumes a written ordinal but has no written expression child;
its pure default child follows all written expressions and retains the declaration
source identity. Accept that cross-source literal without changing its origin;
other checked node kinds retain their enclosing module identity. Do not index
children directly by WrittenOrdinal. Named arguments retain written order,
while parameter maps retain formal order. ByVal/forced/default arguments must
not seed or forward aliases. Reuse this scratch between calls; no syntax-sized
index or scan through unrelated semantic facts is necessary.

For each root, retain false/true facts and outgoing forwarding heads indexed by
ByRefIndex. Direct root-global actuals seed their target formal. Exact ByRef
formal actuals add a forwarding edge. Record the original call source/span and
target module on each edge. Enqueue only newly true formals, but add the foreign
M -> M dependency for every qualifying seed or propagated edge, including an
edge whose target is already true. This preserves the earliest qualifying
witness independently of discovery order. Complete call discovery before
propagation, so later-discovered outgoing edges of an already seeded formal
cannot be missed. Clear/reuse edge capacity and queues between roots.

Procedure roots/seen/queue storage is O(V); formal facts/heads/queue storage is
O(P); forwarding edges are O(F); call scratch is O(V). Together with the retained
matrix, this respects the reviewed O(V+C+P+F+M*M) storage bound. Charge real
root/member resets, child and map visits, queue events and forwarding edges.
Each procedure/formal is enqueued at most once per root, and each forwarding
edge is propagated once, retaining O(M*(V+C+P+F)) discovery work. Queue pushes
reserve actual pending entries alongside the cursor; pops release them.
Capacity growth reserves old-plus-new payload before allocation and retains
partial capacities for exact disposal. No warning is silently omitted when a
work, pending, structural-depth or payload limit fails.

The implementation and focused source qualification are recorded separately in
NATIVE-WARNING-EVIDENCE.md. Required checks include checked multi-module
initializers, uncalled helpers, foreign-helper self cycles, named/omitted
arguments, recursive forwarding, already-true witness replacement and local,
ByVal, forced/default controls, plus actual shared-budget failure/cleanup.

TryDiscoverNativeWarnings borrows a successfully checked SemanticResult, its
ready NativeDeclarationPlan and a newly begun NativeWarningGraph of the same
module count. NativeLLVMWriter supplies only the existing limits, usage,
cancellation and failure fields; discovery emits no LLVM or target identities.
The caller retains those owners throughout the operation and original source
owners through later warning presentation. Discovery does not monitor source
files, acquire locks or perform I/O. Failure must be followed by disposal of
the private dependency and warning owners, never publication of their prefix.
Successful discovery leaves the warning graph collecting; its existing finish
operation selects complete component warnings. Dependency status is 0 unused,
2 complete or 4 failed. Reusing a nonempty dependency owner is rejected.

NativeDependencies is 112 bytes on the selected target. Procedure and formal
rows are 12 bytes each; their queue cells share rows with independent root/seen
and seen/edge-head fields. Their exact capacities are the dense frame/formal
counts. Forwarding edges are 24 bytes and argument-map cells are 4 bytes, with
separate geometric capacity shadows. The embedded NativeTraversal retains its
own 24-byte frame capacity. Each successfully acquired owner stays charged
through partial failure; TryDisposeNativeDependencies releases capacities and
outstanding queue entries without observing cancellation. No managed array or
checked-source owner is copied ByVal. Independent builds share only immutable
checked/source owners and keep all scratch, work queues and failure state private.
