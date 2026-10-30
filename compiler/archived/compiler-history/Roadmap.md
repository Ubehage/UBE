# UBE compiler roadmap

This roadmap is the resumable implementation plan for the UBE-written
compiler. It complements the repository-wide roadmap in
`project-docs/Roadmap.md` and the implemented-subset ledger in
`lang-doc/bootstrap-profile.md`.

## How agents use this file

The owner's 2026-10-30 library-first decision supersedes the immediate execution
order below. Further compiler feature expansion is deferred; the active work
is `../std-lib/ROADMAP.md`. Existing compiler plans remain preserved.

Status markers:

- `[ ]` not started
- `[~]` in progress
- `[x]` complete and verified
- `[!]` blocked; explain the blocker in `Progress.md`

Work from top to bottom unless a later item is an isolated prerequisite. An
item is complete only when implementation, controlled diagnostics, regression
tests, and affected documentation are complete. Non-test compiler and runtime
code must never panic or terminate through an uncontrolled failure path.

## Version boundary agreed for v2 and v3

`UBE_Compiler_v2` is the preserved transitional compiler generation. It is
ready when it retains the existing stage-two self-hosting proof, safely loads
ordered multi-source `.UBE` projects, resolves supported declarations and
references across those modules, and provides the documented Bootstrap Profile
needed to develop and compile `UBE_Compiler_v3`.

`UBE_Compiler_v3` is the first public-release target. Project structures,
classes, the remaining language surface, production hardening, optimization,
debug information, and other advanced features belong to v3 unless a narrowly
documented prerequisite is proven necessary to build v3. Do not expand v2 for
feature completeness alone after its transition gate passes.

### V2 transition and freeze gate

- [x] Preserve the stage-zero -> stage-one -> stage-two self-hosting chain and
  byte-identical fixed-point LLVM comparison.
- [x] Load one or more ordered `.bas` modules from a safe `.UBE` manifest.
- [x] Resolve supported procedure calls and `Type` references across modules,
  independent of declaration order.
- [x] Compare stage-one and stage-two multi-module IR, link it, and verify its
  native output and exit status.
- [x] Map failures in a non-entry module to that module and reject duplicate
  normalized paths without leaving a successful artifact.
- [x] Run every bootstrap verification from a freshly recreated output tree
  while retaining the complete v1 verification path.
- [x] Freeze the v3-facing subset and version boundary in
  `UBE_Compiler_v2/V3_BOOTSTRAP_CONTRACT.md`.

The v2 transition gate is complete. Remaining production-language and
hardening items below are retained as dependency history and v3 planning; they
do not expand the frozen v2 contract unless the v3 bootstrap proves one is a
strict prerequisite.

Before starting work, read `compiler/Progress.md`. During work, keep its active
task, decisions, files, verification commands, and next action current. Update
this roadmap and `lang-doc/bootstrap-profile.md` in the same change whenever a
capability or gate changes.

## Generation and bootstrap terminology

- A **compiler generation** is a preserved source design. It lives in
  `compiler/UBE_Compiler_vN/` and has a matching `UBE_Compiler_vN.UBE`
  manifest. Routine features and fixes do not create a new generation.
- A **bootstrap stage** identifies which compiler produced a binary. Stage zero
  is the C++ bootstrap compiler; stage one is built from UBE compiler source by
  stage zero; stage two is built from the same source by stage one.
- A generation is **self-hosting** only when its stage-one compiler compiles
  the same generation to stage two and the defined comparison gate passes.
- Start a new generation only for a deliberate architectural boundary. Keep
  every previous working generation buildable and tested.

## Required structure for every generation

- [x] Keep source in a uniquely numbered `UBE_Compiler_vN` directory.
- [x] Give the project manifest the same name as its directory.
- [x] Name the startup module `Main.bas`.
- [x] Keep generation-specific acceptance inputs under `tests/`.
- [ ] For future generations, add a local README describing scope, build
  command, limitations, and the previous generation from which it evolved.
- [ ] For future generations, keep generated IR, objects, executables, logs,
  and comparison artifacts outside the source directory.

## Milestone 0: preserve the first proof compiler

Purpose: retain the smallest proven crossing from the C++ bootstrap compiler
to a compiler executable written in UBE.

- [x] Preserve `UBE_Compiler_v1/Main.bas` and its project manifest.
- [x] Compile v1 with stage zero to produce `ube-stage1.exe`.
- [x] Use that binary to emit LLVM IR for both checked-in showcase programs.
- [x] Link and run the `Sub Main` showcase with exit code zero.
- [x] Link and run the `Function Main` showcase with exit code nine.
- [x] Keep both showcase programs under `UBE_Compiler_v1/tests/`.
- [x] Add a generation-local README with exact direct-build and acceptance-test
  commands.
- [x] Add negative v1 tests for missing `Print`, unterminated strings,
  unsupported message bytes, missing function result, bad arguments, read
  failure, and write failure; every case must return a controlled diagnostic.

Exit gate: v1 remains reproducibly buildable and its positive and negative
acceptance tests run automatically without reading or writing source-tree
outputs.

## Milestone 1: make the Bootstrap Profile sufficient for a real compiler

Purpose: add only the stage-zero language/runtime facilities required to
implement the next compiler generation cleanly in UBE.

### Compiler data and control flow

- [x] Support dynamic arrays of compiler-defined `Type` records.
- [x] Support passing dynamic arrays to procedures with explicit, tested
  ownership and `ByRef` behavior.
- [ ] Support nested record fields and the remaining scalar field types needed
  by tokens, source ranges, syntax nodes, symbols, and diagnostics.
- [ ] Implement `Select Case`, or document and test an equally clear
  Bootstrap-Profile dispatch pattern.
- [ ] Define allocation limits and deterministic cleanup for strings, arrays,
  records, and compiler workspaces.
- [ ] Make allocation and resize failure observable through controlled error
  results; add synthetic regression tests for every failure path.

### Text, files, and diagnostics

- [~] Provide a scalable string builder suitable for diagnostics and LLVM IR.
  A linear `StringArrayJoin` bootstrap intrinsic and v2 chunk accumulator are
  implemented; capacity growth and total-output limits remain.
- [ ] Complete the ordinal string comparison and integer-conversion operations
  used by compiler code.
- [~] Define a source-file abstraction that retains path, UTF-8 bytes, line
  starts, and bounded byte-to-line/column lookup.
- [~] Provide stable diagnostic emission with severity, identifier, path,
  line, column, message, and optional note.
- [ ] Make missing, unreadable, oversized, malformed, and concurrently changed
  inputs produce controlled diagnostics.
- [~] Test empty files, malformed UTF-8, very long lines, boundary offsets,
  embedded NUL bytes, and write failures.

### Projects and build inputs

- [x] Implement safe `.UBE` manifest loading for ordered source files, without
  path traversal or duplicate normalized inputs.
- [x] Compile more than one ordered source module as one project and resolve
  supported types and procedures across module boundaries.
- [ ] Reserve `.UBG` orchestration and `.UBR` validation behind explicit
  diagnostics until implemented; never silently ignore either format.
- [ ] Add positive, negative, size-limit, and path-normalization tests derived
  from `lang-doc/project-files.md`.

### Profile verification

- [ ] Give every new profile feature parser, semantic, lowering, native
  execution, and malformed-input coverage where applicable.
- [ ] Update `lang-doc/bootstrap-profile.md` after each verified capability.
- [x] Run the complete bootstrap suite from a clean output directory.
- [ ] Record the supported GCC, LLVM/Clang, MinGW-w64, PowerShell, target
  triple, and flags used by the verification run.

Exit gate: stage zero can safely compile and run a multi-module UBE program
that uses the data structures, text construction, project loading, and
diagnostic machinery needed by the next compiler.

## Milestone 2: specify and scaffold `UBE_Compiler_v2`

Purpose: begin the first structured compiler generation only after its required
Bootstrap Profile is executable and tested.

- [x] Write a short v2 design note covering module boundaries, data ownership,
  failure propagation, resource limits, and interfaces between phases.
- [~] Freeze the token, source-range, diagnostic, AST, symbol, typed-expression,
  target-independent IR, and backend handoff contracts needed for v2.
- [x] Create `compiler/UBE_Compiler_v2/UBE_Compiler_v2.UBE` and `Main.bas`.
- [ ] Split v2 into ordered modules for driver/project loading, source text,
  diagnostics, lexing, parsing, semantics, IR, and LLVM emission.
- [x] Add a generation-local README and `tests/` hierarchy.
- [ ] Add a command-line driver that validates arguments, loads one project,
  reports all failures without a crash, and returns documented exit codes.
- [ ] Add deterministic limits for input bytes, token count, nesting depth,
  diagnostics, allocations, and emitted output.
- [x] Add an automated stage-zero-to-v2 build and smoke test without removing
  the v1 verification path.

Exit gate: stage zero builds v2, and the v2 driver can safely accept or reject
a project and dispatch a source file through placeholder phase boundaries.

## Milestone 3: implement the v2 front end

Purpose: make the UBE-written compiler own source interpretation rather than
searching source text for a special-case program shape.

### Source and lexer

- [ ] Load each manifest source exactly once and retain stable file identity.
- [~] Port strict UTF-8 validation, newline handling, comments, continuations,
  literals, identifiers, and Unicode case folding from the normative rules.
  UTF-8 validation, newline rules, comments, continuations, string/integer
  literals, Unicode 18.0 letter identifiers, and code-point simple-folded name
  comparison are active; complete literal forms and symbol-table integration
  remain.
- [~] Preserve original spelling, byte ranges, and character-based diagnostic
  positions for every token.
- [~] Diagnose invalid bytes and tokens with bounded recovery.
- [ ] Add table-driven lexer conformance tests and arbitrary-byte crash tests.

### Parser and syntax representation

- [ ] Parse the complete Bootstrap Profile compilation unit and module forms.
- [~] Parse module-level procedure and `Type` declaration structure. V2 records
  bounded procedure/type/field tables, validates matching terminators and
  explicit field types, parses passing modes, dynamic-array parameters, and
  function result types, and rejects Unicode-folded duplicate declarations;
  procedure bodies remain.
- [~] Parse procedure bodies into bounded declaration and statement records.
  Procedure-scoped locals, initializer ranges, assignments, and explicit calls
  are recorded. Block `If/Else/End If` and `While/Wend` are structurally
  matched with a bounded explicit stack, and their conditions are parsed and
  typed; remaining structured statements remain.
- [~] Parse Bootstrap Profile expressions into flat syntax nodes. String
  and integer literals, parentheses, names, calls/indexing, member access,
  unary operations, linked argument lists, and the current binary precedence
  levels are active; remaining literal/operator forms and complete typing remain.
- [~] Resolve and type-check expression nodes. Intrinsic scalars, user-defined
  records, dynamic arrays, variables, function results, calls/indexing, member
  access, comparisons, logical operations, arithmetic, concatenation, and local
  initializers are active. Assignment lvalues, exact `ByRef`, call
  assignability, callable/indexable classification, symmetric numeric
  promotion, unary/logical operand constraints, and control-flow conditions
  are checked; full conversions and `ParamArray` remain.
- [ ] Parse declarations, procedures, parameters, records, arrays, expressions,
  assignments, calls, and structured control flow required by compiler source.
- [~] Build owned syntax data with explicit source ranges and checked indices.
  Flat, geometrically grown syntax-node storage with checked sentinel indices
  is active for the current entry-procedure expression subset.
- [ ] Recover at declaration and statement boundaries to report multiple
  diagnostics without loops or out-of-bounds access.
- [ ] Add valid, invalid, deeply nested, truncated, and oversized parser tests.

Exit gate: v2 tokenizes and parses all v2 source modules, produces stable
syntax snapshots, and rejects malformed or resource-exhausting input through
controlled diagnostics.

## Milestone 4: implement v2 semantics and target-independent IR

Purpose: accept only fully typed programs and make behavior explicit before
LLVM-specific lowering.

- [ ] Build case-insensitive module, procedure, parameter, local, record, and
  field symbol tables using the shared Unicode fold rules.
- [ ] Diagnose duplicates, unknown names, invalid shadowing, and unsupported
  declarations with stable diagnostic identifiers.
- [ ] Resolve and validate types, calls, `ByVal`/`ByRef`, lvalues, array access,
  member access, operators, conversions, and procedure results.
- [x] Validate exactly one supported executable `Main` signature.
- [~] Define a typed, target-independent IR with checked identifiers and
  explicit control-flow edges. Typed instruction/procedure ranges are active;
  structured edges are currently verified and materialized during LLVM emission.
- [ ] Lower supported declarations, expressions, calls, branches, loops,
  arrays, strings, records, returns, and failure propagation into that IR.
- [~] Add an IR verifier; invalid IR must be diagnosed before backend entry.
  Procedure ownership, instruction ranges, opcodes, and node indices are
  checked; full type/CFG invariants remain.
- [ ] Add stable textual IR snapshots and semantic/lowering golden tests.
- [ ] Add negative tests for every semantic rule and every checked-index path.

Exit gate: every accepted Bootstrap Profile program is fully typed and lowers
to verified IR; rejected programs never reach LLVM emission.

## Milestone 5: implement the v2 LLVM backend

Purpose: emit deterministic native-code input without depending on undefined
LLVM behavior or hidden source-pattern shortcuts.

- [ ] Define the supported LLVM textual IR version, target triple, data layout,
  ABI, symbol naming, and linkage rules.
- [x] Lower all v2 Bootstrap-Profile instructions, types, calls, branches,
  checked operations, strings, arrays, and records used by its own source to
  valid LLVM IR.
- [ ] Attach source locations needed by diagnostics and later debug metadata.
- [x] Emit deterministic ordering and formatting for equivalent inputs.
- [ ] Validate generated IR before linking and turn tool failures into concise,
  actionable diagnostics.
- [ ] Link executables through the documented driver boundary with fully
  recorded tool paths and flags.
- [~] Add end-to-end programs covering every supported construct and ABI edge.
  The backend feature program covers calls, `ByRef`, records, arrays, resizing,
  arithmetic, branches, and loops; broader conversion/ABI edges remain.
- [ ] Add output checks proving malformed input never yields partial output
  reported as successful.

Exit gate: stage-zero-built v2 compiles the Bootstrap Profile conformance
corpus and v2's own supported source subset into working native executables.

## Milestone 6: reach self-hosting with v2

Purpose: prove that the UBE-written compiler can reproduce itself.

- [x] Make stage zero compile the complete single-source v2 compiler into the
  stage-one compiler; `.UBE` manifest loading remains a separate project gate.
- [x] Make stage one load and compile the same v2 project into stage two.
- [x] Define the LLVM comparison policy: identity canonicalization with no
  ignored fields and byte-equivalence proven by length plus SHA-256.
- [x] Record source/compiler/runtime identities, tool versions, target, flags,
  and artifact hashes in a generated bootstrap manifest.
- [x] Compare stage-one and stage-two self-emission automatically at the stable
  fixed point (stage-two IR versus stage-three IR).
- [x] Run both compilers over the same positive and negative conformance corpus
  and compare IR, diagnostics, exit codes, and output-artifact behavior.
- [~] Repeat the complete bootstrap from a clean checkout/output directory.
  Fresh-output verification passes; this workspace has no usable Git worktree
  metadata with which to prove a separately clean checkout.
- [x] Keep stage zero and v1 archived, documented, buildable, and continuously
  tested after v2 becomes authoritative.
- [x] Document the trust boundary and reproducibility result.

Exit gate: clean stage-zero -> stage-one -> stage-two builds pass the documented
comparison policy, with no pre-existing UBE binary required.

## Milestone 7: harden the self-hosting compiler

Purpose: retain a list of production-hardening work. Under the agreed version
boundary these items are v3 work unless one is strictly required to preserve
v2 self-hosting or to compile v3 safely.

- [ ] Fuzz project manifests, source bytes, lexer, parser, semantic inputs, IR,
  and backend boundaries with saved regression cases.
- [ ] Test low-memory, full-disk, permission, interrupted-write, oversized-input,
  deep-nesting, huge-diagnostic, and external-tool failure scenarios.
- [ ] Make all compiler output writes atomic where partial files could be
  mistaken for valid artifacts.
- [ ] Establish compile-time, peak-memory, output-size, and generated-code
  performance baselines.
- [ ] Add deterministic clean-build verification to continuous integration.
- [ ] Assign stable public diagnostic identifiers and document exit codes.
- [ ] Verify that release builds contain no panic/assert-only user-input paths.
- [ ] Publish a supported-host/toolchain matrix and bootstrap troubleshooting
  guide.

Exit gate: the self-hosting compiler survives hostile inputs and environmental
failures with useful diagnostics and reproducible output on every supported
host.

## Milestone 8: evolve to the production compiler generation

Purpose: expand beyond the Bootstrap Profile without destabilizing the proven
self-hosting line. Create `UBE_Compiler_v3` only when its design boundary is
written and v2 remains preserved.

The detailed, resumable release-preview sequence and per-preview stability
gates are maintained in
[`UBE_Compiler_v3/ROADMAP.md`](UBE_Compiler_v3/ROADMAP.md). This section tracks
only the generation-level outcome.

- [x] Define the v3 architectural changes and migration plan before creating
  its directory.
- [x] Use preserved v2 as the compiler that develops and builds v3; do not
  bootstrap v3 directly from an unrelated implementation.
- [x] Preserve a buildable v2 and its full bootstrap comparison suite.
- [ ] Implement the frozen grammar and semantic surface in dependency order,
  changing normative documents only when correcting an identified contract
  defect or recording an owner-approved decision.
- [ ] Implement the full `.UBE`, `.UBG`, and validated `.UBR` build model.
- [ ] Add library output, foreign declarations, optimization levels, debug
  information, and supported target/ABI expansion.
- [ ] Implement explicit runtime error propagation and `On Error` lowering
  without automatic dialogs or uncontrolled crashes.
- [ ] Add compatibility, conformance, ABI, debugger, performance, and
  reproducibility suites for every declared supported feature and target.
- [x] Bootstrap v3 through stage two and pass the same or stricter comparison
  policy before making it authoritative.

Exit gate: the current normative UBE language and project model are implemented
by a verified, self-hosting, optimized 64-bit compiler suitable for the runtime,
standard library, debugger, and native IDE work tracked in
`project-docs/Roadmap.md`.

## Milestone 9: rebuild the production compiler as v4

Purpose: preserve v3 as the executable UBE 1.0 and bootstrap oracle while
replacing its coupled whole-program implementation with a compiler designed
around small owned phase results, indexed lookup, deterministic local work, and
the correct compiler/library boundary.

The proposed architecture, reuse classification, ordered roadmap, and bounded
agent task packets are maintained under
[`UBE_Compiler_v4/`](UBE_Compiler_v4/README.md). V4 remains documentation-only
until its Task 0 architecture gate receives owner approval.

- [x] Review and approve the v4 architecture, reuse plan, task order, parser
  decision gate, and library/compiler-support boundary. Owner-approved on
  2026-10-27.
- [~] Complete the bounded Task 0 prototypes and freeze the remaining measured
  architecture decisions before production scaffolding.
- [ ] Move or implement approved general-purpose foundations in `UBECore` or a
  versioned compiler-support project before compiler phases depend on them.
- [ ] Create the v4 manifest/startup scaffold only after the architecture gate.
- [ ] Establish one narrow v3-built end-to-end vertical slice before expanding
  language coverage.
- [ ] Reimplement the complete frozen UBE 1.0 front end, semantics, local IR,
  backend, packages, and runtime contracts with differential v3 coverage.
- [ ] Enable deterministic parallel phases only after one-job parity,
  representative speedup, memory, cancellation, and cleanup gates pass.
- [ ] Reach the v3-built v4 -> self-built v4 fixed point and reproduce the exact
  selected source-library slice without weakening prior trust gates.
- [ ] Pass hostile-input, environmental-failure, performance, portability,
  documentation, and offline release gates before making v4 authoritative.

Exit gate: v4 satisfies the complete frozen language, library, runtime,
package, debugger, target, determinism, never-crash, and performance contracts;
v1 through v3 remain preserved and reproducibly buildable.

## Definition of compiler-roadmap completion

- [ ] A clean checkout builds stage zero, every preserved compiler generation,
  and the current compiler without network downloads.
- [ ] The current compiler compiles itself through stage two reproducibly.
- [ ] All accepted input is fully validated before unsafe backend operations.
- [ ] Malformed input and environmental failures produce tested diagnostics,
  never a compiler or runtime panic.
- [ ] Generated programs conform to the language, ABI, runtime, performance,
  and debugging requirements declared by the project.
