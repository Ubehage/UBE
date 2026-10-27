# UBE workplan

This is the repository-wide resumable checklist for active goals and handoffs.
Owner-defined release requirements live in `Release-Requirements.md`; long-term
sequencing lives in `project-docs/Roadmap.md`; module-specific work may use a
nearer roadmap or progress file.

## Status markers

- `[ ]` not started
- `[~]` in progress
- `[x]` complete and verified
- `[!]` blocked, with the reason and required decision recorded

## Current checkpoint

- [x] Preserve and verify the self-hosting UBE Compiler v2.
- [x] Add ordered multi-module compilation and cross-module resolution to v2.
- [x] Reorganize documentation into public, normative-language, and project
  documentation areas.
- [x] Complete and statically verify the public documentation snapshot for the
  frozen UBE 1.0 definition, with specified behavior separated from verified
  Compiler v2 behavior and unresolved public APIs represented by status pages.
- [x] Define and freeze the UBE 1.0 language contract for Compiler v3.
- [x] Create `compiler/UBE_Compiler_v3/` with its architecture, roadmap, and
  v2-buildable project scaffold.
- [x] Establish `source-library/` as the separate root for UBE library source,
  with preview, portability, ownership, and resumable-work boundaries.
- [~] Develop and compile v3 using the preserved v2 compiler.
  - [x] Preserve the explicit RP0 scaffold baseline.
  - [x] Complete RP1: bounded multi-module compiler shell, project/source
    validation, host/target descriptions, compatibility identities, and the
    API-empty `UBECore` project boundary.
  - [x] Complete RP2: native and compatibility source envelopes, frozen UBE
    1.0 tokenization, conditional compilation, stable source mapping,
    deterministic token output, bounded recovery, and malformed-input tests.
  - [x] Complete RP3: embedded frozen grammar, complete bounded parser, owned
    syntax records, deterministic syntax output, recovery, and grammar-wide
    coverage.
  - [x] Complete RP4: bounded scopes and Unicode-folded symbols, semantic type
    and expression records, entry-point and declaration validation, stable
    semantic diagnostics, deterministic semantic output, and focused rejection
    tests.
  - [x] Complete RP5: verified typed IR, native LLVM output, compiler-owned
    toolchain handoff, and deterministic self-compilation.
  - [x] Complete RP6: managed values, objects/interfaces, tracing collection,
    project references, callable `UBECore`, and the foreign ownership ABI.
  - [x] Complete RP7: structured errors, threads and synchronization, events,
    forms/controls, and component lifetime with deterministic failure gates.
  - [x] Complete RP8 with project-group orchestration, bounded hashed resource
    and library bundles, explicit remaining-language compatibility diagnostics,
    optimization/debug controls, the minimum public `UBECore` API, and a
    verified Linux x86-64 ELF object boundary.
  - [ ] After the RP8 gate, execute the Beta 1 compiler parallelization plan in
    `compiler/UBE_Compiler_v3/MULTITHREADED_COMPILER_PLAN.md`: preserve the
    v2-built sequential seed, add deterministic `--jobs` execution in measured
    phases, keep one job as the default, and require explicit caller-selected
    parallelism after reproducibility, failure, memory, and performance gates
    pass.
    - [x] Phase 0: add opt-in sequential compiler profiling, publish repeatable
      self/UBECore/source/procedure baselines, and remove the measured
      superlinear semantic and IR lookup paths.
    - [x] Phase 1: freeze and prove the sequential seed/production bootstrap
      split and record seed/executor identities.
    - [x] Phase 2: implement the bounded executor API with one-job behavior,
      deterministic failure injection, cancellation, drain, and cleanup gates.
    - [x] Phase 3: run independent source preprocessing, lexing, and parsing in
      a bounded worker pump with manifest-order deterministic merge.
    - [x] Phase 4: freeze declarations and types, analyze independent procedure
      bodies with private worker state, and merge semantic results canonically.
    - [~] Phase 5: the v3 audit removed quadratic whole-edge IR verification,
      per-function whole-program LLVM scans, and repeated folded grammar-rule
      dispatch, reducing the verified self-host from 800.7 to 400.7 seconds.
      V3 is now retained as the reference/bootstrap bridge for the planned v4
      design; do not extend its whole-project worker transport architecture.
- [~] Define Compiler v4 as a clean architectural generation while preserving
  v3 as its bootstrap compiler and differential oracle.
  - [x] Draft the v4 ownership model, reuse/retire classification, ordered
    milestone roadmap, and task-specific agent instructions under
    `compiler/UBE_Compiler_v4/`.
  - [x] Obtain owner approval for the Task 0 architecture, parser decision
    process, library/compiler-support split, and task ordering.
  - [x] Run the approved bounded design prototypes and freeze phase interfaces
    before creating the v4 manifest or production source scaffold.
  - [x] Freeze and enforce the v4 verified-build policy: every roadmap step and
    claimed working build needs small purpose-built success, rejection,
    boundary, stress, failure, regression, differential, native, and
    determinism programs plus every applicable earlier test.
  - [x] Implement the Task 1 reusable foundation and exact dependency manifest
    before creating the Task 2 production scaffold.
  - [x] Build the Task 2 production session shell on the frozen Task 1 support
    boundary and permanent sequential reference path.
  - [ ] Implement the Task 3 minimal genuine vertical slice through every
    compiler phase before adding broader language coverage.

## Handoff protocol

For active work, record:

- the exact objective and authoritative specification;
- current status and completed checklist items;
- decisions and assumptions;
- files changed;
- verification commands and results;
- remaining failures or blockers;
- the exact next action.

Update this file when repository-wide work changes state. Do not duplicate a
detailed module checklist here; link to the module's roadmap or progress file.
