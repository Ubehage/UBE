# UBE Compiler v3 staged development plan

UBE Compiler v3 is the first public-release compiler generation. Development
is divided into release previews so every milestone leaves a stable, preserved
compiler rather than one long unfinished rewrite.

Status markers: `[ ]` pending, `[~]` active, `[x]` verified, `[!]` blocked.

## How agents use this plan

Work from the first incomplete item in the active preview unless its recorded
dependency is blocked. Keep each change small enough to test independently.
When work changes a milestone, update this file and `../Progress.md` in the
same change.

For every completed item, record in `../Progress.md`:

- the behavior and authoritative specification implemented;
- files changed and important decisions;
- exact build and test commands with their results;
- new diagnostics and regression fixtures;
- failures, blockers, and the exact next action.

Do not mark a preview complete until its preview gate passes from a clean
output directory. A partial implementation remains `[~]`.

## Rules shared by every preview

Every preview must:

- remain buildable by the preserved Compiler v2 using only the frozen
  `../UBE_Compiler_v2/V3_BOOTSTRAP_CONTRACT.md` source subset;
- preserve the complete v1 and v2 verification paths;
- accept or reject every input through bounded, controlled diagnostics and
  never crash on malformed input or environmental failure;
- keep target-independent phases free of Windows assumptions;
- keep intermediate generated files under `../../bootstrap/out/`, not beside
  source, then preserve the final verified preview executable and hash under
  `../release-previews/` in the preview commit;
- record deterministic source, compiler, library, target, tool, flag, and
  artifact identities;
- add positive, negative, boundary, and recovery tests for completed behavior;
- explicitly close files, processes, pipes, locks, temporary artifacts, and
  other external resources on every exit path; and
- use only the separately built source-library modules recorded for that
  preview. Ordinary library algorithms must never be copied into the compiler.

Self-hosting is not required before v3 can implement the whole Bootstrap
Profile. Once a preview first compiles itself, self-compilation and comparison
become permanent gates for it and every later preview. V2 remains the trusted
bootstrap path even after that point.

Each preview has a source-library slice. It may initially contain no callable
APIs, but any API added for compiler use must have a frozen declaration, a
meaningfully named and documented UBE module under `../../source-library/`,
focused tests, and a recorded intrinsic/platform dependency. A preview cannot
silently use library facilities introduced by a later preview.

## Release Preview 0: frozen target and scaffold

Goal: prove the generation boundary before compiler implementation begins.

- [x] Create the v3 directory, project manifest, and `Main.bas` startup.
- [x] Freeze the UBE 1.0 core language definition and normative grammar.
- [x] Record the minimal-compiler, separate-library, linked-support, managed-
  memory, threading, foreign-ABI, and portability boundaries.
- [x] Build the scaffold with both preserved v2 stages and compare LLVM IR.
- [x] Link and execute the scaffold outside the source directory.
- [x] Record compiler, source, runtime, target, tool, flag, and artifact
  identities in the bootstrap manifest.
- [x] Establish executable conformance derivation as a required cross-preview
  activity, so each implemented normative rule gains coverage in its owning
  preview rather than being delayed until Beta 1.

Preview gate: complete and reverified on 2026-10-16. Both v2 stages emit
byte-identical `v3-rp0` LLVM IR, the linked executable prints the RP0 identity
and returns the expected scaffold status, and
`bootstrap/out/v3-rp0-build-manifest.json` records the reproducibility inputs
and artifacts. The full bootstrap suite remains the regression baseline.

## Release Preview 1: dependable compiler shell

Goal: replace the placeholder with a bounded multi-module driver that can load
and describe a build without yet parsing the complete language.

### RP1.1 — settle identities and compatibility metadata

- [x] Resolve the canonical core-library package identity recorded in
  `../../lang-doc/deferred-questions.md`.
- [x] Define compiler, language, intrinsic ABI, source-library, and artifact
  compatibility/version fields.
- [x] Decide the compiled-library compatibility rule and minimum metadata
  needed by later previews; the final bundle container may remain deferred.
- [x] Create the source-library `.UBE` manifest before adding its first source
  module, as required by `../../source-library/AGENTS.md`.

### RP1.2 — split the v2-buildable compiler source

- [x] Add ordered modules for diagnostics, bounded text/storage, source
  ownership, project loading, host/target description, and the driver.
- [x] Keep `Main.bas` limited to startup, argument handling, driver invocation,
  controlled reporting, and exit status.
- [x] Establish explicit result records so expected failures do not depend on
  panics, assertions, or partially initialized output.
- [x] Centralize limits for file size, source count, diagnostics, allocations,
  recursion, and generated text.

### RP1.3 — implement the project/source boundary

- [x] Load and validate `UBE-Project 1` manifests and ordered source paths.
- [x] Distinguish host and target configuration without assuming host equals
  target.
- [x] Canonicalize safe project-relative paths and reject duplicates, escapes,
  missing files, unsupported kinds, embedded NUL, and invalid UTF-8.
- [x] Give every source and diagnostic a stable identity and source range.
- [x] Produce no compiler output in RP1, so failed validation cannot leave a
  false-success or partial artifact. Atomic output begins with the first
  emitting preview.
- [x] Add malformed project, filesystem failure, limit, and cleanup tests.

RP1 gate: complete and verified on 2026-10-16. Both preserved v2 stages emit
byte-identical RP1 LLVM; the linked compiler validates its own nine-module
project, the two-module fixture, and the API-empty `UBECore` project; the
controlled failure corpus passes; and all v1/v2 tests remain green.

## Release Preview 2: lexical and preprocessing front end

Goal: turn all project source into a stable token stream with complete source
locations and recovery.

### RP2.1 — native and compatibility source envelopes

- [x] Validate native `UBE SOURCE 1` headers, source kind, extension, and
  `Attribute UBE_Name` identity.
- [x] Recognize legacy VB6 headers as compatibility input without emitting
  them for native UBE source.
- [x] Preserve comments, original spelling, line mapping, attributes, and
  designer text needed by diagnostics and future tools.

### RP2.2 — complete lexical contract

- [x] Implement every token and lexical boundary in `language-spec.md`.
- [x] Use the pinned Unicode letter and simple-fold tables.
- [x] Implement literals, suffixes, bracketed identifiers, comments,
  continuations, BOM handling, and invariant date/time text.
- [x] Distinguish hard and contextual keywords at the appropriate phase.
- [x] Recover after malformed tokens while preserving useful locations.

### RP2.3 — conditional compilation

- [x] Implement the separate conditional-compilation grammar before core
  parsing.
- [x] Preserve source mapping through inactive branches and continuations.
- [x] Add nesting, malformed directive, inactive-invalid-text, and limit tests.

RP2 gate: every lexical and preprocessing rule has positive, negative,
boundary, and recovery coverage; arbitrary bytes cannot crash or hang the
compiler; v2 reproducibly builds the preview and recorded library slice.

RP2 gate: complete and verified on 2026-10-16. Both preserved v2 stages emit
byte-identical RP2 LLVM. The linked compiler lexes its own 13-module project,
the inherited multi-module fixture, and `UBECore`; deterministic token dumps,
native and legacy envelopes, conditional selection and source mapping,
malformed recovery, BOM/line-ending boundaries, and deterministic fuzz inputs
all pass without uncontrolled termination. All v1/v2 tests remain green.

## Release Preview 3: complete parser and owned syntax model

Goal: parse the frozen grammar into bounded, owned syntax records without
assigning program meaning prematurely.

### RP3.1 — syntax representation

- [x] Define syntax node ownership, stable IDs, source ranges, list storage,
  and recursion/depth limits.
- [x] Keep syntax data independent of native pointers and target details.
- [x] Add a deterministic textual syntax dump for golden tests.

### RP3.2 — declarations and expressions

- [x] Parse modules, variables, constants, procedures, properties, events,
  types, enums, classes, interfaces, forms, controls, and foreign declarations.
- [x] Parse the full expression precedence ladder, calls, member/index access,
  `With` shorthand, `TypeOf`, object identity, and named/omitted arguments.
- [x] Parse attributes and designer metadata without treating them as runtime
  statements.

### RP3.3 — statements and recovery

- [x] Parse structured control flow, assignment, `Set`, `CallNew`, events,
  error handling, synchronization, file statements, and legacy forms.
- [x] Retain inline assembly and bytecode as validated opaque envelopes.
- [x] Recover at declaration and statement boundaries and report multiple
  useful diagnostics without cascading without bound.
- [x] Derive fixtures for every reachable EBNF production, ambiguity, invalid
  terminator, and recovery point.

RP3 gate: complete and verified on 2026-10-16. Every parser-owned core EBNF
production is exercised, with scanner-owned productions retained in the RP2
lexical corpus. Valid fixtures reproduce deterministic syntax dumps; malformed
and deeply nested input remains bounded; both preserved v2 stages emit
byte-identical RP3 LLVM; the API-empty `UBECore` slice parses successfully.

## Release Preview 4: symbols, types, and semantic core

Goal: fully analyze ordinary procedural programs before any backend operation.

### RP4.1 — declarations and lookup

- [x] Build package, module, member, procedure, block, and label scopes.
- [x] Implement Unicode-folded identity, visibility, direct references,
  qualification, ambiguity rules, and the no-user-overloading rule.
- [x] Validate module initialization order and exactly one executable entry
  point; support entry-free library analysis.

### RP4.2 — type system and conversions

- [x] Implement all scalar types, strings, enums, pointers, arrays, custom
  types, objects/interfaces, and `Variant`/`Empty`/`Null` type records.
- [x] Implement constant evaluation, checked arithmetic, operator typing, and
  the normative implicit-conversion matrix.
- [x] Validate fixed strings, array bounds/ranks, recursive custom types, and
  value versus object-reference assignment.

### RP4.3 — calls and control-flow contracts

- [x] Implement `ByRef`/`ByVal`, Optional, named and omitted arguments,
  `ParamArray`, property accessors, and evaluate-once rules.
- [x] Validate lvalues, exits, labels, loops, branches, result assignment,
  variable hooks, `Inline`/`ForceInline`, and intrinsic declarations.
- [x] Reject all unsupported or unsafe constructs before lowering.
- [x] Assign stable diagnostic identifiers and test wording, locations, notes,
  and recovery behavior.

RP4 gate: complete and verified on 2026-10-16. Every accepted expression has a
semantic type; bounded declaration, type, entry-point, label, `CallNew`, unsafe,
and control-flow checks run before any backend exists. Focused rejection tests
and deterministic semantic serialization pass. Both preserved v2 stages emit
byte-identical RP4 LLVM, RP4 analyzes its own 25-module source, and the
API-empty `UBECore` slice remains valid.

## Release Preview 5: verified IR, native core, and first self-build

Goal: compile the complete v2 Bootstrap Profile to deterministic native code
and establish v3 self-compilation as a permanent regression gate.

### RP5.1 — typed target-independent IR

- [ ] Define typed IR for values, storage, calls, control flow, cleanup,
  errors, source locations, and target-neutral managed references.
- [ ] Lower the complete Bootstrap Profile with explicit evaluation order,
  overflow behavior, `ByRef` identity, and failure edges.
- [ ] Add CFG, type, ownership, cleanup, and data-flow verification.
- [ ] Serialize IR deterministically for golden and bootstrap comparison.

### RP5.2 — LLVM and toolchain boundary

- [ ] Freeze the supported LLVM/Clang version and invocation contract.
- [ ] Implement target triples, data layouts, ABI classification, mangling,
  linkage, debug locations, and deterministic LLVM emission.
- [ ] Invoke assembler/linker tools through bounded argument and process APIs;
  capture failures without false-success artifacts.
- [ ] Link only the minimal startup, allocation, string, array, and error
  support required by the Bootstrap Profile.

### RP5.3 — self-build gate

- [ ] Make the v2-built v3 preview compile the identical v3 source and exact
  source-library slice.
- [ ] Make the self-built compiler repeat that build.
- [ ] Define and pass deterministic IR/object comparison policies, allowing
  only documented nondeterministic fields if unavoidable.
- [ ] Run the same positive and negative corpus through v2-built and self-built
  v3 binaries and require identical observable results.

RP5 gate: v2 builds v3; v3 builds itself and its library slice; the next-stage
compiler repeats the build; comparison and native Bootstrap Profile tests pass.
Self-hosting remains mandatory from this preview onward.

## Release Preview 6: managed values, objects, and automatic collection

Goal: implement the managed language model and the library facilities needed
to exercise it without expanding the compiler into a standard library.

### RP6.1 — managed representation

- [ ] Emit type-layout, root, stack-map, safe-point, and write-barrier metadata.
- [ ] Implement strings, arrays, recursive custom-type lazy storage,
  independent value copying, and object-reference identity.
- [ ] Implement `Variant`, `Empty`, `Null`, fixed strings, and all checked
  dynamic conversions.

### RP6.2 — object system and lifetime

- [ ] Implement classes, interfaces, `Implements`, `New`, `As New`, `Set`,
  `Nothing`, properties, module hooks, and initialization ordering.
- [ ] Implement strong references, exactly-once `Class_Terminate`, orderly
  shutdown, partial-initialization unwind, and opaque external leases.
- [ ] Implement library build output and the frozen exported foreign ABI
  subset needed to test external ownership.

### RP6.3 — collector and library slice

- [ ] Implement automatic tracing collection, cycle reclamation, controlled
  low-memory behavior, and synchronous `CollectGarbage() As Long`.
- [ ] Add documented source-library modules for conversions, strings, managed
  memory, variants, and errors as the compiler/tests require them.
- [ ] Stress roots, barriers, cycles, finalization, shutdown, ignored results,
  external leases, and repeated collection under concurrency-safe invariants.

RP6 gate: the self-hosting chain and exact library slice reproduce; managed
semantics pass leak, cycle, lifetime, low-memory, and ABI tests; no collector
path assumes responsibility for user-owned external resources.

## Release Preview 7: errors, threads, events, and component lifetime

Goal: implement UBE's complete concurrency and callback model with controlled
failure and cleanup.

### RP7.1 — runtime error model

- [ ] Implement thread-local `Err`, neutral failure values, `On Error`,
  `Resume`, and cleanup on every control-flow edge.
- [ ] Define controlled unrecoverable failure for resource exhaustion and
  recursion/stack limits without an uncontrolled process crash.

### RP7.2 — threads and synchronization

- [ ] Implement `CallNew`, non-recycled `LongLong` thread IDs, left-to-right
  argument snapshots, and shared object identity.
- [ ] Implement cooperative stop, wait, liveness, yield, safe program shutdown,
  and callback-event-source liveness.
- [ ] Implement `SyncLock`, sequentially consistent atomic wrappers,
  `ThreadEvent`, `Semaphore`, and FIFO `MessageQueue` in the proper compiler,
  linked-substrate, and source-library layers.
- [ ] Verify data-race memory safety, safe points, cancellation wakeups,
  reentrant locks, dead-object failures, and multiple waiters.

### RP7.3 — events, forms, and controls

- [ ] Implement `Event`, `RaiseEvent`, `WithEvents`, synchronous ordered and
  recursively reentrant dispatch, subscription changes, and signature checks.
- [ ] Resolve the default-form-after-unload question before implementing bare
  default-form recreation behavior.
- [ ] Implement startup forms, `Load`, cancellable `Unload`, drain-before-
  termination, alias clearing, native callback admission, and UI-thread
  dispatch without exposing an owner-thread restriction in UBE source.

RP7 gate: the self-hosting/compiler-library chain reproduces; threading,
events, unload, shutdown, cancellation, GC interaction, recursion limits, and
failure suites pass repeatedly and under stress.

## Release Preview 8: complete UBE 1.0 surface and portability boundary

Goal: close every remaining frozen language, project, ABI, and linked-library
requirement before hardening Beta 1.

### RP8.1 — projects, resources, and dependencies

- [ ] Implement complete `.UBE` executable/library projects and source-project
  references with deterministic dependency initialization and shutdown.
- [ ] Implement `.UBG` orchestration.
- [ ] Freeze and implement the bounded, hashed `.UBR` container.
- [ ] Freeze and implement the portable compiled-library bundle and dependency
  compatibility rules deferred from RP1.

### RP8.2 — remaining language and compatibility behavior

- [ ] Close every still-unimplemented production and semantic rule in the
  frozen UBE 1.0 specification.
- [ ] Implement foreign declarations, `AddressOf` thunks, variable hooks,
  inline/force-inline contracts, unsafe assembly/bytecode gates, and legacy
  file/error statements.
- [ ] Resolve deferred host-clock assignment and classic graphics syntax before
  claiming their compatibility status.
- [ ] Add optimization levels without changing observable semantics.
- [ ] Emit complete debugger metadata required by the future native IDE.

### RP8.3 — library and target completeness

- [ ] Complete the minimum public core-library API needed for all UBE 1.0
  language examples and compiler conformance programs.
- [ ] Keep portable modules separate from Windows adapters and document every
  API's failure, ownership, thread-safety, and platform contract.
- [ ] Add and verify at least one non-Windows target before claiming full
  portability; until then, describe portability as architectural rather than
  completed.

RP8 gate: every frozen UBE 1.0 syntax and semantic rule is implemented or has
an explicit documented unsupported diagnostic consistent with the release
contract; project, ABI, debugger, optimization, platform, self-hosting, and
library conformance suites pass.

## Beta 1: public-release hardening

Goal: turn the feature-complete final preview into the first public beta
without adding new language features.

### B1.1 — hostile input and environmental failure

- [ ] Fuzz manifests, resources, source bytes, preprocessing, lexer, parser,
  semantics, IR, library metadata, and backend boundaries; save every crash or
  hang as a regression test.
- [ ] Test low memory, full disk, permission denial, interrupted writes,
  missing/corrupt tools, excessive nesting, huge diagnostics, and cancellation.
- [ ] Prove non-test code contains no reachable panic/assert-only user-input
  or environment-failure path.

### B1.2 — reproducibility, performance, and support

- [ ] Establish compile-time, peak-memory, artifact-size, startup, GC, and
  generated-code performance baselines and regression thresholds.
- [ ] Run clean deterministic builds in continuous integration on every
  supported host/target combination.
- [ ] Publish the supported toolchain/host/target matrix, bootstrap trust
  record, stable diagnostics, exit codes, and troubleshooting guide.
- [ ] Complete contribution, bug-report, security, compatibility, and release
  processes before inviting general testing.

### B1.3 — final proof

- [ ] Build v1, v2, v3, and the exact source library from a clean offline
  checkout using documented commands.
- [ ] Pass the complete language, grammar, conversion, managed-memory,
  threading, event, project, ABI, platform, debugger, malformed-input, and
  environmental-failure suites.
- [ ] Produce the v2-built and self-built v3 artifacts and pass the release
  comparison policy.
- [ ] Audit public documentation against verified implementation status.
- [ ] Preserve release inputs, hashes, licenses, provenance, and artifacts.

Beta 1 gate: the frozen UBE 1.0 contract is implemented and verified by a
stable self-hosting compiler and separately built source library. Self-hosting
alone is necessary but not sufficient.

## Immediate next action

Begin RP5.1 by defining bounded typed target-independent IR records for values,
storage, calls, control flow, cleanup, errors, and source locations. Keep the
complete RP4 semantic corpus as the pre-lowering regression boundary.
