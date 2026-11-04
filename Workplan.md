# UBE workplan

This is the repository-wide resumable checklist for active goals and handoffs.
Owner-defined release requirements live in `Release-Requirements.md`; long-term
sequencing lives in `project-docs/Roadmap.md`; module-specific work may use a
nearer roadmap or progress file.

## Status markers

- `[ ]` not started
- `[~]` in progress
- `[x]` complete and verified
- `[!]` blocked, with the reason and required decision recorded

## Completed next step - 2026-11-04

The owner-requested generated-storage alias/residency goal is complete.
Starting from commit 1376e39, focused diagnostics established the gaps, then
NativeStorageOwnership added complete generated-owner coverage, exact geometry,
resident permissions, disjointness and independently bounded metadata exclusion.
Legitimate TLS template containment, repeated labels and empty markers remain
permitted; zero-filled mutable globals remain supported.

NATIVE-STORAGE-OWNERSHIP-EVIDENCE.md in the active compiler records all nine
passing gates: 136 component groups, 32 storage image/reader groups and 7,040
rejected storage mutations, plus retained instruction/extent/target/unwind/image
relocation gates. The verification-only audit rechecked 666 unchanged paths.
Both readers pass 52,456,374 component assertions. No production cap increased.

Next qualify register/pointer provenance and whole-function control/dataflow,
including relocated tail jumps, initialization and termination closure, while
retaining the separate CRT/startup, stack/debug and builder/publication work.
The full First checked native executable deliverable remains unfinished.

## Resumed next step - 2026-11-04

The owner requested a new agent to resume the handoff and set a goal for the
next step. That bounded goal is complete: base-relocation validation and required
pointer write/value association within First checked native executable.
NATIVE-IMAGE-RELOCATION-EVIDENCE.md in the active compiler records all eight
passing gates, 132 component groups, 34 image groups, 4,704 rejected image
mutations and the unchanged 652-path audit. The test-only enclosing component
allowance is now 1,080 seconds after measured 944-second child work; production
caps are unchanged. At that checkpoint global storage and the other native
obligations remained; the generated-storage dependency is now qualified above.
The full native deliverable is not complete.

## Earlier owner-requested pause - 2026-11-04

The active First checked native executable goal is paused for handoff at the
owner's request, not complete. The last qualified checkpoint is TLS storage
association; bounded base-relocation validation is next and has not been
implemented. No verification process remains running. The detailed resume record
is in [compiler progress](compiler/UBE_Compiler_v3/Progress.md).
Read the "Paused for a new agent" section there for exact evidence, unfinished
investigation, remaining scope and worktree/tooling precautions.

## Current priority - 2026-11-02

- [x] Complete the owner-approved **First semantic checking** deliverable for
  the bounded scalar/native MODULE subset, including the existing check command,
  shared source-worker controller and exact native/process/resource gates.
  Accepted source-built cohort: `88d1906a667645fa87f885c3a117e52f`.
  [Semantic evidence](compiler/UBE_Compiler_v3/SEMANTIC-EVIDENCE.md) records the
  exact reports, source/tool/artifact identities, retained failure and scope.
  A later focused lifecycle-deferral correction is qualified on cohort
  `25f3b4878a1348e79766e70decd66b66`; its exact reports and limits are in
  `compiler/UBE_Compiler_v3/LIFECYCLE-DEFERRAL-EVIDENCE.md`. The earlier cohort
  remains historical; future hook execution and direct-call enforcement remain
  outside the bounded checker result.
- [x] Prepare and review the next existing **First checked native executable**
  deliverable's bounded lowering, backend, ABI/runtime-error and tool-handoff
  contracts with independent native/failure oracles. No backend implementation
  is part of the completed semantic goal.
  Draft and agent review: `compiler/UBE_Compiler_v3/NATIVE-EXECUTABLE-CONTRACT.md`
  and `NATIVE-CONTRACT-REVIEW.md`; detailed progress and remaining review,
  tool/ABI/resource and acceptance gaps are in `compiler/UBE_Compiler_v3/Progress.md`.
  The owner has confirmed the scope and several visible build and language
  behaviors; the bounded contract review is complete. Local fixture admission
  and focused LLVM probes do not establish native generation. The concrete
  review points are collected in `NATIVE-CONTRACT-REVIEW.md`.
  The 2026-11-03 review selects initial serial lowering and explicit resource
  caps in `NATIVE-RESOURCE-CONTRACT.md`, and nontransactional extended handle
  rename as the core commit direction. Path acquisition, stack safety, bounded
  diagnostic delivery and production debug-check scope are selected in
  `NATIVE-PATH-CONTRACT.md`, `NATIVE-STACK-REVIEW.md`,
  `NATIVE-BUILD-DIAGNOSTICS.md` and `NATIVE-DEBUG-CONTRACT.md`.
  Future backend acceptance is tracked
  separately from those preimplementation decisions.
  `NATIVE-RUNTIME-CONTRACT.md` now selects the private Err support and observer,
  with shared error-unit extraction required before use. The whole-runtime
  section-GC recipe failed a focused minimality audit, while its tested Err
  semantics passed; these outcomes are recorded separately.
  `NATIVE-TOOL-CONTRACT.md` selects tool identity scope, argument encoding/limits,
  invocation and cleanup deadlines, and bounded retained ownership for unresolved
  capture. These design decisions do not claim a working native launcher.
- [~] Implement and qualify the reviewed **First checked native executable**
  deliverable. Begin with the shared error-support extraction and counted
  byte-output dependency, then checked-graph lowering and the native tool path.
  `NATIVE-EXECUTABLE-CONTRACT.md` supplies the acceptance checklist;
  the existing independent oracles and retained frontend gates remain required.
  The owner-confirmed Err persistence and complete visible-field replacement rule
  is explicit in normative section 9 and the native runtime contract. Added stale
  description/source controls pass the 23-command error-support gate; see
  ERROR-SUPPORT-EVIDENCE.md. Resume execution remains outside this bounded subset.
  Shared error-support extraction has focused record, retained-caller and
  Full/None linked-inventory/TLS evidence in
  `compiler/UBE_Compiler_v3/ERROR-SUPPORT-EVIDENCE.md`. Counted output passes its
  focused direct/two-stage gate, recorded in `std-lib/FILE-OUTPUT-EVIDENCE.md`.
  The complete bootstrap passed 914 assertions on cohort
  `df15817344774026bebebfd1e9ae8eaf`. The subsequently promoted output-role
  diagnostic correction, scalar resource accounting, bounded byte emission and
  explicit graph traversal/preparation and scalar LLVM conversion/arithmetic
  fragments have focused two-stage evidence, including actual checked facts
  and mixed-width operator nodes. Declaration-target indexing and scalar/native
  storage have focused ownership/failure/ABI and real-catalog evidence. The
  ordered body consumer passes actual checked procedures, control flow, nested
  short circuit and ByRef effects through both stages at O0/O2. Native
  Pack/Unpack and equality also pass checked-procedure ABI/value/error tests
  and an altered-equality control. Ordinary guarded calls and exact/forced/default ByRef argument storage now
  pass focused two-stage O0/O2 call-effect/refusal tests with controlled stack
  metadata. Actual stack-footprint/startup qualification, module initialization
  and combined declaration-work acceptance remain pending;
  `compiler/UBE_Compiler_v3/NATIVE-IMPLEMENTATION-EVIDENCE.md`
  records scope and pending integration. The reusable directed-component search
  and compiler warning matrix/witness consumer now pass focused independent
  resource/failure/witness gates and are registered in production manifests and
  the full bootstrap. Checked-source/ByRef extraction now also passes its fresh
  two-stage gate over 23 cases, with exact dependency/warning-span, resource and
  failure oracles. It is registered in the compiler manifest and bootstrap gate;
  compiler/UBE_Compiler_v3/NATIVE-WARNING-EVIDENCE.md records scope and limits.
  Shared initialization data and inline access support now pass 54 focused
  two-stage groups, recorded in NATIVE-INITIALIZATION-EVIDENCE.md, and are registered.
  Private ByRef ownership now passes 64 two-stage graph groups and 26 focused
  emission groups. The reproduced declaration-reset fix also passes the refreshed
  64-group graph gate.
  Checked initializer body emission and procedure-root lookup now pass 76 graph
  groups and 26 component groups; NATIVE-INITIALIZATION-EVIDENCE.md records the
  exact native/resource scope. Foreign access and failure-unwind integration now
  pass 94 two-stage graph groups with actual checked three-module bodies and
  shared initialization support, including O0/O2 and negative controls. The
  same evidence file records controlled frame/wait-entry limits. Normal package/
  source scheduling now passes 118 component and 118 checked-project groups,
  with direct-reference metadata, O0/O2 order/failure/completion checks and exact
  work/identity/inlining evidence. Per-module output/imports now pass 154 graph
  groups and a six-group exact-work gate, including separate O0/O2 objects and
  controlled cap failure. NATIVE-MODULE-IMPLEMENTATION.md records the evidence.
  Common program entry and the ordinary adapter now pass 224 focused and 194
  checked-project groups, with controlled platform setup. NATIVE-ENTRY-IMPLEMENTATION.md
  records signed exits, same-thread Err, startup cutoff and Main-refusal evidence.
  Actual Windows stack setup/fatal/wait now pass 358 two-stage component groups,
  including common-entry integration at O0/O2 Full/None with controlled metadata;
  NATIVE-PLATFORM-IMPLEMENTATION.md records exact scope and retained controls.
  Frame-data emission and 36 object/data binding groups now pass; see
  NATIVE-FRAME-IMPLEMENTATION.md for exact scope and the controlled reserve.
  Bounded production binary readers now include names, primary symbol fields and
  relocation descriptions and bounded symbol inventories; 30 component and 224
  generated-artifact groups pass.
  NATIVE-OBJECT-EVIDENCE.md records comparisons, failure bounds and scope limits.
  Production definition-range and immutable data binding now pass 192 actual
  frame/reserve comparisons, including 64 understatement rejections; see
  NATIVE-BINDING-EVIDENCE.md. The expected-linkage owner now passes its independent
  34-group component gate; NATIVE-EXPECTATION-EVIDENCE.md records exact rows,
  resources and limits. Actual checked-project integration now passes the
  350-group full graph gate with jobs 1/2/4 and 144 object comparisons through
  both bootstrap stages. Definition/anchor retention now passes 416 linked
  groups, including 128 image-mutation rejections; see NATIVE-RETENTION-EVIDENCE.md.
  Object/image function-range readers now pass 46 component groups, 288 object
  comparisons (720 range observations) and 32 image comparisons (2,352 observations).
  The preceding data/reader/retention gates pass; see NATIVE-UNWIND-EVIDENCE.md.
  Retained extent binding now passes 50 component and 416 actual groups, with
  720 bound extents and 128 targeted mutation rejections; see
  NATIVE-EXTENT-BINDING-EVIDENCE.md. Selected scalar instruction inspection now
  passes 54 component and 128 actual-object groups (2,496 instruction observations);
  see NATIVE-INSTRUCTION-EVIDENCE.md. Bounded leaf traversal now passes 58
  component and 256 actual-object groups, including 112 function observations
  and 192 targeted mutation rejections; see NATIVE-LEAF-EVIDENCE.md. Function
  address indexing and fence lookup now pass 62 component and 832 object/image
  groups, including 2,880 fence observations and 512 rejected controls; see
  NATIVE-FUNCTION-INDEX-EVIDENCE.md. Complete leaf extent/map binding now passes
  66 component and 192 actual groups, with 112 leaf observations and 128 image
  mutations rejected by binding; see NATIVE-LEAF-BINDING-EVIDENCE.md. Named
  relocation target association now passes 70 component and 736 actual groups,
  including 5,696 named references through both readers and 448 rejected controls.
  The 16 anonymous references explicitly reject; NATIVE-RELOCATION-EVIDENCE.md
  records the proof and a focused 31-byte constant-section diagnostic. Anonymous
  constant contribution binding now passes 74 component and 96 actual groups,
  with 16 complete contribution observations, 32 reference associations and 80
  rejected mutations. The named-target matrix retains all 736 groups. See
  NATIVE-CONSTANT-BINDING-EVIDENCE.md for commands, identities and the subsequent
  112-code-section fixup diagnostic. Relocation encoding comparison now passes
  78 component and 960 retained groups: 11,424 field observations and 672 rejected
  linked-byte/addend/site mutations. NATIVE-FIXUP-EVIDENCE.md records its scope.
  Whole-code placement and complete byte comparison now pass 82 component and
  1,408 retained groups, with 224 contribution observations / 292,176 bytes and
  1,120 rejected mutations. The affected 96-group constant gate passes too.
  NATIVE-CODE-EVIDENCE.md records that proof. The INT3 decoder gap is now fixed;
  82 component, 896 complete-code instruction and 128 retained leaf groups pass.
  Both readers match 36,192 instructions / 146,088 unique code bytes and reject
  672 opcode/oracle controls; NATIVE-INSTRUCTION-EVIDENCE.md records scope.
  Traps still require termination-closure proof. Production contribution
  ownership now passes 86 component and 2,208 retained groups, including all
  16 images, anchor/coverage checks, independent RVA order and 1,888 refusals.
  NATIVE-CODE-OWNERSHIP-EVIDENCE.md records exact costs and current identities.
  Its measured 619-second component gate requires a 720-second bootstrap test
  deadline; production resource caps remain unchanged. A diagnosed missing
  indirect target-register descriptor now passes 88 component, 1,120 complete-code
  and 128 retained-leaf groups. NATIVE-INSTRUCTION-EVIDENCE.md records the proof;
  NATIVE-CONTROL-FLOW-INVESTIGATION.md records the relocation, initializer-table
  and API-return dependencies. Instruction relocation-field/effective-offset checks
  now pass 90 component, 2,240 complete-code and 128 leaf groups. All 5,712 fields
  match through both readers and 1,792 complete-code controls reject; see
  NATIVE-INSTRUCTION-RELOCATION-EVIDENCE.md. Signed linked targets now pass 92 component
  and 1,856 target/fixup groups, with the instruction/leaf gates retained. All 5,712
  targets match through both readers and 1,568 controls reject; see
  NATIVE-INSTRUCTION-TARGET-EVIDENCE.md. The separate ownership census records
  generated extents, reference cells, IAT and TLS-index associations in
  NATIVE-TARGET-OWNERSHIP-INVESTIGATION.md. Generated entries and storage extents
  now pass 96 component, 2,240 complete instruction, 128 retained-leaf and 2,784
  generated/signed-target/fixup groups. Both readers match all 3,128 generated
  references and reject 2,464 target/encoding controls; see
  NATIVE-TARGET-OWNERSHIP-EVIDENCE.md. Reference-pointer binding now passes 102
  component, 2,240 instruction, 128 leaf and 3,296 target groups; both readers match
  all 1,880 uses and reject 2,976 target/encoding controls.
  NATIVE-REFERENCE-POINTER-EVIDENCE.md records that proof and the measured test-only
  240-second full-probe / 900-second enclosing allowances. Import association now
  passes 108 component, 2,240 instruction, 128 leaf and 3,424 target groups,
  matching all 80 imports through both readers and rejecting 128 new controls.
  The shared directory reader also passes 288 object-unwind, 32 image-table and
  416 extent-binding groups. NATIVE-IMPORT-EVIDENCE.md records exact commands,
  identities and the unchanged 622-path audit. TLS storage association now passes
  126 component and 4,064 target groups, matching 592 index and 888 member
  references through both readers and rejecting 640 new controls. Instruction,
  leaf, unwind and extent-binding gates pass; NATIVE-THREAD-STORAGE-EVIDENCE.md
  records the exact source/report identities and unchanged 645-path audit.
  NATIVE-IMAGE-POINTER-INVESTIGATION.md classifies all 49 absolute pointer fields
  per image. Bounded base-relocation validation and exact pointer associations
  now pass 132 component and 34 image groups, including 1,568 field observations
  and 4,704 rejected mutations. All six affected retained gates and the 652-path
  audit pass; NATIVE-IMAGE-RELOCATION-EVIDENCE.md records exact proof and limits.
  Generated-storage ownership/residency now passes 136 component and 32 retained
  storage groups, with 7,040 rejected mutations and all nine gates passing.
  NATIVE-STORAGE-OWNERSHIP-EVIDENCE.md records the 666-path audit and exact scope.
  Continue with CRT TLS callbacks, register/pointer provenance and whole-function
  dataflow/control flow, then derive the complete reserve and
  qualify the remaining stack closures. The owner approved 3*D+I lowering work and
  further necessary resource adjustments. The added expectation pass makes the
  combined declaration/import bound 4*D+I; measured accounting is recorded in
  NATIVE-DECLARATION-WORK-REVIEW.md, backed by an actual checked counterexample.
  Complete startup/stack/wait safety, warning delivery, final source-cohort
  qualification and the native builder remain unfinished.

  The inventory's generic byte-key dependency now enforces byte/event budgets
  and cancellation and supports cross-arena queries. Existing APIs retain their
  full native regression, and new budget and retained consumer gates pass.
  See std-lib/BYTE-KEY-BUDGET-EVIDENCE.md. The compiler inventory now passes its
  shared-budget, cancellation, allocation/cleanup and relocation-membership gates.
  Complete binding and source-cohort qualification remain work under the active goal.

The checker accepts the contracted native MODULE projects and one explicit
direct library reference, selected Boolean/integer expressions and statements,
calls, constants and opaque native values backed by Byte/Integer/Long.
Successful checks return exit 0 with empty output and create no executable.
Earlier frontend failures retain their behavior; unsupported facilities defer.
The full compiler and actual UBECore source exceed this subset. Full grammar,
native generation and a semantic speedup claim remain outside this result.

UBECore owns the qualified generic SignedIntegers, ByteKeys, StorageCapacity and
Utf8Encoding facilities. Immutable source owners, private results, canonical
merge and the existing bounded worker budget remain the implementation rules.
Ordinary behavior follows VB6 unless an established UBE definition conflicts.

### Historical preparation and bootstrap identities

The dated checkpoints below preserve their original source/tool/artifact
identities. Their then-current capability and next-action statements describe
those checkpoints; the current implementation status is the section above.

The declaration-detail prerequisite was qualified on cohort
`04c889304e52467bbf597ac84269317e` with 1,879 parser checks and 104 source CLI
cases. The reusable-library foundation build passed 894 assertions on cohort
`3d4622079d9d476d9aad890dfa8593e8`, manifest SHA-256
`70B1F55EF276E2DAA12EB2939775E2FFA7AB7B68A0DCDC59476D16FEF55D1392`.
The before-edit 90-file snapshot remains
`bootstrap/out/semantic-baseline/549405a6379c411eaedfda49e1932ce9/`.
These are retained foundation records, not final acceptance of later inputs.

## Completed preparation and owner behavior review - 2026-11-01

The owner requested preparation of the existing **First semantic checking**
deliverable. The review package is now in
[`SEMANTIC-CONTRACT.md`](compiler/UBE_Compiler_v3/SEMANTIC-CONTRACT.md) and
[`SEMANTIC-SYNTAX-INVENTORY.md`](compiler/UBE_Compiler_v3/SEMANTIC-SYNTAX-INVENTORY.md),
with independent cases, source evidence and future native obligations under
`compiler/UBE_Compiler_v3/tests/semantic/`. Exact executed checks and their limits
are in [`SEMANTIC-EVIDENCE.md`](compiler/UBE_Compiler_v3/SEMANTIC-EVIDENCE.md).
This records the earlier review preparation; definition consistency alone did not implement or qualify the later checker.

The owner confirmed unsuffixed decimal integer destination typing, including
literals within arithmetic, and Long/LongLong defaults on 2026-11-01. That rule
is synchronized into the normative specification/conversion table and manual.
The bounded contract makes remaining context/representation limits explicit.

Owner review additionally confirmed that literals must use types able to hold
their values even when the destination is narrower. `Dim x As Integer =
40000 - 10000` behaves like a declaration followed by an ordinary assignment:
declare neutral storage first, calculate in a suitable wider integer type,
then convert 30000 to Integer. A recoverable initializer failure does not
undeclare the variable. Basic scope/foundation-first order is accepted; remaining
behavior questions are reviewed individually, using VB6 unless an established
UBE definition conflicts. The owner confirmed rejection of provable faults,
including known final overflow in ordinary initializers/assignments. Literal-
only integer calculations must reduce to constants during compilation; 40000 -
10000 becomes 30000 before destination conversion. Runtime-dependent failures
retain the established Err behavior. These are definition changes, not a claim
that fresh v3 already implements the semantic checker.

The owner subsequently approved implementation; the active next action is
recorded above. This paragraph records the preceding preparation checkpoint.

## Completed filesystem cleanups - 2026-11-01

Owner-requested bootstrap cleanup: consolidate the former root `runtime/`
folder and the two C adapters from `std-lib/src/win-lib/` under
`bootstrap/runtime/` (Windows adapters in `windows/`). Build/test paths and
native include paths are updated; logic and public names remain unchanged.
Fresh source qualification passes all 785 assertions on cohort `2c0fb05a3c4b4912861db33043acdb40`.
Strict source/local/project CLI gates pass 104/52/1202 cases/assertions, and the
borrowed-lifetime gate passes all 56 runs. The 96 focused relocation checks,
unchanged production LLVM and `git diff --check` complete this filesystem correction.
Exact commands, current identities and supported limits are in compiler v3 Progress.md.

Owner-requested filesystem cleanup: put fresh v3's production modules/classes
under `compiler/UBE_Compiler_v3/src/`, separate from plans and definitions.
The project manifest stays at the v3 root; tests/tools and contributor guidance
retain their locations. All 24 source files are byte-identical after relocation;
the ordered manifest and active tool/CLI-oracle paths are updated. Fresh source
qualification passes all 785 assertions; source/local/project CLI gates pass
104/52/1202 exact processes/assertions. Both production LLVM stages are identical
to the accepted pre-relocation CLI. The 122 focused relocation checks and
`git diff --check` passed. Before the runtime cleanup, this source-folder cohort
was `47d728ea15684fdd8639e444709df30b`; the current cohort is recorded above.
Details and exact evidence are in compiler v3's `Progress.md`. This filesystem
correction changes no language or compiler behavior.

Completed the owner-requested bounded normal `.UBE` input and qualified parallel
frontend deliverable. The accepted pre-relocation source cohort is
`a732173e4f3d450cb7a6feaa519af1d3`:785 source acceptance assertions and all seven
strict retained gates pass. Both complete performance sessions retain252 trials.
All original serial/small-input guards pass. The owner accepted close initial
gains on2026-11-01;1.5x/two-worker and2x/four-worker remain optimization targets.
The original eight numerical target misses remain recorded, with no baseline reset.

- [x] Freeze bounded project/reference, path/identity, source-order, span,
  diagnostic, CLI, ownership and failure/publication contracts before coding.
- [x] Freeze representative real/balanced/uneven/small corpora and complete
  reference streams before optimization; preserve both original baselines.
- [x] Implement and qualify ordered native MODULE input, direct explicit
  UBECore references, metadata/discovery and whole-result publication through
  the same `TryParseSources` worker budget. Current native consumer evidence
  covers35 cases, four independent contexts and375 observed allocator failures.
  The optional physical case-sensitive36th case is historical evidence.
- [x] Qualify the reviewed unused-argument-slot correction, address-owned root
  synchronization and existing coordinator wait of1ms. Native tests preserve
  the32-byte root ABI, global1,048,576 capacity, cross-thread cleanup, safe
  absence and initialization fallback. No additional executor or user ABI was added.
- [x] Pass fresh source, parser, source/local/project CLI, lifetime and concurrency
  gates; qualify repeatable useful gains through both complete measurement sessions.

| Corpus | Session1 speedup, two/four workers | Session2 speedup, two/four workers |
| --- | ---: | ---: |
| Real25-module corpus | 1.207x /1.304x | 1.211x /1.335x |
| Balanced32-module corpus | 1.279x /1.396x | 1.288x /1.423x |

Every parallel trial beats every serial trial within its session/main corpus;
four-worker trials also beat all two-worker trials. Source bytes, deterministic
results, zero worker source-payload copies, cancellation/drain, old-output
retention and actual resource-failure obligations remain qualified. Initial
performance acceptance follows the explicit owner revision, rather than claiming
the original numerical targets passed. Further optimization remains planned.

The compiler owns project/language policy and orchestration; UBECore owns reusable
algorithms and generic facilities. Shared owners remain immutable, worker results
private and publication deterministic under one budget. Root/collector changes
stay in the approved irreducible bootstrap substrate. Established names remain.

Evidence and exact commands: [project qualification](compiler/UBE_Compiler_v3/PROJECT-INPUT-EVIDENCE.md),
[performance qualification](compiler/UBE_Compiler_v3/FRONTEND-PERFORMANCE-EVIDENCE.md),
[owner acceptance policy](compiler/UBE_Compiler_v3/PERFORMANCE-ACCEPTANCE.md).
The final acceptance record is `0340fcdd651b45b5bf7ed1d6cd9fab7a/acceptance.json`
under `bootstrap/out/frontend-performance/`, SHA-256
`D0F00D1685929368F7E72E652623AC29F3E9C193E309D3CF93873CDF168FB36B`.

At this completed frontend checkpoint, First semantic checking was the next
deliverable and successful syntax reported checking unavailable. That is
historical behavior, superseded by the integrated bounded check path described
in the current priority. Full grammar and native code generation remain future
work. No new push is authorized.

## Historical concurrency checkpoint

The results and then-pending actions below describe the preceding concurrency
goal. Current project/frontend acceptance and the next action are recorded above.

Completed: the owner-requested bounded compiler-concurrency contract and actual
UBE-driven proof. Compiler-owned `TryParseSources` uses the existing source,
scanner and parser bodies with one worker budget, immutable source owners,
private work and complete failure-atomic publication. Budgets 1, 2 and 4 produce
the same complete results and canonical first failures. Cancellation and actual
allocation/root/start/wait failures preserve earlier output and drain workers.
UBECore retains generic mechanisms without source policy or an executor.

The then-current source-built bootstrap passed 592 grouped assertions. Bounded
field-only reference classes and scalar/reference `CallNew` captures preserve
ordinary independent array/record copies. UBECore's `Threads` Try APIs provide
fresh identity, liveness, stop, wait and yield status. The current concurrency
proof passed 5652 native assertions through both stages; retained parser and
strict CLI gates pass 4049 and 217 checks, and the rebuilt local executable
passes 41 exact process oracles. Exact commands, identities, costs and limits
are in [CONCURRENCY-EVIDENCE.md](compiler/UBE_Compiler_v3/CONCURRENCY-EVIDENCE.md).

Instrumented four-worker execution was slower than the one-worker reference;
collector contention is explicit follow-up work. No speedup is claimed.
The owner has approved an explicit
[parallel performance gate](project-docs/Development-Plan.md#parallel-performance-acceptance):
at least 1.5x speedup with two workers and 2x with four on representative real and
larger balanced corpora, with single-worker/small-input regression guards and
all correctness/resource gates retained. Measurement and optimization remain
unfinished. This is required before the parallel frontend is marked complete
and before substantial semantic/backend growth; it does not reopen the completed
concurrency correctness proof or start another implementation goal.
The owner has now requested the bounded normal `.UBE`/direct-UBECore frontend
row in the [development plan](project-docs/Development-Plan.md). Its concrete
contract requires review before production implementation. Later rows remain
proposed.
Full grammar, semantics, backend work and project/jobs CLI integration are not
capabilities implied by this completed goal.

## Earlier foundation and parser checkpoints

The first UBECore byte/text foundation is implemented and independently tested:
an incremental UTF-8 decoder and owned ByteBuffer with geometric growth,
failure-atomic operations and independent snapshots. The owner approved the
managed-storage scope and permits extending v2 as necessary for bootstrap.
`bootstrap/build-v2.ps1` passed 501 grouped assertions at that checkpoint, retaining the earlier
foundation gates and adding the fresh scanner/envelope consumer and exhaustive
Unicode qualification. Current runtime/bootstrap and production-parser results
are in `compiler/UBE_Compiler_v3/PARSER-NATIVE-EVIDENCE.md`; representation probes
remain in `compiler/UBE_Compiler_v3/PARSER-PROBE-EVIDENCE.md`. The earlier
scanner snapshot remains in `compiler/UBE_Compiler_v3/SCANNER-EVIDENCE.md`.

Completed: implement the smallest compiler source-ingestion consumer of these APIs.
`compiler/UBE_Compiler_v3/SOURCE-INPUT-CONTRACT.md` defines exact byte preservation,
streaming UTF-8/newline validation, scalar positions and independent publication.
The minimal fresh source and manifest pass independent native, failure, cleanup,
position and actual cost oracles through both source-built stages. Necessary
bootstrap prerequisites include recoverable byte-file/Unicode argument primitives
and bounded direct source-library references with envelope validation.
Source policy and diagnostics remain compiler responsibilities. Full shared
Library output, builtin String and language checking remain unqualified. No
archived implementation or restored compiler is required.

Completed next: define scanner/native-or-legacy envelope acceptance over exact
source snapshots. `compiler/UBE_Compiler_v3/SCANNER-CONTRACT.md` and its 102
hand-authored vectors/174 word roles pass 2286 data-consistency assertions.
This established the independent definition before production implementation.
Its historical readiness probes remain in the scanner evidence.

Completed: implement that defined consumer in UBE, with narrow reserved-name
renames, official pinned Unicode 18 data, ordinary UBE lookup/cursor helpers,
exact token/envelope spans, controlled diagnostics and failure-atomic results.
Both source-built stages pass native fixtures, real root/allocator failures,
cleanup, four private-worker comparisons and measured scanner copy/work budgets.
At that checkpoint, the complete gate passed 501 assertions; the scanner's observed executable
executes 2274484 native assertions per stage. Legacy recognition and raw date/
directive tokens do not establish their full grammar or semantics. `--check`
still reports checking unavailable after a successful scan.

Completed: define the first grammar consumer over qualified token/envelope views.
`compiler/UBE_Compiler_v3/PARSER-CONTRACT.md` has 116 hand-authored cases covering
grouping, source spans, structural rejection, later semantic obligations and
explicit deferred families. The definition gate passes 11969 new consistency
assertions and 16 negative controls; a separate identity audit preserves the
existing 501-check native cohort. That definition did not qualify an
implementation. Exact results and limits are in
`compiler/UBE_Compiler_v3/PARSER-EVIDENCE.md`.

Completed: focused native UBE storage/traversal probes pass 3828 assertions through
both accepted source-built stages. The measured choice is linked-child nodes and
explicit stacks. Persistent allocator denial exposed and fixed recoverable GC
tracing/first-error publication; the complete fresh source gate passes 501 grouped
checks with stronger recovery regressions. Exact identities, costs, tradeoffs and
limits are in `compiler/UBE_Compiler_v3/PARSER-PROBE-EVIDENCE.md`.

Completed: implement and independently qualify the bounded production grammar
consumer in `compiler/UBE_Compiler_v3/PARSER-CONTRACT.md`, using that representation,
borrowed source/token views, private pending nodes and atomic complete-result
publication. Native acceptance covers the full frozen syntax/rejection/deferred
cohort while preserving ownership, diagnostics, budgets, cleanup and measured
work/copy obligations. No UBECore API expansion was needed.
At that parser checkpoint, the refreshed bootstrap passed all 501 checks. The unrestricted parser gate
passes 4049 grouped checks through both source-built stages, all 188 independent
cases, 10412 actual root capacities and 102 cost rows, including complete failure
retention and cleanup. Strict CLI acceptance passes 82 cases and 54 diagnostic
controls; the rebuilt local executable passes all 41 process oracles. Exact
commands, hashes, limits and handoff are in
`compiler/UBE_Compiler_v3/PARSER-NATIVE-EVIDENCE.md`. No generic collection or worker
scheduler was added. That checkpoint preceded the subsequently owner-approved
concurrency goal. Current qualification and proposed next work are recorded in
`CONCURRENCY-EVIDENCE.md` and the priority above.

The owner chose to establish a fresh UBECore in `std-lib/` before further
compiler feature expansion. Grow the library with concrete compiler needs;
do not import the previous implementation or assume its APIs are the new base.
The existing v3/v4 plans below are preserved history and do not define the
next active implementation task.

The owner subsequently approved early library-defined native datatype
mechanisms and investigation of the smallest stage-zero/v2 bootstrap route.
The fresh compiler is named v3. Previous v3/v4 implementations, previews and
compiler-wide handoffs are now under `compiler/archived/`, with exact original
working-tree snapshots and recorded relocation-only integration edits. Resume
from `compiler/UBE_Compiler_v3/Progress.md` and `std-lib/ROADMAP.md`.

- [x] Move the entire previous library to `archive/source-library/`, preserving
  all 28 files byte-for-byte, including working-tree changes and instructions.
  `archive/source-library.snapshot.json` records sizes and SHA-256 values.
- [x] Establish `std-lib/UBECore.UBE`, its empty identity module, design,
  contributor guidance, and `std-lib/ROADMAP.md`.
- [x] Retarget historical build/test paths to the archived library; keep them
  separate from the fresh project.
- [x] Build the owner's requested finished-library inventory for VB6, VBA7,
  and UBE additions in `std-lib/INVENTORY.md`; keep planned scope distinct
  from implemented or frozen APIs. Its documentary gate covers 175 reference
  function/alias names and 73 historical private intrinsic names; detailed
  component-member/signature/value reconciliation remains explicitly open.
- [x] Select and test the bounded bootstrap tool/subset and define the first
  library contracts before implementation. Resume from `std-lib/ROADMAP.md`.
  The shared ledger and independent cases are in `std-lib/FOUNDATION.md`.
  The source-built seed and two restored v2 artifacts pass all 18 diagnostic-
  subset checks, but nine target probes fail. Exact results/provenance are in
  `std-lib/FOUNDATION-EVIDENCE.md`. The subsequent v2 and native-value goals
  resolve the scalar prerequisites. The approved managed extension and byte/text
  body qualification now pass the combined 296-assertion gate; initial failed
  probes remain historical evidence rather than acceptance results.
- [x] Complete the owner's bounded usable-v2 prerequisite: current-source build,
  fixed point and 130 independent acceptance assertions, with exact provenance
  and a maintained compile helper. No archived implementation was imported.
- [x] Archive previous v3/v4 and their preview/history material, preserve exact
  original bytes for 367 files, and establish the fresh v3 design/workplan.
- [x] Record the owner's native-datatype and temporary-bootstrap decisions;
  adopt and prove opaque scalar representation, explicit binding, zero/copy,
  equality and rejection behavior under delegated design authority.

Structural setup and archive-integrity checks do not constitute compiler or
library execution verification. Library module bodies now have independent
execution proofs; a full native Library project build remains unqualified.

## Preserved compiler checkpoint

- [x] Preserve and verify the self-hosting UBE Compiler v2.
- [x] Add ordered multi-module compilation and cross-module resolution to v2.
- [x] Reorganize documentation into public, normative-language, and project
  documentation areas.
- [x] Complete and statically verify the public documentation snapshot for the
  frozen UBE 1.0 definition, with specified behavior separated from verified
  Compiler v2 behavior and unresolved public APIs represented by status pages.
- [x] Define and freeze the UBE 1.0 language contract for Compiler v3.
- [x] Create the previous `compiler/archived/UBE_Compiler_v3/` with its architecture, roadmap, and
  v2-buildable project scaffold.
- [x] Establish the previous `source-library/` root (now archived) for UBE library source,
  with preview, portability, ownership, and resumable-work boundaries.
- [~] Develop and compile v3 using the preserved v2 compiler.
  - [x] Preserve the explicit RP0 scaffold baseline.
  - [x] Complete RP1: bounded multi-module compiler shell, project/source
    validation, host/target descriptions, compatibility identities, and the
    API-empty `UBECore` project boundary.
  - [x] Complete RP2: native and compatibility source envelopes, frozen UBE
    1.0 tokenization, conditional compilation, stable source mapping,
    deterministic token output, bounded recovery, and malformed-input tests.
  - [x] Complete RP3: embedded frozen grammar, complete bounded parser, owned
    syntax records, deterministic syntax output, recovery, and grammar-wide
    coverage.
  - [x] Complete RP4: bounded scopes and Unicode-folded symbols, semantic type
    and expression records, entry-point and declaration validation, stable
    semantic diagnostics, deterministic semantic output, and focused rejection
    tests.
  - [x] Complete RP5: verified typed IR, native LLVM output, compiler-owned
    toolchain handoff, and deterministic self-compilation.
  - [x] Complete RP6: managed values, objects/interfaces, tracing collection,
    project references, callable `UBECore`, and the foreign ownership ABI.
  - [x] Complete RP7: structured errors, threads and synchronization, events,
    forms/controls, and component lifetime with deterministic failure gates.
  - [x] Complete RP8 with project-group orchestration, bounded hashed resource
    and library bundles, explicit remaining-language compatibility diagnostics,
    optimization/debug controls, the minimum public `UBECore` API, and a
    verified Linux x86-64 ELF object boundary.
  - [ ] After the RP8 gate, execute the Beta 1 compiler parallelization plan in
    `compiler/archived/UBE_Compiler_v3/MULTITHREADED_COMPILER_PLAN.md`: preserve the
    v2-built sequential seed, add deterministic `--jobs` execution in measured
    phases, keep one job as the default, and require explicit caller-selected
    parallelism after reproducibility, failure, memory, and performance gates
    pass.
    - [x] Phase 0: add opt-in sequential compiler profiling, publish repeatable
      self/UBECore/source/procedure baselines, and remove the measured
      superlinear semantic and IR lookup paths.
    - [x] Phase 1: freeze and prove the sequential seed/production bootstrap
      split and record seed/executor identities.
    - [x] Phase 2: implement the bounded executor API with one-job behavior,
      deterministic failure injection, cancellation, drain, and cleanup gates.
    - [x] Phase 3: run independent source preprocessing, lexing, and parsing in
      a bounded worker pump with manifest-order deterministic merge.
    - [x] Phase 4: freeze declarations and types, analyze independent procedure
      bodies with private worker state, and merge semantic results canonically.
    - [~] Phase 5: the v3 audit removed quadratic whole-edge IR verification,
      per-function whole-program LLVM scans, and repeated folded grammar-rule
      dispatch, reducing the verified self-host from 800.7 to 400.7 seconds.
      V3 is now retained as the reference/bootstrap bridge for the planned v4
      design; do not extend its whole-project worker transport architecture.
- [~] Define Compiler v4 as a clean architectural generation while preserving
  v3 as its bootstrap compiler and differential oracle.
  - [x] Draft the v4 ownership model, reuse/retire classification, ordered
    milestone roadmap, and task-specific agent instructions under
    `compiler/archived/UBE_Compiler_v4/`.
  - [x] Obtain owner approval for the Task 0 architecture, parser decision
    process, library/compiler-support split, and task ordering.
  - [x] Run the approved bounded design prototypes and freeze phase interfaces
    before creating the v4 manifest or production source scaffold.
  - [x] Freeze and enforce the v4 verified-build policy: every roadmap step and
    claimed working build needs small purpose-built success, rejection,
    boundary, stress, failure, regression, differential, native, and
    determinism programs plus every applicable earlier test.
  - [x] Implement the Task 1 reusable foundation and exact dependency manifest
    before creating the Task 2 production scaffold.
  - [x] Build the Task 2 production session shell on the frozen Task 1 support
    boundary and permanent sequential reference path.
  - [x] Implement the Task 3 minimal genuine vertical slice through every
    compiler phase before adding broader language coverage.

## Handoff protocol

For active work, record:

- the exact objective and authoritative specification;
- current status and completed checklist items;
- decisions and assumptions;
- files changed;
- verification commands and results;
- remaining failures or blockers;
- the exact next action.

Update this file when repository-wide work changes state. Do not duplicate a
detailed module checklist here; link to the module's roadmap or progress file.
