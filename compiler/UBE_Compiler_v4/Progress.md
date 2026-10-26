# UBE Compiler v4 progress

This is the short resumable handoff for the one active v4 task. The roadmap is
`ROADMAP.md`; do not duplicate the complete backlog here.

## Current position

- Active task: **Task 0 — architecture and reuse decision**.
- Status: the owner approved the proposed architecture, reuse policy, task
  ordering, ownership model, library/compiler-support split, determinism rules,
  performance rules, bootstrap chain, and Task 0 exit gate on 2026-10-27.
  Task 0 now proceeds to bounded prototypes and measured decisions. No v4
  production source, manifest, or build integration has been created.
- Bootstrap compiler: preserved v3 production compiler.
- Normative language: frozen UBE 1.0 definition and grammar.
- Blockers: none for Task 0 prototype work. Production implementation remains
  gated on completion of the full Task 0 exit gate.

## Approved direction

- Reuse v3 as bootstrap, differential oracle, format/ABI evidence, and corpus.
- Do not copy v3 modules wholesale or carry forward its whole-program arrays,
  global offset translation, or worker serialization.
- Put general-purpose facilities in UBECore or an approved compiler-support
  package before v4 depends on them.
- Use immutable source/global inputs, per-source syntax, per-procedure semantic
  outputs, function-local IR, and canonical coordinator merges.
- Choose the parser/syntax representation only after measured prototypes.
- Keep `--jobs 1` as the permanent reference and enable parallel phases only
  after parity, speed, memory, failure, and cleanup gates pass.

## Evidence carried forward

- V3 final measured self-host: 400.656 seconds, 922,352 KiB peak working set,
  299,684 tokens, and 1,249,321 syntax nodes.
- V3 fixed-point LLVM SHA-256:
  `C80FC435047E1B31BE8296EC54115BEE797022F8BE67B41ACEE46747F41D318C`.
- Phase 3/4 parallel transport was slower because workers rebuilt/copied large
  whole-project state; normal activation remains suspended.
- Indexed verifier/backend traversal and numeric grammar-rule identity proved
  that algorithmic structure, not self-hosting alone, caused major costs.

## Files created for the draft

- `AGENTS.md`
- `README.md`
- `DESIGN.md`
- `REUSE_PLAN.md`
- `ROADMAP.md`
- `TASKS.md`
- `Progress.md`

## Verification

- All linked local planning/specification paths exist.
- Task packets are continuous from Task 0 through Task 13 and match the roadmap.
- Targeted `git diff --check` passed for the updated compiler/workplan records;
  the new v4 Markdown files contain no trailing whitespace.
- Production/compiler tests: not applicable; no production code changed for
  this planning task.

## Exact next action

Define the representative parser-prototype fixture set and measurement format,
then implement the two bounded syntax approaches outside the production
manifest. Record nodes and bytes per token, parser work, peak memory, recovery,
span fidelity, grammar coverage, and maintenance tradeoffs before selecting a
representation. Do not create `UBE_Compiler_v4.UBE` or `Main.bas` yet.
