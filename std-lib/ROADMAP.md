# UBECore workplan

## Bounded byte-key indexing dependency - 2026-11-03

The existing ByteKeys sorter/lookup now shares its implementation with explicit
byte/event-budget and cooperative-cancellation APIs. Cross-arena queries borrow
their own byte owner, avoiding object/image concatenation. Existing APIs retain
all 4,827,069 legacy native assertions per bootstrap stage; the new bounded gate
passes 2,103,397 per stage, including every cancellation admission, exact/below
budgets, old outputs, root/allocation refusal and physical byte observations.
BYTE-KEY-BUDGET-EVIDENCE.md records exact commands, reports and limits. Both gates
are registered in the bootstrap. Integrated arena/actual-worker foundations and
native binary/generated-input gates also pass with the changed Core. The complete
source-built bootstrap, checker resources and performance remain unrefreshed.
Next consume these bounded operations in the compiler's primary-symbol and
owned-identity inventory. No compiler naming/COFF policy enters this library.

## Binary inspection dependency - 2026-11-03

BinaryBytes adds ordinary allocation-free little-endian reads under
BINARY-BYTES-CONTRACT.md, with exact bit patterns for widths 1..8 and preserved
outputs on failure. Its actual byte visits, integer boundaries, invalid ranges,
input/Err preservation, root/allocator refusal and cleanup pass through both
pinned bootstrap stages in the compiler's native-objects gate. That gate passes
26 groups and is registered in the full bootstrap. Exact command, report and
source hashes are in ../compiler/UBE_Compiler_v3/NATIVE-OBJECT-EVIDENCE.md.
COFF/PE policy and inspection budgets remain compiler-owned. No new primitive
or language behavior is introduced; full source qualification remains pending.
The compiler now uses the same facility for borrowed names, symbols and
relocations; a 224-group gate also covers retained actual generated artifacts.
Next implement indexed compiler symbol/identity binding over these readers.

## Initialization-warning graph dependency - 2026-11-03

The generic GraphComponents implementation and compiler matrix/witness consumer
now pass their focused two-stage DiagnosticOnly gates. The library gate passes
six groups and 2,175,517 assertions per stage, including actual pending limits,
independent reachability, observed transitions/peaks, ownership/failure checks
and two negative controls. The compiler consumer passes six groups and
2,098,158 assertions per stage, including exact witnesses and shared budgets.
Contracts and exact reports are in GRAPH-COMPONENTS-CONTRACT.md,
GRAPH-COMPONENTS-EVIDENCE.md and the compiler's NATIVE-WARNING-EVIDENCE.md.
The module is now in UBECore. Its public check wrapper and the compiler consumer
are registered in the full bootstrap gate; that updated bootstrap has not run.
The compiler's checked-source/ByRef extraction now passes its fresh two-stage
23-case gate and is also registered. Next implement runtime module initialization
in the compiler, then retain final source qualification. Module policy and
diagnostics stay in the compiler; no additional Core API was needed for discovery.

## Native emitter dependencies - 2026-11-03

The generic signed decimal byte encoder and explicit ByteBuffer payload release
are implemented under `INTEGER-OUTPUT-CONTRACT.md` and `BYTE-BUFFER-CONTRACT.md`.
The compiler's focused emission gate observes exact decimal boundaries/counts,
no allocation/copying under full root pressure, concurrent private encoders and
preserved TLS error state, plus actual buffer growth/snapshot/release costs.
Both pinned bootstrap stages pass; report and limitations are recorded in
`../compiler/UBE_Compiler_v3/NATIVE-IMPLEMENTATION-EVIDENCE.md`. This diagnostic
component checkpoint is later than the accepted bootstrap cohort. Final source
qualification remains required; guarded creation/publication and checked-graph
lowering remain compiler integration work.

## Counted output dependency - 2026-11-03

The active First checked native executable item requires counted byte output.
`FILE-OUTPUT-CONTRACT.md` fixes the focused write/flush declarations, borrowed
payload and token ownership, partial progress/failure behavior and independent
acceptance cases. The implementation passes its 19-group native/two-stage gate,
including exact byte read-back, short writes, failures, resource accounting,
concurrent owners and five defective controls. `FILE-OUTPUT-EVIDENCE.md` records
the command, source/LLVM identities and scope. The enclosing bootstrap passed
914 acceptance assertions on cohort `df15817344774026bebebfd1e9ae8eaf`.
Later checker/native-builder edits still require final retained qualification.
The existing close/token mechanism remains shared; native-build guarded file
creation and executable publication require their own integration evidence.

## Bootstrap support location - 2026-11-01

The owner moved the temporary file/thread C adapters out of `src/win-lib/`
and into `../bootstrap/runtime/windows/`, beside the other native bootstrap
support. UBECore's production source tree contains UBE. Names, bindings,
contracts and adapter replacement conditions are unchanged. Current source
qualification passes 785 assertions; strict source/local/project CLI and
borrowed-lifetime gates pass on the consolidated layout. Exact source identities,
commands and evidence are in compiler v3 `Progress.md`.

## Qualified project-input consumer - 2026-11-01

The approved PathBytes/FileBytes working-directory and opened-file identity
facilities are qualified through the current bounded compiler consumer.
Ordinary path normalization/resolution remains UBE; the two host observations
stay behind the existing Windows adapter. Compiler source/project policy and
the single worker budget remain compiler-owned, with no executor in UBECore.

The current source cohort passes785 assertions and all seven retained gates,
including project CLI1202, native35-case/four-context/375-fault intake and actual
source concurrency4200 assertions per stage. Both full performance sessions
show useful gains accepted under the owner's revised starting-point criterion;
all source-copy/resource/lifetime/regression obligations remain. Detailed current
scope and exact commands are in the root Workplan.md and compiler evidence.
Earlier619/638/692 checkpoints remain historical records, not pending work.
The public API remains the adopted contract; no new library API was added for
the compiler's root/collector bookkeeping optimization.

## Owner decision — 2026-10-30

Build a fresh UBECore in `std-lib/`, growing with the compiler's needs.
Preserve the existing library as an archive rather than building on its
implementation. This is the active library direction; prior compiler and
library checklists are retained as history.

The owner approved the early native-datatype proof and bounded stage-zero/v2
bootstrap investigation, and assigned the fresh compiler the v3 name.
Its design and workplan are under `../compiler/UBE_Compiler_v3/`; previous
v3/v4 sources, previews and handoffs are under `../compiler/archived/`.

## Earlier foundation checkpoints

- [x] Qualify the owner-approved bounded threading prerequisite. `Threads.bas`
  supplies `TryCurrentThreadId`, `TryThreadIsAlive`, `TryThreadRequestStop`,
  `TryThreadStopRequested`, `TryThreadWait` and `TryThreadYield` under
  `THREADS-CONTRACT.md`. The source-built bootstrap's 592-check gate covers
  actual UBE reference captures, original array/record value semantics,
  failures, real roots, TLS and cleanup. The compiler's separate bounded
  source-set proof passes 5652 native assertions; exact current evidence is in
  [CONCURRENCY-EVIDENCE.md](../compiler/UBE_Compiler_v3/CONCURRENCY-EVIDENCE.md).
  This does not qualify full threading or shared-Library packaging. No executor,
  source document or compiler policy belongs in UBECore.

- [x] Archive all 28 previous library files without changing their bytes.
  The archive snapshot records SHA-256 values, sizes, and directories.
- [x] Establish a fresh `UBECore.UBE` project with an empty identity module,
  contributor guidance, and a separate design/workplan.
- [x] Inventory the finished VB6/VBA7 runtime surface and UBE-defined additions,
  including datatypes, callables, objects/constants, compiler/substrate
  boundaries, and unresolved compatibility decisions. The owner requested
  this inventory and explicitly included VBA7 on 2026-10-30; see `INVENTORY.md`.
- [x] Define the primitive/type-mechanism ledger and independent acceptance
  obligations in `FOUNDATION.md`, keeping undecided syntax/ABI explicit.
- [x] Investigate the smallest bootstrap tool/subset with independent native
  and rejection cases. `FOUNDATION-EVIDENCE.md` records 18/18 subset passes,
  nine failed target probes and exact tool/source provenance limitations.
- [x] Qualify source-built v2 for the bounded Byte/Integer/Long scalar, record
  and compact-array work needed next. The owner explicitly requested the repair;
  `../compiler/UBE_Compiler_v2/FOUNDATION-VERIFICATION.md` records its fixed point
  and the original 130 acceptance assertions.
- [x] Review the native-type mechanism proposal, settle its syntax/ABI and
  prove one small library-defined native datatype before substantial higher-
  level type implementation.
  The owner delegated design decisions with VB6 compatibility preferred.
  `tests/native-type/NATIVE-EVIDENCE.md` records the adopted scalar mechanism:
  66 native assertions, eight record baselines and all 130 earlier assertions.
- [x] Define the first byte/text storage and construction contracts, including
  failures, ownership, Unicode boundaries, and sharing behavior.
  `BYTE-TEXT-CONTRACT.md` defines the decoder and storage obligations; the
  compiler-wide managed mechanism was subsequently approved and implemented.
- [x] Implement that first facility in UBE and a library-only test runner.
  Utf8.bas and ByteBuffer.bas pass the source-body runners through both stages;
  the earlier source-body gate records 296 assertions. See BYTE-BUFFER-EVIDENCE.md.
- [x] Establish meaningful work/allocation/copy/memory measurements and
  appropriate concurrent-instance tests before compiler use.
  Decoder state is 16 bytes with zero measured allocations and one Feed call
  per byte at measured input sizes; four independent test workers pass.
  ByteBuffer growth/snapshot allocation and actual payload-copy measurements,
  failure injection, scope cleanup and four native workers pass their oracles.
  These qualify the component, not a UBE thread scheduler or compiler worker pool.
- [x] Supply counted UTF-8 arguments/paths and recoverable stepwise file bytes
  for the first compiler consumer. Explicit resource cleanup, cancellation by
  early close, fault atomicity and private native workers pass their oracles.
  Intact library source references and the source reader passed the earlier
  470-check gate and remained covered by the subsequent 501-check snapshot. See
  `../compiler/UBE_Compiler_v3/SOURCE-INPUT-EVIDENCE.md`.
- [x] Implement the raw scanner's concrete Unicode and scalar-cursor needs in
  ordinary UBE, with checked-in official Unicode 18 raw data, license,
  provenance and offline deterministic generation. Exhaustive native tests
  through both accepted stages pass; see `UNICODE-EVIDENCE.md` for their limits.
- [x] Qualify the Unicode/cursor slice against the final current-source
  bootstrap selection with the unchanged maintained gate: eight assertions pass
  within the complete 501-check gate. Exact cohort/report identities are in
  `UNICODE-EVIDENCE.md`; earlier diagnostic runs remain historical.

## Subsequent needs

The compiler's production parser now uses the measured linked-child nodes and
explicit stacks over the existing UBECore byte, Unicode and cursor facilities.
No library collection, primitive or API expansion was needed. Both source-built
stages pass the full bounded native gate, including failure retention, cleanup,
private workers and measured work/copy bounds. That parser checkpoint
passed all 501 foundation checks. Its identities, commands and limits are in
`../compiler/UBE_Compiler_v3/PARSER-NATIVE-EVIDENCE.md`; the earlier probes and
their recoverable-memory prerequisite remain historical evidence.

Add collections, lookup/hashing, sorting, file/path facilities, platform
adapters, and concurrency facilities only as concrete consumers require them.
Their order, APIs, and representations have not been approved by this setup.
Do not resume compiler feature expansion by duplicating missing library code.

## Evidence and limits

The archive move was checked against a snapshot taken immediately before it:
all 28 file counts, sizes, SHA-256 values, and directory paths matched.
`archive/source-library.snapshot.json` retains that snapshot.

The setup acceptance procedure checks the archive against the snapshot, resolves
every archived/new manifest Source entry, checks historical script paths and
PowerShell syntax, checks the empty new API boundary, and checks diff hygiene.
It does not establish language, library, bootstrap, or native execution support.
The initial setup did not compile the project. Current ordinary module-body
qualification is recorded above; standalone shared-library output remains unbuilt.

Setup verification command:
`rtk proxy powershell -NoProfile -File bootstrap/out/verify-library-layout.ps1`.
It passed: 28 archived file hashes/sizes, the exact directory set, four
manifests with 20 source paths, four parsed PowerShell scripts, eight historical
script input paths, the historical JSON dependency path, and zero public
declarations in the fresh project. Generated results are recorded in
`bootstrap/out/library-layout-verification.json`. These are setup artifacts,
not a library build gate. `rtk proxy git -c core.safecrlf=false diff --check`
also passed for tracked changes.

## Exact next action

Implement and qualify the counted byte-output dependency in
`FILE-OUTPUT-CONTRACT.md` for the reviewed native-executable consumer. Preserve
the qualified byte/Unicode/file/path/thread and semantic numeric/storage
foundations, their ordinary UBE algorithms and existing contracts/names.
Do not import compiler policy or implement the full inventory. Guarded file
acquisition remains a separate native-build integration obligation.

## Unicode and cursor handoff - 2026-10-30

`src/portable/Unicode.bas` implements Unicode 18 Lu/Ll/Lt/Lm/Lo membership and
default C/S simple folding. Its generated balanced decisions contain 694 letter
ranges and 219 constant-delta stride ranges covering 1,533 fold mappings.
`src/portable/Utf8Cursor.bas` reads one scalar from a borrowed immutable byte
array through the existing decoder, with neutral outputs on failure. Neither
introduces an intrinsic, mutable initialization or compiler-type dependency.

The official raw UCD files, final-version ReadMe, Unicode License V3 and exact
retrieval hashes are under `data/unicode/18.0.0/`. The maintained generator and
acceptance procedure operate offline. Current-source native runs compare the raw
data independently with every codepoint and the bootstrap headers, decode every
scalar, and cover malformed input, offsets, Err, immutable shared input, four
workers, cleanup and observed work/allocation/copy bounds through both pinned
stages. The unchanged maintained gate now passes all eight Unicode/cursor
assertions within the complete 501-check gate. The final cohort is
`bootstrap/out/v2/4eb76c64ed774a1a9fb38b38155b71ef/`; exact manifests, report
hashes and observed work are in `UNICODE-EVIDENCE.md`. Earlier diagnostic runs
deliberately bypassed stale source-cohort checks and remain historical only.

## Byte/text handoff - 2026-10-30

`BYTE-TEXT-CONTRACT.md` identifies source ingestion as the first compiler
consumer and separates bytes, Unicode scalars and source byte positions.
`src/portable/Utf8.bas` implements reset/feed/finish without managed state.
`tools/check-utf8.ps1` passes all scalars, one/two-byte strings, boundary and
random sequences, state copying, failure/Err and independent-worker oracles.
The initial storage probes recorded ten failed obligations. Under the owner's
subsequent approval, v2 now implements precise array roots, independent record/
array copies, managed call/results, safe element borrowing and recoverable
allocation failure. ByteBuffer adds ordinary UBE growth, append, snapshots and
UTF-8 scalar counting. The maintained gate passes all 296 assertions including
the focused regressions, 13 functional buffer and five instrumented report
checks. `BYTE-BUFFER-EVIDENCE.md` records exact identities and actual measured
work, memory, failure and four-worker results. The library manifest includes
both functional modules and its identity anchor; only ordinary bodies are
qualified in that earlier snapshot, not full native Library packaging. The later
470-check source-consumer goal validates intact source-reference builds and adds
FileBytes plus the first fresh v3 production source. Shared-library packaging
remains unqualified; current evidence is in the source-consumer record above.

## Native mechanism handoff - 2026-10-30 (earlier snapshot)

The owner delegated syntax/ABI decisions, preferring VB6 where compatible with
agreed definitions. V2 now implements opaque nominal Byte/Integer/Long-backed
values, synthesized zero/copy, exact explicit Pack/Unpack metadata and equality.
Bindings belong to the type's declaring source module. Ordinary records remain
covered by their independent baseline. `bootstrap/build-v2.ps1` passes 204
assertions and publishes its selection only after both additional proof suites
pass. Grammar, semantics, bootstrap profile and public reference agree on this
bounded addition. Exact identities, tests and limits:
`tests/native-type/NATIVE-EVIDENCE.md`. No archive, seed or public UBECore API
was imported or introduced by this goal.

## Foundation handoff - 2026-10-30

The owner explicitly requested a goal for the first contract and bounded
bootstrap investigation. The maintained command is:
`rtk proxy powershell -NoProfile -File std-lib/tools/check-foundation.ps1`.
It builds only the current small seed/runtime in a separate generated output
directory and checks exact native results, storage widths, rejection and repeat
LLVM identity against independently specified cases. Optional restored v2
artifacts are identified and tested without claiming source reproduction.

All six narrow-subset cases pass in each of three tools. Byte is unsupported;
v2 Integer storage is i32; seed ByVal records are unsupported; the bootstrap
StringFromByte operation excludes zero and terminates on that input. These
limits prevent using the tested subset as the proposed datatype/byte-text base.
The source-built seed is selected only for the demonstrated diagnostic work.
`FOUNDATION-EVIDENCE.md` records identities, results and remaining obligations.
No archived code was imported, no production bootstrap source was changed,
and the fresh library project still has no implemented APIs or execution proof.

## Inventory handoff — 2026-10-30

Current bootstrap handoff: the subsequent usable-v2 goal passed the maintained
`bootstrap/build-v2.ps1` gate with 130 assertions. It builds from current source
without restored executables, supports tested Byte/Integer storage/conversions
and diagnoses unsupported deep-copy paths. It also fixes integer-failure
termination and rejects expressions exceeding the bootstrap depth limit before
recursive processing. See the v2 verification record for exact identities,
commands and remaining language/runtime limits. The earlier foundation handoff
above describes the pre-repair investigation; those backup artifacts are not
the current selected tool.

The owner requested a finished-library overview covering the VB6 runtime and
UBE additions, and explicitly included VBA7. `INVENTORY.md` links four detailed
catalogs with 710 rows. These include named APIs and types, grouped constants
and component members, unnamed capabilities, and historical private hooks.
Counts are not unique public-function counts. The archive was read only as a
documentary source; no implementation was imported or changed.

`rtk proxy powershell -NoProfile -File std-lib/tools/check-inventory.ps1`
passed: 175 function/alias baseline names, 73 historical intrinsic names,
five document structures, duplicate-key checks, 52 local link targets, reference
definitions, and whitespace. Microsoft primary sources establish VB6/VBA
lineage; local normative sources govern UBE behavior. Cross-review corrected
ownership/signature descriptions and added previously missing named coverage.

Exact public signatures, constant values, per-class UI/member matrices,
LongPtr/PtrSafe compatibility, Variant missing/error states, and other recorded
compatibility decisions remain open. The inventory is a planning baseline;
it does not freeze or implement those APIs. Nothing was compiled or executed.

## Compiler archive handoff — 2026-10-30

Historical references in the inventory and its checker now select
`compiler/archived/UBE_Compiler_v3/` and `UBE_Compiler_v4/`. The archive integrity
gate also checks the previous 28 library files against their original snapshot.
The previously recorded setup runner under bootstrap/out describes the former
layout; use the maintained archive gate for the current compiler paths:
`rtk proxy powershell -NoProfile -File compiler/archived/verify.ps1`.
The inventory gate remains `std-lib/tools/check-inventory.ps1`.
