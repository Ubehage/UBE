# UBE Compiler v4 progress

This is the short resumable handoff for the current or next v4 task. The
roadmap is `ROADMAP.md`; do not duplicate the complete backlog here.

## Current position

- Completed task: **Task 1 — reusable foundation and library split**.
- Next task: **Task 2 — scaffold and session shell**; ready.
- Status: the first-slice facility inventory, package boundary, intrinsic list,
  public declarations, deferrals, and native evidence are frozen. No v4
  production compiler source or manifest was created before the Task 1 exit
  gate.
- Bootstrap compiler: preserved v3 production compiler.
- Normative language: frozen UBE 1.0 definition and grammar.
- Blockers: none.

## Completed Task 0 execution packet

- Objective: close every remaining Task 0 decision with reproducible evidence
  and leave a frozen, implementable contract for Tasks 1 and 2.
- Prerequisites checked: all v4 planning documents; v3 `DESIGN.md`,
  `BOOTSTRAP_SPLIT.md`, `MULTITHREADED_COMPILER_PLAN.md`, and the Phase 5
  investigation; source-library instructions and design; the frozen core
  grammar; versioning and dependency policy.
- Files in scope: v4 planning documents plus a new Task 0 decision record,
  dependency-free manifest examples/schema, bounded prototype source, fixtures,
  runner, and generated evidence under `bootstrap/out/v4-task0/`.
- Files excluded: the production v4 manifest and source, v3 production source,
  bootstrap gates, normative language documents, and source-library APIs.
- Smallest reproduction: parse one native module containing a declaration,
  procedure, expression precedence, and a nested block; then mutate it into a
  truncated block and an excessive-nesting input.
- Expected artifacts: validated test-case manifests, a verified-build record
  example, two parser/syntax prototype modes, deterministic measurement output,
  an accepted syntax decision, rejected alternatives, and frozen Task 0
  contracts.
- Test inventory: valid minimal and representative syntax; malformed/truncated
  recovery; empty/minimum/depth-boundary inputs; deterministic generated scale
  series; injected output publication failure at the boundary the runner owns;
  repeated-run identity; exact span checks; and grammar-production coverage.
  Native code generation is not applicable because Task 0 does not build a
  compiler.
- Focused commands: the Task 0 runner validates manifests, builds the prototype
  with the checked-in bootstrap C++ toolchain contract, runs both modes over
  every fixture, compares semantic event/span results, and writes evidence only
  below `bootstrap/out/v4-task0/`.
- Cumulative inherited gates: grammar validation, Task 0 manifest/schema
  validation, deterministic rerun comparison, and targeted Markdown/link
  validation. Full compiler/self-host gates are not applicable because no
  production source or bootstrap integration changes.
- Measurements: input/source hash, bytes, tokens, nodes, nodes per token,
  syntax bytes, bytes per token, parser work, recovery count, maximum stack or
  explicit-frame depth, grammar coverage, wall/CPU time, and peak working set.
- Risks: a toy grammar could bias the result; wall time alone could reward an
  incomplete representation; PowerShell object overhead could obscure syntax
  costs; and prototype behavior could accidentally become production policy.
  The fixture mix, semantic parity checks, deterministic counters, compiled
  prototype, and explicit non-production boundary mitigate these risks.
- Result: every expected artifact was produced and the focused/cumulative Task
  0 gate passed. The accepted and rejected decisions are frozen in
  `TASK0_DECISIONS.md`.

## Completed Task 1 execution packet

- Objective: give Tasks 2/3 the smallest independently tested reusable
  boundary, with every other facility explicitly owned or deferred.
- Prerequisites checked: Task 0 decisions, source-library instructions,
  language/project/version rules, v3 intrinsic contracts, and safe project
  reference rules.
- Files in scope: `support/`, `task1/`, the Task 1 dependency manifests, and
  synchronized roadmap/progress/readme documentation. Production v4 compiler
  source and the v3 implementation remained out of scope.
- Smallest reproduction: compile the support library alone with v3, then link
  one bounded API fixture, one two-worker reentrancy fixture, and one
  file/process cleanup fixture.
- Expected artifacts: versioned support manifest/declarations, exact ownership
  and intrinsic inventory, deterministic LLVM, native fixtures, and generated
  evidence below `bootstrap/out/v4-task1/`.
- Tests: positive append/path/record behavior; byte-limit, parent-path, and bad
  record-key rejection; boundary measurements; two concurrent stateless path
  calls; Windows file publication/process execution/cleanup; repeated LLVM
  determinism; and independent UBECore compilation. Direct allocation fault
  injection is not applicable because this slice exposes no allocator; its
  allocation boundary is the tested byte limit. Unicode, hashes, collections,
  and a parallel executor are not implemented because Tasks 2/3 do not need
  them.
- Measurements: package versions, exact intrinsic counts, output SHA-256, and
  native exit/output status. Performance scaling begins with the Task 2 shell;
  these bounded helpers contain no input-wide nested traversal.
- Risks and decisions: cross-directory source references cannot escape a
  project root, so compiler support is a separate subproject within the v4
  generation. Shell-mediated process tests were rejected after exposing `cmd`
  reparsing; the final test invokes an executable with a separate argument.
- Result: `task1/run-task1.ps1` passed. V3 built UBECore and
  UBECompilerSupport independently, repeated support LLVM byte-identically,
  and passed all three native fixtures with no surviving published artifact.
  Thirteen existing support intrinsics and 54 preserved UBECore intrinsics are
  explicit; Task 1 added zero intrinsic names. The generated Task 1 evidence
  record SHA-256 is
  `44F73912A35A040B30CB1FFDFB3AB4E4481D04B64EC9792E5B7E36BD4FC5781D`.

## Approved direction

- Reuse v3 as bootstrap, differential oracle, format/ABI evidence, and corpus.
- Do not copy v3 modules wholesale or carry forward its whole-program arrays,
  global offset translation, or worker serialization.
- Put general-purpose facilities in UBECore or an approved compiler-support
  package before v4 depends on them.
- Use immutable source/global inputs, per-source syntax, per-procedure semantic
  outputs, function-local IR, and canonical coordinator merges.
- Use the measured selective hybrid parser/syntax representation, with
  immutable source bytes, compact per-source nodes, exact spans, numeric kinds,
  and generated grammar inventory/coverage checks.
- Keep `--jobs 1` as the permanent reference and enable parallel phases only
  after parity, speed, memory, failure, and cleanup gates pass.
- Treat every implementation increment as unverified until purpose-built small
  positive, rejection, boundary, stress, failure, regression, differential,
  native, and determinism cases plus all applicable earlier cases pass.

## Evidence carried forward

- V3 final measured self-host: 400.656 seconds, 922,352 KiB peak working set,
  299,684 tokens, and 1,249,321 syntax nodes.
- V3 fixed-point LLVM SHA-256:
  `C80FC435047E1B31BE8296EC54115BEE797022F8BE67B41ACEE46747F41D318C`.
- Phase 3/4 parallel transport was slower because workers rebuilt/copied large
  whole-project state; normal activation remains suspended.
- Indexed verifier/backend traversal and numeric grammar-rule identity proved
  that algorithmic structure, not self-hosting alone, caused major costs.

## Planning files

- `AGENTS.md`
- `README.md`
- `DESIGN.md`
- `TASK0_DECISIONS.md`
- `TASK1_DEPENDENCIES.md` and `TASK1_DEPENDENCIES.json`
- `REUSE_PLAN.md`
- `ROADMAP.md`
- `TASKS.md`
- `TESTING.md`
- `Progress.md`
- `task0/` non-production prototype, fixtures, formats, validator, and runner
- `task1/` reusable-foundation build and evidence runner
- `support/` independently buildable compiler-support package and fixtures

## Verification

- `task0/run-task0.ps1` passed with three repetitions for both modes. It
  validated positive and hostile manifests, compiled with C++17 warnings as
  errors, compared valid/malformed/depth/scaling fixtures, required stable
  counters/spans/meaning/diagnostics, matched v3 acceptance on three checked-in
  projects, and cleaned an injected pre-rename publication failure.
- The representative 97-token fixture measured 2,684 syntax bytes and 119
  nodes for the full table form versus 480 bytes and 40 nodes for the selected
  hybrid. The 30,025-token scale fixture measured 1,000,596 versus 240,060
  syntax bytes. Both modes stayed within the 1.20 work/token scaling bound.
- Depth 32 was accepted and depth 65 was rejected in a controlled way under
  the experimental 64-frame prototype limit. The malformed fixture produced
  the same two recovery diagnostics and locations in both modes.
- Generated evidence is under `bootstrap/out/v4-task0/`; the final measurement
  JSON SHA-256 for the final recorded run is `2627477CF98374F8531956E933A3681C035B11CDA97E33A3CA693A4B0CC3AF3E`
  and the verified-build record SHA-256 is
  `72F7022E8BB88F54C1DEC2DDBD068B09BF212477E1BB7BFA6DDDA4E94867ACBC`.
- Production compiler/self-host/native gates are not applicable: Task 0 changed
  no production compiler, bootstrap integration, language semantics, ABI,
  library API, or native code generation.

## Exact next action

Copy the Task 2 packet into this file, then create `UBE_Compiler_v4.UBE`,
`Main.bas`, immutable session/limit/diagnostic records, fake phase adapters,
and the cumulative runner against `TASK1_DEPENDENCIES.json`. Start with the
hostile-argument and atomic-publication shell; do not add real parsing or LLVM.
