# UBE Compiler v3 workplan

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
- [ ] Proposed next: define the development plan's bounded First semantic
  checking contract, beginning with retained declaration details, scopes and
  selected scalar rules. Implementation remains pending that contract/review.

The 710-entry library inventory is target scope, not an instruction to implement
all families before the compiler begins. No new compiler phase architecture is
frozen by this checklist.

## Acceptance

An item requires its documented assertions/results to pass. Preserve focused
failure regressions, exact tool/input identities, actual work/copy/allocation
measurements, cleanup checks and applicable earlier tests. Archive integrity
and path/syntax checks do not verify a compiler or its generated programs.

## Active next action

The completed project/frontend deliverable has its exact source/test/measurement
record in PROJECT-INPUT-EVIDENCE.md and FRONTEND-PERFORMANCE-EVIDENCE.md. Preserve
its qualified ownership, library boundary, names, determinism and one worker budget.

The next proposed development-plan row is **First semantic checking**. Before
implementation, inventory the declaration details retained by syntax and define
the bounded scope/lookup/type/diagnostic contract with independent cases, exact
spans, failure publication and deterministic private body work. Do not guess
missing declaration information from node kinds or create another source parser.
Reusable text/numeric operations belong in UBECore; language policy stays here.
No semantic/backend code or new phase architecture is authorized by this handoff.
