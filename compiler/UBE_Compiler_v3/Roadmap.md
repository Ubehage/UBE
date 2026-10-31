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
  See `../../std-lib/tests/native-type/NATIVE-EVIDENCE.md` for current evidence.
- [x] Implement and independently test the first UBECore byte/text foundation.
  The approved managed-storage prerequisites, Utf8 decoder and ByteBuffer now
  pass the combined source-only gate (296 assertions). Exact current evidence:
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
  The combined current-source gate passes 501 grouped checks. Both stages
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

The 710-entry library inventory is target scope, not an instruction to implement
all families before the compiler begins. No new compiler phase architecture is
frozen by this checklist.

## Acceptance

An item requires its documented assertions/results to pass. Preserve focused
failure regressions, exact tool/input identities, actual work/copy/allocation
measurements, cleanup checks and applicable earlier tests. Archive integrity
and path/syntax checks do not verify a compiler or its generated programs.

## Exact next action

This bounded consumer is complete. Agree the next bounded contract and independent
acceptance cases before further compiler or library expansion; no successor
implementation item is selected by this checklist. Preserve the qualified parser
and existing foundation gates. Literal conversion, semantic validity, conditional
selection/inactive-text behavior, deferred grammar and code generation remain
separate as already defined. Current commands and handoff are in
`PARSER-NATIVE-EVIDENCE.md`.
