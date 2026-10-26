# UBE Compiler v4 agent instructions

This directory defines and, after owner approval, implements the v4 compiler
generation. These instructions supplement `../AGENTS.md`. Read `README.md`,
`DESIGN.md`, `REUSE_PLAN.md`, `ROADMAP.md`, and `Progress.md` before changing
anything in this directory.

## Current authorization boundary

V4 is in architecture planning. Documentation, focused measurements, and
throwaway prototypes outside the production manifest are allowed. Do not add
production compiler source, create `UBE_Compiler_v4.UBE`, or change the v3
bootstrap/build gate until the measured Task 0 exit gate in `ROADMAP.md` is
complete. The owner approved the Task 0 direction on 2026-10-27; that approval
authorizes the bounded prototype work, not production scaffolding.

## Non-negotiable rules

- Preserve v1, v2, v3, their release previews, and their verification paths.
- V3 is the bootstrap compiler and differential oracle for v4. It is not a
  source-code template.
- Never copy a v3 module wholesale. Reuse requires a recorded decision in
  `REUSE_PLAN.md`, a smaller v4-owned interface, and focused parity tests.
- Compiler-only behavior stays in the compiler. General text, collection,
  hashing, path, file, process, synchronization, and serialization facilities
  belong in the source library or a separately approved compiler-support
  package. Never hide ordinary library code behind a new intrinsic.
- Follow `../../source-library/AGENTS.md` and
  `../../source-library/agent-rules.md` for every source-library change. A v4
  task does not grant permission to weaken the public library boundary.
- Host and target are independent. Portable phases must not depend on Windows,
  LLVM process details, native path syntax, or platform handles.
- All non-test paths return controlled errors. Every crash, hang, unchecked
  index, resource leak, or false-success artifact requires a focused synthetic
  regression that failed before the correction.
- Inputs shared across workers are immutable. Mutable state has exactly one
  owner. Worker outputs are private until a deterministic coordinator merge.
- Stable IDs and emitted order come from source/declaration/function identity,
  never allocation address, hash iteration, thread assignment, or completion
  order.
- Do not optimize by adding workers to an unmeasured algorithm. First record a
  work counter or scaling fixture that can distinguish linear from repeated
  whole-program work.
- Keep external resources under explicit lifetime management. Garbage
  collection does not close files, processes, pipes, locks, temporary files,
  or tool handles.
- Generated files belong under `bootstrap/out/` or another documented output
  directory, never beside v4 source.

## How to execute a roadmap task

1. Read the task packet in `TASKS.md` and the current handoff in `Progress.md`.
2. Confirm every prerequisite and list the exact files in scope before editing.
3. Reproduce the smallest relevant v3 behavior or failure before porting it.
4. Implement only the named deliverables. A new cross-phase dependency or
   fundamental design change requires owner approval and a recorded decision.
5. Run the task's focused tests first, then its differential and inherited
   gates. Never use a full self-build as the first diagnostic.
6. Record measurements using input hashes, record counts, work counters, wall
   time, CPU time, peak memory, artifact size, host, target, and tool versions.
7. Update `Progress.md` during the task and `ROADMAP.md`, `REUSE_PLAN.md`, and
   affected public/library documentation when the result changes them.
8. Mark a task complete only when code, controlled failures, regression tests,
   documentation, cleanup, and the stated exit gate all pass.

## Review stop conditions

Stop and request direction instead of guessing when a change would:

- alter frozen UBE 1.0 semantics, diagnostics, ABI, package formats, or public
  library behavior;
- add a dependency or intrinsic;
- place general-purpose behavior inside the compiler;
- make a phase depend on another phase's mutable representation;
- change deterministic ordering or the bootstrap comparison policy; or
- require broad changes to v3 rather than a narrow bootstrap-gate correction.
