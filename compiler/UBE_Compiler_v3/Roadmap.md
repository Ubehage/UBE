# UBE Compiler v3 workplan

The owner-requested next-step goal, generated storage alias/residency validation,
is complete. NATIVE-STORAGE-OWNERSHIP-EVIDENCE.md records all nine passing gates,
32 retained storage image/reader groups, 7,040 rejected storage mutations and the
unchanged 666-path audit. The earlier relocation checkpoint remains preserved.

Next qualify register/pointer provenance and whole-function control/dataflow.
CRT/startup effects, initial values, stack/debug, builder/publication and final
native acceptance retain their separate obligations. The full native-executable
deliverable remains incomplete. Progress.md records the current next action and
preserves historical handoffs and exact qualified checkpoints.

This is the fresh compiler's prerequisite checklist, approved in direction by
the owner on 2026-10-30. It works with `../../std-lib/ROADMAP.md`.

- [x] Archive the previous v3/v4 implementations and distinguish historical
  artifacts from the fresh v3 identity.
- [x] Record the approved library-first, native-datatype and bounded-bootstrap
  direction without importing the old architecture or implementation.
- [x] Define the primitive/type-mechanism ledger required by the first library
  slice: exact behaviors, ownership, safety, limits, failure and portability.
- [x] Inspect the stage-zero/v2 tool/subset against that ledger; select exact
  inputs and run small independent positive/rejection/native fixtures.
  `../../std-lib/FOUNDATION.md` records the contract and pending decisions;
  `FOUNDATION-EVIDENCE.md` beside it records 18/18 narrow-subset passes and
  nine failed target probes in the initial investigation. The subsequent
  owner-requested v2 repair is recorded in
  `../UBE_Compiler_v2/FOUNDATION-VERIFICATION.md`: 130 source-built acceptance
  assertions now pass for the bounded byte/scalar bootstrap subset. The native
  datatype extension and production byte/text library remain separate proofs.
- [x] Specify and prove a minimal library-defined native datatype mechanism,
  obtaining decisions for any new syntax or observable semantics it requires.
  The owner delegated those decisions, preferring compatible VB6 conventions.
  `../../std-lib/NATIVE-TYPE-PROPOSAL.md` is adopted; the bounded scalar proof
  passes 66 native and eight record assertions alongside all 130 earlier checks.
  See `../../std-lib/tests/native-type/NATIVE-EVIDENCE.md` for that checkpoint.
- [x] Implement and independently test the first UBECore byte/text foundation.
  The approved managed-storage prerequisites, Utf8 decoder and ByteBuffer now
  passed the combined source-only gate (296 assertions). Its exact evidence:
  `../../std-lib/BYTE-BUFFER-EVIDENCE.md`.
- [x] Measure construction/copying/memory behavior and test independent-instance
  reentrancy, immutable sharing and bounded worker ownership early.
  Actual allocation/copy/GC observations and four bounded native test workers
  qualify the component. UBE CallNew/compiler scheduling remain separate work.
- [x] Define the first genuine compiler consumer of those tested APIs, then
  create the minimal production manifest and source required by that consumer.
  Exact source input, counted file I/O, direct source references and entry
  admission pass the combined 470-check gate. See `SOURCE-INPUT-EVIDENCE.md`.
- [x] Define scanner/native-or-legacy envelope acceptance over exact source
  snapshots, with independently specified token and diagnostic oracles.
  `SCANNER-CONTRACT.md` and its data-consistency gate specify 102 hand-authored
  vectors and 174 word roles. 2286 consistency assertions pass; this does not
  qualify an implemented scanner. See `SCANNER-EVIDENCE.md`.
- [x] Implement that scanner/source-envelope consumer in UBE, satisfying its
  native fixture, failure, ownership, Unicode-data and measured-cost gates.
  The combined source gate at that checkpoint passed 501 grouped checks. Both stages
  produce identical raw LLVM and pass independent native fixtures, real root
  pressure, allocation faults, private-worker cleanup and observed copy budgets.
  Exact accepted identities and recognition limits are in `SCANNER-EVIDENCE.md`.
- [x] Define the first grammar consumer over qualified token/envelope views,
  with independent syntax, contextual grouping, diagnostic and bounded-failure
  expectations before choosing parser representation or implementing it.
  `PARSER-CONTRACT.md` and 116 hand-authored cases pass 11969 new definition
  assertions and 16 negative controls. The then-existing 501-check native cohort
  was audited unchanged. See `PARSER-EVIDENCE.md` for that definition snapshot.
- [x] Run focused native UBE representation/traversal probes against that
  contract, then document a measured storage/strategy choice before production
  parser implementation. `PARSER-PROBES.md` fixes candidates and budgets;
  `PARSER-PROBE-EVIDENCE.md` records 3828 passed assertions, the necessary
  recoverable-OOM bootstrap correction and fresh 501-check source qualification.
  Linked-child storage and explicit stacks are selected for the first consumer.
- [x] Implement and independently qualify the bounded production grammar consumer
  in `PARSER-CONTRACT.md`, preserving the measured storage/publication choice and
  complete ownership, failure, resource, cleanup and work/copy obligations.
  `PARSER-IMPLEMENTATION.md` records ownership and budget accounting.
  `PARSER-NATIVE-EVIDENCE.md` records the refreshed 501-check bootstrap,
  4049 native checks, all 188 cases and 10412 real-root capacities through both
  stages, measured bounds, strict CLI and qualified local artifact.
- [x] Define and qualify the owner-requested bounded compiler-concurrency
  contract and actual UBE-driven proof. Compiler-owned `TryParseSources`
  preserves immutable owners, private results, one budget, canonical failures,
  cancellation/drain and complete publication through budgets 1, 2 and 4.
  UBECore retains generic thread/storage mechanisms. `CONCURRENCY-EVIDENCE.md`
  records the current 592-check bootstrap, 5652 concurrency assertions,
  retained parser/CLI gates, exact identities, costs and supported limits.
- [x] Define, implement and qualify bounded normal `.UBE`/direct-UBECore input
  through the existing parallel frontend. Current source785/strict7 pass;
  PROJECT-INPUT-EVIDENCE.md records the35-case/four-context/fault/publication scope.
- [x] Qualify useful repeatable parallel gains under the owner's2026-11-01
  initial-performance revision. Both complete sessions/252 trials retain all
  serial/small and correctness/resource gates. Real gains are1.207-1.211x at two
  workers and1.304-1.335x at four; balanced gains are1.279-1.288x and1.396-1.423x.
  Original1.5x/2x targets remain future optimization targets, not claimed passes.
  See PERFORMANCE-ACCEPTANCE.md and FRONTEND-PERFORMANCE-EVIDENCE.md.
- [x] Prepare the bounded First semantic checking contract and actual retained-
  syntax inventory with independent cases and future native obligations.
  `SEMANTIC-CONTRACT.md`, `SEMANTIC-SYNTAX-INVENTORY.md` and
  `SEMANTIC-EVIDENCE.md` record definition evidence and review boundaries.
- [x] Obtain owner review of that concrete contract before the required parser
  detail extension, measured semantic storage probes and checker implementation.
  Preparation does not complete the semantic-checking deliverable.
  Basic scope/foundation-first order is accepted. Review actual remaining
  behavior questions individually using the owner's VB6-default guidance;
  wider literal types and declaration-before-initializer behavior are confirmed.
- [x] Retain and independently qualify declaration details in the existing
  parser under SYNTAX-DETAILS.md, preserving old syntax observations and the
  failure/resource/ownership gates. The strict 1,879-check native gate passes
  for source cohort04c; see SEMANTIC-SYNTAX-INVENTORY.md.
- [x] Measure and select semantic storage/lookup foundations; integrate the
  generic numeric, byte-key, capacity and UTF-8 facilities in UBECore.
- [x] Qualify the bounded checker, shared worker controller and check-path
  diagnostics on accepted cohort 88d. Maintained native/process/resource/cost/
  sharing gates and retained proofs pass; see SEMANTIC-EVIDENCE.md.
- [x] Prepare and review bounded lowering/backend/tool-handoff contracts for
  the existing First checked native executable deliverable. Executable generation
  is outside the completed checker goal.
- [~] Implement and qualify the reviewed First checked native executable
  contract, including its shared support dependencies and independent gates.

The 710-entry library inventory is target scope, not an instruction to implement
all families before the compiler begins. No new compiler phase architecture is
frozen by this checklist.

## Acceptance

An item requires its documented assertions/results to pass. Preserve focused
failure regressions, exact tool/input identities, actual work/copy/allocation
measurements, cleanup checks and applicable earlier tests. Archive integrity
and path/syntax checks do not verify a compiler or its generated programs.

## Active next action

Implement and qualify the reviewed First checked native executable contract.
Lower the checked graph and integrate the selected tools and publication
boundary. Preparation is complete; native generation is not. Shared error
support and counted byte output passed the 914-assertion bootstrap cohort.
The later resource, byte-emission, explicit traversal and scalar expression
components pass focused two-stage diagnostic gates, including conversion and
arithmetic fragments consumed from the real checker. Declaration-target
indexing and scalar/native storage also pass focused and real-catalog gates.
The ordered body consumer now passes actual checked procedure, control-flow,
short-circuit and ByRef native observations through both stages at O0/O2.
`NATIVE-IMPLEMENTATION-EVIDENCE.md` records exact scope and pending combined
declaration-work accounting. Native Pack/Unpack and same-nominal equality now
also pass complete checked-procedure O0/O2 tests and an altered-predicate
control; inverse argument links preserve the existing map traversal bound.
Ordinary guarded calls and exact/forced/default ByRef argument storage now pass
54 focused two-stage groups, including O0/O2 call-effects/refusal tests and an
inverted-admission control. Those tests supply controlled stack metadata; real
linked frame sizes, recovery reserve and startup/fatal qualification remain.
The reusable component search and compiler matrix/witness consumer pass their
focused two-stage gates, including actual pending/work/payload boundaries and
independent witnesses. Both are in production manifests and registered in the
full bootstrap, which has not yet run with these additions. Dense ByRef-formal
indexing preserves declaration storage/work and emitted program bytes.
Checked-source dependency discovery now passes six focused two-stage groups over
23 cases (22 accepted and one expected checker rejection), jobs 1/2/4, exact edges,
witnesses, actual costs, failure/cleanup and negative controls. NativeDependencies
and its fresh source gate are registered; NATIVE-WARNING-EVIDENCE.md retains the
proof and limits. Shared initialization data and per-output inline access support
now pass 54 focused groups (NATIVE-INITIALIZATION-EVIDENCE.md). The helper and gate
are registered. Private ByRef owner transport now passes 64 two-stage graph
groups and 26 focused emission groups; exact evidence is in
NATIVE-IMPLEMENTATION-EVIDENCE.md. The reproduced repeated-declaration reset
correction also passes the refreshed 64-group graph gate. Checked initializer
body emission and bounded procedure-root lookup subsequently pass 76 graph groups
and 26 component groups, with native order/neutral/temporary/Err and refusal
controls. The subsequent access/failure-unwind integration passes 94 two-stage
graph groups, linking actual checked three-module bodies with the shared helper.
NATIVE-INITIALIZATION-EVIDENCE.md records its native value/effect/Err, O0/O2,
negative-control and controlled frame/wait-entry scope. Normal package/source
scheduling subsequently passes 118 component groups and 118 checked-project
groups, including actual direct-reference metadata and O0/O2 failure/completion
tests. Module output/imports now pass the 154-group checked-project gate and
the six-group exact work-bound regression; see NATIVE-MODULE-IMPLEMENTATION.md.
The entry consumer now passes 224 focused and 194 checked-project groups with
controlled setup; see NATIVE-ENTRY-IMPLEMENTATION.md. Actual Windows stack
setup/fatal/wait now pass 358 two-stage component groups, including O0/O2 Full/None
common-entry integration with controlled metadata; see NATIVE-PLATFORM-IMPLEMENTATION.md.
Frame-data emission and test-owned object/data binding now pass their two-stage
gates; NATIVE-FRAME-IMPLEMENTATION.md records 36 binding groups with actual
checked entry and controlled reserve. Bounded production binary readers now
cover headers/sections, names, primary symbol fields/auxiliary extents and selected
relocation descriptions. NATIVE-OBJECT-EVIDENCE.md records 30 component groups
and 224 generated-artifact groups through both reader stages, now including
bounded symbol inventories and primary relocation target membership.
Production definition-range and immutable integer-data binding now pass 192
actual table/reserve comparisons, including 64 understatement rejections. See
NATIVE-BINDING-EVIDENCE.md; this still uses a controlled reserve. The pre-tool
expected-linkage owner now passes its independent component gate, including exact
row/source associations and charged D-row work; see NATIVE-EXPECTATION-EVIDENCE.md.
Actual checked-project integration now passes the 350-group full graph gate,
including jobs 1/2/4 root/reference inventories and 144 object comparisons.
Definition/anchor retention now passes 416 linked-artifact groups, including
128 rejected image mutations, through both production reader stages; see
NATIVE-RETENTION-EVIDENCE.md. Object/image function-range readers now pass 46 component groups,
288 object comparisons (720 range observations) and 32 image comparisons (2,352
observations); see NATIVE-UNWIND-EVIDENCE.md. Retained data/reader/retention gates
also pass. Retained declared-extent binding now passes 50 component groups and
416 actual groups (720 bound extents and 128 targeted mutation rejections); see
NATIVE-EXTENT-BINDING-EVIDENCE.md. Selected scalar instruction inspection now
passes 54 component and 128 actual-object groups; NATIVE-INSTRUCTION-EVIDENCE.md
records 2,496 instruction observations and scope limits. Bounded leaf traversal
now passes 58 component and 256 actual-object groups (112 function observations,
2,416 reachable instructions and 192 targeted mutation rejections); see
NATIVE-LEAF-EVIDENCE.md. Function address indexing and conservative fence lookup
now pass 62 component and 832 actual-object/image groups (2,880 fence observations
and 512 rejected controls); see NATIVE-FUNCTION-INDEX-EVIDENCE.md. Complete leaf
extent/map binding now passes 66 component and 192 actual groups (112 leaf
observations and 128 image mutations rejected by binding); see
NATIVE-LEAF-BINDING-EVIDENCE.md. Named relocation target association now passes
70 component and 736 actual groups: 5,696 named references resolve through both
reader stages, with 448 rejected controls; the 16 anonymous references explicitly
reject. NATIVE-RELOCATION-EVIDENCE.md records exact evidence and a focused
31-byte constant-section diagnostic. Anonymous constant contribution binding now
passes 74 component and 96 actual groups, including 16 complete contribution
observations, 32 reference associations and 80 rejected controls. The refreshed
named-target matrix still passes 736 groups. NATIVE-CONSTANT-BINDING-EVIDENCE.md
records exact proof and the 112-code-section fixup diagnostic. Relocation
encoding comparison now passes 78 component and 960 retained groups, including
11,424 field observations and 672 rejected linked-byte/addend/site mutations.
NATIVE-FIXUP-EVIDENCE.md records the exact qualification and remaining limits.
Whole-code placement and complete relocated/unchanged-byte comparison now pass
82 component and 1,408 retained groups, plus the affected 96-group constant
regression. NATIVE-CODE-EVIDENCE.md records 224 contribution observations,
292,176 content bytes and 1,120 rejected controls. Canonical INT3 decoding now
passes 82 component groups; the expanded instruction gate passes 896 groups,
matching all 36,192 instructions / 146,088 unique code bytes through both readers
and rejecting 672 controls. The retained 128-group leaf gate also passes;
NATIVE-INSTRUCTION-EVIDENCE.md records identities and limits. Production anchor
consistency, object coverage and complete retained-image contribution ownership
now pass 86 component and 2,208 retained groups. NATIVE-CODE-OWNERSHIP-EVIDENCE.md
records all 16 image comparisons, exact storage/copy bounds, failure controls
and the measured test-deadline adjustment. The subsequent indirect target-register
descriptor fix passes 88 component, 1,120 complete-code and 128 leaf groups.
NATIVE-INSTRUCTION-EVIDENCE.md records exact identities;
NATIVE-CONTROL-FLOW-INVESTIGATION.md identifies concrete field, initializer-table
and API-return obligations. Instruction-field/effective-offset checks now pass
90 component, 2,240 complete-code and 128 leaf groups. Both readers pair all 5,712
relocations and reject 1,792 complete-code controls. NATIVE-INSTRUCTION-RELOCATION-EVIDENCE.md
records that proof and unchanged caps. Signed linked targets now pass 92 component
and 1,856 target/fixup groups, with complete instruction/leaf checks retained.
NATIVE-INSTRUCTION-TARGET-EVIDENCE.md records all 5,712 target comparisons and
1,568 rejected controls. NATIVE-TARGET-OWNERSHIP-INVESTIGATION.md records frozen
extents, reference cells, IAT and TLS-index associations. Generated function entries
and data extents now pass 96 component, 2,240 complete instruction, 128 retained-leaf
and 2,784 generated/signed-target/fixup groups. NATIVE-TARGET-OWNERSHIP-EVIDENCE.md
records all 3,128 generated references through both readers, 32 independent owner
range comparisons and 2,464 rejected target/encoding controls. Reference-pointer
cell binding now passes 102 component, 2,240 instruction, 128 leaf and 3,296 target
groups, including all 1,880 uses through both readers and 2,976 rejected controls.
NATIVE-REFERENCE-POINTER-EVIDENCE.md records the exact proof and measured test-only
240/900-second allowances. NATIVE-IMAGE-DIRECTORIES-INVESTIGATION.md records the
16-image IAT/TLS/DIR64 diagnostic, including CRT TLS callbacks and unclassified
relocation fields. Import association now passes 108 component and 3,424 target
groups, with all 80 import references through both readers and 128 new rejected
controls. The complete instruction/leaf, object/image unwind and extent-binding
gates pass with the shared directory reader; NATIVE-IMPORT-EVIDENCE.md records
exact commands, source identities and the 622-path audit. TLS storage association
now passes 126 component and 4,064 target groups, matching all 592 index and 888
member references through both readers and rejecting 640 new controls. Instruction,
leaf, unwind and extent-binding gates pass; NATIVE-THREAD-STORAGE-EVIDENCE.md
records exact identities and the 645-path audit. The separate pointer census in
NATIVE-IMAGE-POINTER-INVESTIGATION.md classifies all 49 fields per image. Bounded
base-relocation validation and required pointer associations now pass 132
component and 34 image groups, with 1,568 field observations and 4,704 rejected
mutations. All eight gates and the unchanged 652-path audit are recorded in
NATIVE-IMAGE-RELOCATION-EVIDENCE.md. Generated-storage ownership and residency
now pass 136 component and 32 retained storage groups, including 7,040 rejected
mutations and all nine gates. NATIVE-STORAGE-OWNERSHIP-EVIDENCE.md records the
666-path audit and remaining scope. Next qualify register/pointer provenance and
whole-function dataflow/control flow, including trap termination closure,
then derive the complete recovery reserve
and qualify call-site/prologue, startup/API and refusal closures. Warning presentation, end-to-end checked-program integration, final
source-cohort qualification and retained gates remain unfinished.
The current decisions are in `NATIVE-EXECUTABLE-CONTRACT.md` and its linked
resource, runtime, tool, path, stack, diagnostic and debug contracts.
Use their independent acceptance gates and retain qualified frontend behavior.
Source changes during builds remain entirely the user's responsibility.

The inventory prerequisite now extends the existing UBECore byte-key sorter and
lookup with actual byte/event admission, cancellation and cross-arena queries.
Legacy, bounded and integrated foundation gates pass, and reader/generated-input
gates remain passing with the changed Core. Exact evidence is in
../../std-lib/BYTE-KEY-BUDGET-EVIDENCE.md. The compiler inventory now passes its
own admission, cancellation, failure/cleanup and membership gates, recorded in
NATIVE-OBJECT-EVIDENCE.md. Complete retention/fixup binding remains unfinished.

## Earlier preparation record

The following records the investigation before final selection. The contracts
and current action above supersede its open-decision statements.

Prepare and review First checked native executable's small included/deferred
program set, lowering from the qualified semantic result, target ABI/native-value
and runtime-error behavior, LLVM validation and tool/cancel/publication failures.
Author independent value/exit/failure oracles before implementation. Keep the
existing dependency order, library/compiler responsibilities, original spans,
qualified immutable owners/private results and shared worker budget.
On-disk source consistency is the user's responsibility. Do not add monitoring,
source-change rejection or automatic retry to the native-build contract.
The draft selects Clang verification/object generation and a separate explicit
LLD link, with staged host evidence in `tests/native-executable/verifier/EVIDENCE.md`.
Explicit startup/archive resolution and the child environment are now selected
with Full/None object/link comparisons and omitted-option controls. Complete
common path acquisition and stack
safety remain unresolved contract prerequisites. The core publication direction
is nontransactional extended handle rename, with 16 combined ordinary-path host
cases. `NATIVE-RESOURCE-CONTRACT.md` selects initial serial lowering, explicit
resource caps and work/copy obligations; actual implementation measurements and
the counted byte writer remain acceptance/dependency work. The main contract
now separates remaining design choices from future implementation gates.
`NATIVE-RUNTIME-CONTRACT.md` selects the private Err support/observer and a
shared error-unit extraction dependency. The whole-runtime link failed the
minimality audit despite passing the tested error behavior; unrelated exported
library/GC support must not be carried into the bounded output. Stack admission
and its startup/fatal path remain separate design work.
`NATIVE-CANDIDATE-REVIEW.md` selects the finite structural
profile with host layout and Full/None mutation evidence; production integration
and binding the inspected candidate to publication remain implementation gates.
The new-command diagnostic interface and its 24 independent output vectors are
selected. Initialization-warning grouping, conservative reachability and exact
ByRef forwarding now have a selected policy with a 21-case graph model and three
adverse controls. Production analysis and byte/console delivery remain future
acceptance gates.
`NATIVE-TOOL-CONTRACT.md` selects executable/dependency identity scope, UTF-16
argument limits, lifecycle deadlines and overlapped capture/retained-owner
cleanup policy. Windows system components are trusted host prerequisites,
not a per-build whole-OS DLL lock. The common path mechanism and actual process
boundary still need implementation/qualification; bounded diagnostic delivery
remains separate from tool capture.
The stack review now fixes the distinction between own-frame allocation and
complete call footprint; its corrected host guards remain experiments pending
a justified recovery reserve and complete entry-path coverage.
