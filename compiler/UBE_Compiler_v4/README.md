# UBE Compiler v4

UBE Compiler v4 is the planned clean compiler generation that follows the
preserved v3 implementation. V3 remains the executable UBE 1.0, diagnostic,
ABI, package, and bootstrap oracle. V4 will be written in UBE and built first
by v3, but its internal architecture will not be copied from v3.

The directory contains the frozen planning documents, the bounded
non-production Task 0 prototype/evidence harness, and the independently
buildable `support/UBECompilerSupport.UBE` package completed by Task 1. No v4
production compiler source or manifest exists yet. Creating the required
`UBE_Compiler_v4.UBE` manifest and `Main.bas` startup module is part of the
Task 2 scaffold gate.

Read in this order:

1. [`AGENTS.md`](AGENTS.md) — mandatory local instructions.
2. [`DESIGN.md`](DESIGN.md) — frozen phase, ownership, and determinism
   contracts.
3. [`TASK0_DECISIONS.md`](TASK0_DECISIONS.md) — measured syntax choice, phase
   APIs, IDs, limits, diagnostics, test formats, and rejected alternatives.
4. [`REUSE_PLAN.md`](REUSE_PLAN.md) — what v3 contributes and how it may be
   used.
5. [`TASK1_DEPENDENCIES.md`](TASK1_DEPENDENCIES.md) — frozen first-slice
   ownership, package, intrinsic, and deferral decisions.
6. [`ROADMAP.md`](ROADMAP.md) — milestones, dependencies, and exit gates.
7. [`TESTING.md`](TESTING.md) — mandatory focused and cumulative proof for
   every development build.
8. [`TASKS.md`](TASKS.md) — bounded briefs for the agent executing each task.
9. [`Progress.md`](Progress.md) — the single active resumable handoff.

Authoritative external inputs remain:

- `../../lang-doc/v3-language-definition.md` and the normative grammar;
- `../../project-docs/architecture.md` and versioning contracts;
- `../UBE_Compiler_v3/` and its preserved release artifact as differential
  behavior, not source architecture; and
- `../../source-library/` for reusable UBE facilities outside the compiler
  boundary.
