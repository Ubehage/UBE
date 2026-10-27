# UBE Compiler v4 progress

This is the short resumable handoff for the current or next v4 task. The
roadmap is `ROADMAP.md`; do not duplicate the complete backlog here.

## Current position

- Completed task: **Task 3 — minimal vertical slice**.

- Previous task: **Task 2 — scaffold and session shell**.
- Next task: **Task 4 — projects, sources, preprocessing, and lexer**; ready.
- Status: Tasks 0 through 3 are verified. The production compiler preserves the
  Task 2 shell and compiles one bounded genuine `Sub Main` through seven
  validated phase envelopes to deterministic LLVM and v3-equivalent native
  behavior. Broader language coverage and parallel execution are not claimed.
- Bootstrap compiler: preserved v3 production compiler.
- Normative language: frozen UBE 1.0 definition and grammar.
- Blockers: none.

## Completed Task 3 execution packet

- Objective: prove the frozen architecture end to end before adding breadth.
- Prerequisites checked: Tasks 0–2, phase/ownership contracts, support boundary,
  minimal grammar fixture, v3 oracle, LLVM, and bootstrap runtimes.
- Scope: production phase modules, bounded support text views, Task 3 fixtures,
  runner/evidence, and synchronized status documentation.
- Smallest reproduction: one 17-token `Public Sub Main()` printing `task3-ok`;
  malformed token, truncated syntax, and wrong-startup variants.
- Test inventory: positive/native/v3 differential, deterministic LLVM and all
  seven phase dumps, three rejections, seven envelope mutations, 100,000-byte
  stress, post-fault ownership isolation, and artifact cleanup.
- Result: `task3/run-task3.ps1` passed. The 104-byte source produced 17 tokens,
  four syntax nodes, one declaration, one typed statement, three IR
  instructions, 736 LLVM bytes, and a 147,456-byte native executable. LLVM
  SHA-256 is `53C84191CF3B60B6A6198DF3E808ABB328C492774893C8A683D5E657E03FE747`;
  dump SHA-256 is
  `15411BBEFE824A2BA7AF90AD37197C31ACC5DF791C3A55B9ADB4AF5C80FF3ED2`.
  No false-success artifact or live resource remained.

## Completed Task 2 execution packet

- Objective: create a v3-built production v4 shell that owns immutable
  configuration/session/limit records, bounded deterministic diagnostics, a
  cooperative cancellation token, explicit phase-result cleanup, fake phase
  failure propagation, and atomic shell-record publication.
- Prerequisites checked: Task 0 phase/limit/diagnostic/test contracts; Task 1
  dependency manifest and support declarations; v3 CLI and diagnostic tests;
  project naming, source header, output separation, and bootstrap rules.
- Files in scope: `UBE_Compiler_v4.UBE`, `Main.bas`, focused `src/` modules,
  `tests/task02-shell/`, `task2/run-task2.ps1`, and synchronized v4/compiler/root
  documentation. V3, UBECore, the frozen Task 1 support API, bootstrap build
  integration, and normative language files are excluded.
- Smallest reproduction: v3 builds the shell; the native shell accepts one
  nonempty project control file and a supported target, runs load/frontend/tool
  fake adapters sequentially, and optionally publishes one deterministic
  bounded record.
- Expected artifacts: production manifest/startup, immutable session and limit
  envelope, stable `UBE6000`-series diagnostics, cancellation token, releasable
  fake phase results, generated native shell/LLVM, deterministic record, and a
  Task 2 verified-build record only below `bootstrap/out/v4-task2/`.
- New tests: valid check and record publication; argument-count, empty target,
  unsupported target, empty/corrupt project, and over-limit arguments;
  injected phase-allocation, tool, write, and cancellation failures; real
  missing-input and host cleanup failures; pre-existing-output removal;
  repeated invocation/deterministic output; native exit/output checks; and
  cleanup/no-false-artifact assertions. Parallel interaction is not applicable
  because the frozen reference shell is deliberately one job; its concurrency
  evidence remains the inherited Task 1 two-worker reentrancy test.
- Focused command: `task2/run-task2.ps1`; it builds through preserved v3 and
  Clang, executes each case with separate arguments, verifies exact status and
  diagnostics, hashes outputs, runs repeated invocations, and publishes
  evidence only after every case passes.
- Cumulative gates: Task 0 parser/manifest evidence, Task 1 support/native/
  thread/cleanup evidence, grammar validation, JSON validation, and diff
  hygiene.
- Measurements: input and output hashes, case count, phase work units, shell
  LLVM/native sizes, elapsed/CPU/peak-memory samples, host/target/tool identity,
  artifact presence, and cleanup status.
- Risks: bootstrap file intrinsics own missing/unwritable-file diagnostics and
  exit codes; tests must distinguish those controlled platform failures from
  v4 diagnostics. Fake phases must remain obvious scaffolding and must not
  smuggle Task 3 parsing/backend behavior into Task 2.
- Decisions and rejected alternatives: all phase inputs are `ByVal` immutable
  envelopes; mutable cancellation has one coordinator owner; fake results are
  released on every path. Real parsing/LLVM, worker creation, shared phase
  arrays, shell command construction, and publish-in-place output were
  rejected. A missing-parent write was removed as a negative test after proving
  that the atomic writer correctly creates that directory; an existing
  directory now exercises real host cleanup rejection instead.
- Result: all 13 manifests and 15 native executions passed. Repeated v3 shell
  LLVM and three published records were byte-identical. Their deterministic
  hashes are LLVM
  `05EE253CE4DDAC3710CD6EA8359E1F5C5DD945113A68C88BEF02AAA05D201B15`,
  and shell record
  `CDCCFCD079746687533566041F24601EE6FDEA16995F8956A83D958B83A02EBC`.
  The recorded run produced 1,259,750 LLVM bytes and a 193,024-byte native
  executable. The native hash is retained in each generated evidence record,
  but reproducible final linker containers are not claimed before Task 9/12. The
  run recorded three phase work units, zero live resources, and zero
  false-success artifacts. The host process API reported peak working set as
  unavailable (`0`), so no memory claim is inferred from that field.

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
- `task2/` production shell build, native-case, and evidence runner
- `src/`, `Main.bas`, and `UBE_Compiler_v4.UBE` production Task 2 shell
- `tests/task02-shell/` checked manifests and minimal project fixtures
- `support/` independently buildable compiler-support package and fixtures

## Verification

- `task2/run-task2.ps1` passed 13 validated manifests in 15 native executions.
  V3 emitted identical shell LLVM twice and built the native executable. Exact
  success, usage, target, empty/missing input, 4096/4097-byte argument,
  allocation, tool, cancellation, publication, stale-output, and host cleanup
  results matched their manifests. Three publication runs produced identical
  bytes, and every failure left zero false-success files and live resources.
- The final cumulative run passed `task0/run-task0.ps1`,
  `task1/run-task1.ps1`, `task2/run-task2.ps1`, and grammar validation for 202
  core plus 19 conditional productions. `git diff --check` also passed.

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
- Generated evidence is under `bootstrap/out/v4-task0/`. Whole evidence-file
  hashes are run-specific because timing measurements are included; stable
  input, span, semantic, and artifact hashes are stored inside each record.
- Production compiler/self-host/native gates are not applicable: Task 0 changed
  no production compiler, bootstrap integration, language semantics, ABI,
  library API, or native code generation.

## Exact next action

Task 3 is complete. Copy the Task 4 packet into this file and expand project
and source loading, preprocessing, and lexical coverage from these envelopes.
Begin with the smallest differential fixture and preserve every Task 0–3 gate.
