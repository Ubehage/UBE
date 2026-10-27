# UBE Compiler v4

UBE Compiler v4 is the clean compiler generation that follows the
preserved v3 implementation. V3 remains the executable UBE 1.0, diagnostic,
ABI, package, and bootstrap oracle. V4 will be written in UBE and built first
by v3, but its internal architecture will not be copied from v3.

Tasks 0 through 4 are complete. The directory contains the frozen architecture
and dependency decisions, the Task 0 prototype evidence, the independently
buildable `support/UBECompilerSupport.UBE` package, and the first production
`UBE_Compiler_v4.UBE`/`Main.bas` shell. The shell proves bounded startup,
immutable session ownership, diagnostics, cancellation, failure propagation,
cleanup, and atomic record publication. It deliberately has no real parser,
semantic pipeline, IR, or backend. Task 3 adds the first genuine vertical
slice through separate source, lexer, syntax, declaration, semantic, verified
function-local IR, and LLVM backend modules. Task 4 adds load-once immutable
project sources, explicit preprocessing/source mapping, complete per-source
lexical tokens with stable byte spans, and deterministic v3 differential gates.

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

Run the complete current v4 evidence gates with:

```powershell
powershell -ExecutionPolicy Bypass -File task0/run-task0.ps1
powershell -ExecutionPolicy Bypass -File task1/run-task1.ps1
powershell -ExecutionPolicy Bypass -File task2/run-task2.ps1
powershell -ExecutionPolicy Bypass -File task3/run-task3.ps1
powershell -ExecutionPolicy Bypass -File task4/run-task4.ps1
```

Authoritative external inputs remain:

- `../../lang-doc/v3-language-definition.md` and the normative grammar;
- `../../project-docs/architecture.md` and versioning contracts;
- `../UBE_Compiler_v3/` and its preserved release artifact as differential
  behavior, not source architecture; and
- `../../source-library/` for reusable UBE facilities outside the compiler
  boundary.
