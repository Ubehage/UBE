# UBE Compiler v4 roadmap

## Status and completion rules

Tasks 0 through 2 are complete; Task 3 is the next implementation gate. Status
markers are `[ ]` pending, `[~]` active, `[x]` verified, and `[!]`
blocked with the reason in `Progress.md`.

Tasks run in dependency order unless `Progress.md` records an approved isolated
prerequisite. A task is complete only when its implementation, controlled
failure paths, focused regression tests, differential evidence, performance
work counters, documentation, and task exit gate pass. Detailed execution
instructions are in `TASKS.md`. Every development build must also satisfy the
focused and cumulative verified-build policy in `TESTING.md`; successfully
building the compiler alone never completes a step.

## Phase A — approve the boundary before production code

### Task 0: architecture and reuse decision

- [x] Review and owner-approve `DESIGN.md`, `REUSE_PLAN.md`, this roadmap, and
  the task packets. Approved by the owner on 2026-10-27.
- [x] Resolve the syntax representation decision gate with bounded prototypes.
- [x] Freeze initial phase interfaces, ID rules, ownership, limits, diagnostic
  comparison policy, and library/compiler-support split.
- [x] Freeze the dependency-minimal test case manifest, cumulative runner
  contract, verified-build record, and the required positive, rejection,
  boundary, stress, failure, regression, differential, native, and determinism
  matrix from `TESTING.md`.
- [x] Record accepted decisions and explicitly rejected alternatives.

Task 0 completed on 2026-10-27. `TASK0_DECISIONS.md` freezes the measured
selective hybrid syntax representation and every remaining contract. The
offline `task0/run-task0.ps1` evidence gate validates the manifest formats,
compares both representations over valid/malformed/depth/scaling fixtures,
requires deterministic reruns and v3 acceptance parity, and proves atomic
publication cleanup. No production manifest or source was created.

Exit gate: the owner approves a written architecture; measured prototypes
support uncertain choices; no production scaffold predates the decision.

### Task 1: reusable foundation and library split

- [x] Inventory every non-language facility required by the first vertical
  slice and assign it to compiler, UBECore, compiler-support, or platform.
- [x] Implement only the minimal approved text, Unicode, collection, hashing,
  path/file, process, serialization, and executor facilities needed by the
  next task, each in its owning project with focused tests.
- [x] Freeze the v4 bootstrap/library/intrinsic dependency manifest.

Task 1 completed on 2026-10-27. `TASK1_DEPENDENCIES.md` and its JSON companion
freeze the exact first-slice inventory. The separately buildable
`UBECompilerSupport` 0.1.0-v4t1 package supplies only the Task 2 shell's
bounded text, path, record, environment, file, process, and measurement
contracts. Unicode, general collections/hashing, and parallel execution are
explicitly deferred because the first slice does not need them.

Exit gate: the first slice can depend on documented tested APIs without
copying general-purpose routines into the compiler or adding hidden intrinsics.

## Phase B — build one thin end-to-end compiler

### Task 2: v4 scaffold and session shell

- [x] Create `UBE_Compiler_v4.UBE`, `Main.bas`, generation-local tests, and
  output separation only after the complete Task 0 exit gate passes.
- [x] Implement bounded arguments, immutable configuration/limits, project and
  target identity, diagnostic aggregation, cancellation, cleanup, and atomic
  artifact publication interfaces.
- [x] Create the deterministic test runner and initial Task 2 focused/cumulative
  suite defined by `TESTING.md`.
- [x] Add v3-built smoke and hostile-argument gates.

Task 2 completed on 2026-10-27. The production manifest and native shell use
sealed `ByVal` session envelopes, the complete frozen limit set, stable
`UBE6000` diagnostics, cooperative cancellation, private releasable fake phase
results, and atomic shell-record publication. Thirteen checked case manifests
cover success, exact boundaries, hostile input, allocation/tool/write/cancel
faults, runtime file failure, cleanup, native execution, and deterministic
repetition. The cumulative Task 0/1/2 and grammar gates pass.

Exit gate: v3 builds the shell; the shell accepts or rejects a minimal project
without a crash, leaked external resource, or false-success artifact.

### Task 3: minimal vertical slice

- [ ] Compile one tiny `Sub Main` program through source snapshot, tokens,
  compact syntax, frozen declaration, typed body, verified local IR, LLVM,
  link, and native execution.
- [ ] Keep each phase in a separate module with serialized debug snapshots.
- [ ] Compare v3/v4 acceptance, diagnostics, output, exit status, and native
  behavior for the slice and its malformed variants.

Exit gate: the architecture works end to end before language breadth grows;
no phase queries another phase's private mutable state.

## Phase C — complete the front end and semantic core

### Task 4: projects, sources, preprocessing, and lexer

- [ ] Implement frozen project/source envelopes and preprocessing with sources
  loaded once into immutable snapshots.
- [ ] Complete UBE 1.0 lexing with per-source tokens and stable spans.
- [ ] Differentially cover arbitrary bytes, Unicode, continuations, legacy
  envelopes, limits, path failures, and deterministic diagnostic recovery.

Exit gate: the full lexical corpus matches the approved v3 contract and scales
approximately linearly by bytes/tokens without cross-source arena copying.

### Task 5: compact parser and recovery

- [ ] Implement the Task 0-selected parser and compact per-source syntax.
- [ ] Cover every normative production and frozen compatibility form.
- [ ] Bound nesting, recovery attempts, diagnostics, nodes, and memory; retain
  exact source spans and prove forward progress on malformed input.

Exit gate: grammar-wide valid/invalid coverage passes; normalized syntax and
recovery match the approved oracle policy; representation budgets pass.

### Task 6: declarations, names, and types

- [ ] Collect declarations in canonical source order and freeze indexed scopes,
  folded names, type identities, layouts, signatures, and project references.
- [ ] Keep declaration mutation in one owner; publish immutable lookup views.
- [ ] Implement conversions, constants, layout, duplicate/unknown-name, entry
  point, and dependency validation with deterministic diagnostics.

Exit gate: the frozen universe is deterministic under hash collisions and
input permutations where semantics allow; semantic decision snapshots match
v3 for the selected corpus.

### Task 7: function-local semantic analysis

- [ ] Analyze each procedure into private binding, typed-expression,
  control-flow, effect, lifetime, and diagnostic arenas.
- [ ] Cover calls, `ByRef`/`ByVal`, arrays, custom/managed values, objects,
  properties, errors, threads, events, forms, unsafe constructs, and all
  remaining frozen semantics.
- [ ] Run whole-program checks through explicit summaries rather than walking
  every body repeatedly.

Exit gate: complete semantic differential coverage passes; lookup/traversal
work counters remain bounded by relevant declarations and body records.

## Phase D — verified native compilation

### Task 8: function-local IR and verification

- [ ] Define and implement typed local IR for values, storage, calls, control
  flow, failure, cleanup, managed roots/barriers, concurrency, and locations.
- [ ] Verify local CFG/type/ownership invariants before merge and program-link
  invariants through compact summaries.
- [ ] Add one minimal synthetic rejection for every verifier invariant.

Exit gate: accepted semantic bodies lower deterministically; invalid IR never
reaches a backend; edge/instruction work counters remain linear.

### Task 9: target, LLVM, debug, ABI, and native tool boundary

- [ ] Reimplement target descriptions, data layout, mangling, ABI
  classification, LLVM fragments, debug metadata, and linked support from the
  frozen contracts.
- [ ] Emit function fragments independently and assemble them in canonical
  order; publish only validated complete artifacts.
- [ ] Cover Windows x86-64 native execution and the verified Linux x86-64 ELF
  boundary before broader target claims.

Exit gate: LLVM validation, ABI/native probes, debugger metadata, failure
cleanup, and v3/v4 observable parity pass; backend visits are linear in emitted
records.

### Task 10: projects, libraries, resources, and complete runtime behavior

- [ ] Complete `.UBE`, `.UBG`, `.UBR`, `.UBL`, project references, foreign
  ABI, initialization/shutdown, optimization modes, and exact library slices.
- [ ] Complete managed memory, errors, threading, synchronization, events,
  components, forms/controls, and platform-linked behavior through the proper
  compiler/library/runtime layers.
- [ ] Reuse all RP6–RP8 native and corruption gates.

Exit gate: the complete frozen UBE 1.0 corpus and package/runtime gates match
the approved v3 contract on supported targets.

## Phase E — concurrency, bootstrap, and release hardening

### Task 11: deterministic parallel execution

- [ ] Add the bounded executor first with one-job behavior and failure
  injection.
- [ ] Enable source, procedure semantic, local IR, verifier, and backend
  fragment tasks one phase at a time using immutable inputs/private outputs.
- [ ] Require byte-identical artifacts/diagnostics across job counts plus a
  measured speedup and accepted peak-memory budget before enabling each phase.

Exit gate: `--jobs 1`, `2`, and representative maximum counts pass repeated
randomized scheduling, failure, cleanup, parity, memory, and scaling gates.

### Task 12: self-hosting and fixed point

- [ ] Make preserved v3 build v4 stage one from a clean offline checkout.
- [ ] Make v4 stages one and two build the same v4 source and exact library
  slice, then require the approved stage-two/stage-three fixed point.
- [ ] Record source, grammar, library, intrinsic, compiler, runtime, toolchain,
  host, target, flags, artifacts, and hashes in the trust manifest.

Exit gate: no pre-existing v4 binary is required; compiler and library outputs
reproduce; all previous generations remain buildable and verified.

### Task 13: hostile-input, environmental, performance, and release gate

- [ ] Fuzz every boundary and save every crash/hang as a regression.
- [ ] Test low memory, full disk, permissions, interruption, corrupt tools,
  deep nesting, oversized records/diagnostics, cancellation, and shutdown.
- [ ] Establish compiler self-build, UBECore, many-source, many-procedure,
  artifact-size, startup, generated-code, and peak-memory thresholds.
- [ ] Audit docs, diagnostics, exit codes, supported matrices, dependencies,
  licenses, provenance, and offline release instructions.

Exit gate: v4 satisfies the complete Beta gate without an uncontrolled crash,
false-success artifact, unexplained nondeterminism, or unbounded regression.

## Release rule

V4 does not replace v3 merely by self-hosting. It becomes authoritative only
after the complete language/library/runtime/package corpus, deterministic
fixed point, hostile-environment suite, and agreed performance/memory budgets
pass. V3 remains preserved afterward as part of the trust history.
