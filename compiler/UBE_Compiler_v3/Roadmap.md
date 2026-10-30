# UBE Compiler v3 workplan

This is the fresh compiler's prerequisite checklist, approved in direction by
the owner on 2026-10-30. It works with `../../std-lib/ROADMAP.md`.

- [x] Archive the previous v3/v4 implementations and distinguish historical
  artifacts from the fresh v3 identity.
- [x] Record the approved library-first, native-datatype and bounded-bootstrap
  direction without importing the old architecture or implementation.
- [ ] Define the primitive/type-mechanism ledger required by the first library
  slice: exact behaviors, ownership, safety, limits, failure and portability.
- [ ] Inspect the stage-zero/v2 tool/subset against that ledger; select exact
  inputs and run small independent positive/rejection/native fixtures.
- [ ] Specify and prove a minimal library-defined native datatype mechanism,
  obtaining decisions for any new syntax or observable semantics it requires.
- [ ] Implement and independently test the first UBECore byte/text foundation.
- [ ] Measure construction/copying/memory behavior and test independent-instance
  reentrancy, immutable sharing and bounded worker ownership early.
- [ ] Define the first genuine compiler consumer of those tested APIs, then
  create the minimal production manifest and source required by that consumer.

The 710-entry library inventory is target scope, not an instruction to implement
all families before the compiler begins. No new compiler phase architecture is
frozen by this checklist.

## Acceptance

An item requires its documented assertions/results to pass. Preserve focused
failure regressions, exact tool/input identities, actual work/copy/allocation
measurements, cleanup checks and applicable earlier tests. Archive integrity
and path/syntax checks do not verify a compiler or its generated programs.

## Exact next action

Write the first primitive/type-mechanism ledger alongside the UBECore foundation
contract. Use it to identify the smallest bootstrap features to test; do not
begin by building a full archived compiler or creating a production scaffold.
