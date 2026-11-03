# Native lowering resource contract

This selects initial engineering limits and a bounded implementation approach
for the existing First checked native executable item. It is not evidence of
an implemented emitter, measured performance or a whole-process memory limit.
Independent acceptance obligations are in `tests/native-executable/RESOURCE-ORACLES.md`.

## Limits and units

The build caller supplies nonnegative limits through internal configuration;
tests can lower each independently. No new public CLI or language limit is
introduced. Check arithmetic and reserve before an operation crosses a limit;
report UBE1502 and preserve the old output. Actual allocation failure remains
a controlled failure even below the configured limit.
The cumulative work-event limit reports category `lowering-work`; the live
pending-entry limit reports `pending-work`. Do not confuse the two quantities.
The separate `NATIVE-DEBUG-CONTRACT.md` bounds candidate debug inspection and
uses `debug-information` for its resource failures; its live owned payload
also counts against the total lowering payload ceiling while owners overlap.

| Quantity | Initial default | Accounting |
| --- | ---: | --- |
| Generated LLVM | 268435456 bytes (256 MiB) | Cumulative logical UTF-8 bytes across all modules, including support and debug metadata |
| Lowering payload capacity | 1073741824 bytes (1 GiB) | Simultaneously owned buffer/array payload capacities, including maps, warning analysis, traversal stacks, snapshots and resize overlap |
| Pending traversal | 1048576 entries | Simultaneously live explicit traversal entries across lowering and warning analysis |
| Structural traversal depth | 256 | Active body nesting, unrelated to the generated program's runtime recursion |
| Generated identities | 4194304 records | Cumulative unique target functions/globals, block labels, SSA values and metadata nodes |
| Analysis/lowering work | 268435456 events | Actual node enter/exit, edge, declaration and argument-map visits, including repeated warning-analysis root passes |
| Accepted executable length | 268435456 bytes (256 MiB) | Logical file length after candidate writers stop, before validation/publication |

The source defaults admit up to 64 MiB and 1048576 syntax nodes with depth 256.
The separate output cap allows four times that source-byte ceiling, without
claiming every source expands within that ratio. Pending/depth defaults reuse
familiar frontend scales as independent limits. Identity/work caps bound target
expansion and repeated graph work. The payload cap allows a largest admitted
module buffer and its two snapshot arrays to coexist with bounded maps. These
are explicit engineering choices, not measured peaks or a promise that every
frontend-admitted project fits. Measure representative projects and boundaries
before qualifying the implementation.

Payload accounting excludes retained frontend/checked owners, allocator
headers, unreachable storage awaiting collection, thread stacks, pipe/kernel
buffers and external tools. Report these separately when measuring process
usage. Release a payload charge when ownership ends, without claiming physical
memory has already been returned. Never reset charges while owners overlap or
double-charge a transfer. No whole-process RAM or hard temporary-disk quota is
selected. The executable limit is post-write admission only; external writers
may consume more disk first. Handle disk-full normally. Tool diagnostic
retention remains 4096 raw bytes per stream with separate rendered-buffer
accounting in the main contract.

## Traversal and emission

Start lowering serially in canonical manifest order. Jobs 1/2/4 still select
the existing frontend/checker worker budget; they do not require concurrent
lowering or create a second pool. This is a scheduling choice inside the
existing architecture, not a public phase or IR. Later parallel lowering must
preserve the no-false-budget-rejection rule and qualify simultaneous scratch
accounting and cost bounds.

Borrow the checked graph and original spans and retain their owners. Use
bounded indexed scalar maps and explicit traversal stacks, never source-driven
native recursion. Use one declaration/identity preparation scan and at most two
ordered body traversals: planning stable target identities, then emission.
Do not add another parser or duplicate semantic graph.

For body node occurrences V and followed child edges E, the two traversals
allow at most 4*V enter/exit events and 2*E followed-edge events. Count actual
occurrences, including repeated edges, rather than hiding rescans behind unique
IDs. Declaration and written/parameter argument maps allow at most 2*D and
2*A visits respectively. Build ordinal lookups once instead of rescanning all
formals for each named argument. Emitted identities, metadata and escaped
bytes have separate counters; these bounds do not imply output is proportional
to source length. Warning analysis retains its separate root/edge/formal work
bound in `NATIVE-BUILD-DIAGNOSTICS.md`; charge every actual visit against the
shared work limit.

Check cancellation at least every 4096 counted work events and every 65536
bytes of compiler-controlled emission/escaping, and before tool handoff and
commit. Chunk those loops and append ranges accordingly. Check before and
after snapshot, allocation and I/O calls; the existing whole-array snapshot
does not support cancellation during its internal copies. These are algorithmic
check intervals, not elapsed-time or mid-primitive cancellation guarantees.
The serial baseline has no speculative
retry whose discarded work could make resource admission depend on jobs.

## Byte storage and output

Use adopted UBECore ByteBuffer operations ByRef with one reusable current-module
buffer. Assignment, ByVal and record results copy storage, not transfer it.
Fields remain reserved library state. Clear between modules without shrinking;
release each module snapshot after its counted write finishes. Generated files
remain owned temporaries until cleanup, independently of the reusable buffer.

Check each append against the remaining cumulative LLVM allowance. Capacity
starts at eight and doubles; the initial power-of-two logical ceiling bounds
ordinary growth at 256 MiB. For smaller caller limits, charge actual rounded
capacity. Reserve old and new capacities simultaneously before growth. Across
monotone growth to capacity C, retained-payload growth copying is less than
2*C; count appended range bytes and zeroing separately.

`TrySnapshotByteBuffer` may copy an N-byte payload twice: into a prepared array
and then into its independently published result. Reserve up to 2*N snapshot
payload in addition to the buffer, including both arrays while rooted. Permit
one successful snapshot per module, not per append. Count allocation retries
and failure paths separately from successful-growth formulas. These obligations
follow `../../std-lib/BYTE-BUFFER-CONTRACT.md`; no zero-copy claim is made.

A counted byte writer belongs in UBECore or its minimal host boundary. The
current `FILE-BYTES-CONTRACT.md` provides reading/close, not this writer. Qualify
the required write/flush/close operation as a direct dependency: borrow the
exact snapshot, report partial writes and I/O failures, and retain ownership
until completion. Do not access reserved ByteBuffer fields or assume a read
primitive already supplies output. No new runtime subsystem or language syntax
is introduced by this dependency.

## Required implementation evidence

The caps are design selections and the formulas are candidate-algorithm
obligations. Actual emitter measurements follow implementation, before its
qualification or release; they do not require a working backend before design
review can finish. Record visits, emitted bytes, growth/snapshot copies,
zeroing, allocation/root failures, overlapping payload charges and separately
observed process/tool/storage usage.

Use the independent below/exact/above, zero, cancellation and failure controls
in `tests/native-executable/RESOURCE-ORACLES.md` through both source-built stages
and jobs 1/2/4. Require identical raw LLVM and semantic results, zero worker
source-payload copies, no repeated whole-project scan per emitted node,
controlled exhaustion and preserved output. Retain frontend/semantic performance
gates. If implementation needs extra traversals or another storage strategy,
review its revised bound before depending on it; do not hide excess work as
uncounted bookkeeping.
