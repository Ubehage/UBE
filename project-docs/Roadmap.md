# UBE development roadmap

This document tracks the work required to take UBE from its current
stage-zero lexer to a complete, self-hosting compiler, runtime, standard
library, debugger, and native IDE.

The roadmap is ordered by dependency. Later phases may be prototyped early,
but a phase is complete only when its exit criteria are satisfied.

## How to maintain this roadmap

Use these markers consistently:

- `[ ]` Not started
- `[~]` In progress
- `[x]` Complete and verified
- `[!]` Blocked; add a short explanation and link to the relevant issue or
  design note

Agents and contributors should update this file in the same change that
completes or materially changes an item. Keep completed items in place so the
file remains a useful history of the project's progress. Split an item when
only part of it is complete. Do not mark an item complete merely because an
initial implementation exists: its tests, diagnostics, and documentation must
also meet the stated exit criteria.

When a decision changes the language or architecture, update the normative
documents first or in the same change:

- [`../lang-doc/language-spec.md`](../lang-doc/language-spec.md) for lexical and semantic behavior
- [`../lang-doc/grammar/ube.ebnf`](../lang-doc/grammar/ube.ebnf) for syntax
- [`architecture.md`](architecture.md) for compiler and bootstrap boundaries
- [`../lang-doc/project-files.md`](../lang-doc/project-files.md) for project, project-group, source-list,
  and binary-resource container behavior

## Current position

The owner has now named the fresh compiler v3 and archived the previous v3/v4
under `../compiler/archived/`. Early native-datatype mechanisms and investigation
of a bounded stage-zero/v2 bootstrap route are approved. Resume from
`../compiler/UBE_Compiler_v3/Roadmap.md` and `../std-lib/ROADMAP.md`. References to
old v3/v4 milestones below describe the archived lines.

The fresh source reader/scanner and Unicode helpers pass the refreshed 501-check
native gate. The bounded grammar consumer in
`../compiler/UBE_Compiler_v3/PARSER-CONTRACT.md` is now implemented and independently
qualified: 4049 native checks through both stages, 188 independent cases, all
10412 real-root capacities, measured work/copy bounds and strict production CLI
acceptance pass. Exact commands, identities and limits are in
`../compiler/UBE_Compiler_v3/PARSER-NATIVE-EVIDENCE.md`. It uses the measured
linked-child nodes and explicit stacks. Semantic checking, conditional selection,
deferred grammar and code generation remain separate. Resume from the fresh
compiler roadmap; no successor implementation item is selected by this slice.

The owner changed the immediate development order on 2026-10-30: establish a
fresh UBECore in [`../std-lib/`](../std-lib/README.md), adding independently
tested facilities as concrete compiler needs arise. The previous library is
archived intact. Further v3/v4 feature expansion is deferred; resume from
[`../std-lib/ROADMAP.md`](../std-lib/ROADMAP.md). The compiler checkpoints and
long-term feature inventory below are preserved history and scope, not the
current execution order.

UBE currently has a frozen UBE 1.0 language definition, a C++17 stage-zero compiler,
a minimal native runtime, and the preserved self-hosting UBE Compiler v2.
Stage zero builds v2; v2 rebuilds itself through stage two with byte-identical
fixed-point LLVM and compiles ordered multi-module projects with supported
cross-module references. V2 is the transitional compiler used to develop and
compile v3, UBE's first public-release target.

## Phase 0: project foundations

- [x] Establish the initial language specification and normative grammar.
- [x] Define the bootstrap, compiler, runtime, and standard-library boundaries.
- [x] Create a reproducible stage-zero build entry point.
- [ ] Add continuous integration for supported host platforms and compilers.
- [ ] Define the supported host platforms, target platforms, and minimum tool
  versions.
- [ ] Adopt formatting and static-analysis rules for stage-zero C++ and later
  UBE source.
- [ ] Add contribution, issue-reporting, security, and release documentation.
- [ ] Define versioning for the language, compiler, runtime ABI, object format,
  and standard library.
- [ ] Add license notices and third-party dependency tracking where required.
- [x] Reserve `.UBE` and `.UBG` for plain-text project and project-group
  manifests, define the supported source extensions, and separate binary
  designer data into `.UBR` sidecars.

Exit criteria: a fresh checkout can be built and tested on every supported
host through documented, automated commands.

## Phase 1: complete the stage-zero lexer

- [x] Recognize identifiers, initial reserved words, literals, operators,
  punctuation, comments, newlines, and explicit line continuations.
- [x] Accept an optional UTF-8 BOM and validate UTF-8 strictly.
- [x] Preserve byte offsets while reporting character-based line and column
  locations.
- [x] Reject lone carriage returns and malformed base-prefixed integers.
- [x] Implement Unicode `Letter` category checks for bare identifiers using a
  generated, version-pinned Unicode data table.
- [x] Implement Unicode simple case folding for keyword comparison and provide
  a shared folding utility for later name resolution while retaining original
  spelling.
- [ ] Decide and implement the distinction between hard and contextual
  keywords.
- [x] Define and validate invariant Gregorian UBE date/time literal syntax.
- [ ] Add a compiler compatibility-mode option for locale-dependent VB6 date
  literals without changing invariant-mode behavior.
- [ ] Verify every numeric form, suffix, overflow boundary, and token-boundary
  ambiguity defined by the specification.
- [ ] Verify string, bracketed-identifier, comment, continuation, BOM, and EOF
  edge cases.
- [ ] Add lexer error recovery suitable for reporting more than one diagnostic
  per file, if the parser architecture requires it.
- [ ] Add table-driven conformance tests derived from the lexical specification.
- [ ] Add fuzzing and malformed-input tests.
- [x] Exhaustively exercise every one-byte and two-byte input combination and
  require either tokens or a controlled `LexError`.
- [ ] Freeze and document the token interface consumed by the parser.

Exit criteria: all lexical rules in the language specification have positive,
negative, and source-location tests, and arbitrary input cannot crash or hang
the lexer.

## Phase 2: parser and syntax tree

- [ ] Choose and document the concrete-syntax-tree and abstract-syntax-tree
  representation, ownership model, and source-range policy.
- [x] Establish the initial owned AST and source-location model for procedures,
  local declarations, assignments, output, exits, and expressions.
- [ ] Implement compilation-unit, file-header, designer-block, and module-level
  parsing.
- [ ] Implement declaration parsing, including variables, constants, types,
  enums, events, external declarations, and variable hooks.
- [~] Parse and lower Bootstrap Profile user-defined `Type` records. Named
  records with scalar `Long`/`String` fields, member access, and `ByRef`
  parameters work natively; general record composition and arrays remain.
- [ ] Implement procedure, property, intrinsic, and parameter parsing.
- [ ] Implement expressions with the specified precedence, associativity, call
  forms, member access, indexing, and `With` shorthand.
- [x] Implement and test the complete core unary/binary precedence ladder for
  the initial expression forms.
- [~] Implement structured control-flow statements. The Bootstrap Profile has
  block `If`, `While`/`Wend`, bidirectional `For`/`Next`, and structured loop
  exits; the complete grammar surface remains.
- [ ] Implement legacy VB6-compatible statements and file I/O syntax.
- [ ] Implement inline assembly and bytecode syntax envelopes without
  interpreting their payloads.
- [ ] Retain comments, original spelling, attributes, and designer metadata
  needed by tools.
- [ ] Produce precise expected-token diagnostics with recovery at statement and
  declaration boundaries.
- [ ] Add valid and invalid grammar conformance suites.
- [ ] Add parser fuzzing, nesting limits, and resource-exhaustion safeguards.

Exit criteria: every production in `lang-doc/grammar/ube.ebnf` is implemented and
tested, malformed files produce useful diagnostics, and exported VB6 source
fixtures can be parsed without losing tool-relevant metadata.

## Phase 3: symbols, types, and semantic analysis

- [ ] Implement packages, modules, scopes, declarations, imports/references,
  visibility, and case-insensitive name resolution.
- [x] Use the shared Unicode simple-fold representation for initial local,
  parameter, procedure, and entry-point lookup and duplicate-name detection.
- [ ] Extend canonical folded-name lookup across packages, modules, members,
  imports, and labels, including the frozen ambiguity and qualification rules.
- [ ] Implement the complete core type model, including fixed-width integers,
  pointer-sized integers, floating point, decimal, currency, date, strings,
  objects, variants, arrays, and user-defined types.
- [~] Implement dynamic arrays. The native Bootstrap Profile supports
  one-dimensional local `Long()` and `String()` arrays with indexed access,
  bounds queries, and preserving or non-preserving resizing; general element
  types, ranks, parameters, and lifetime semantics remain.
- [ ] Define and implement implicit conversions, explicit conversions, literal
  typing, property/intrinsic signature selection, and operator typing. UBE 1.0
  has no user-defined procedure overloading.
- [~] Implement checked Bootstrap Profile integer operations. Native `Long`
  arithmetic, division, remainder, negation, and loop increments are checked;
  other integer widths and conversion boundaries remain.
- [ ] Enforce mandatory explicit types on variables, constants, parameters,
  properties, and function results; reject undeclared names and implicit
  `Variant` declarations in every mode.
- [ ] Accept `Option Explicit` and `Option Explicit On` only as redundant
  import-compatibility declarations, and diagnose `Option Explicit Off`.
- [ ] Define the callable-signature mechanism used by broadly typed
  compatibility built-ins without weakening ordinary static type checking.
- [ ] Validate assignments, lvalues, constants, array bounds, procedure result
  assignment, and declaration placement.
- [ ] Validate procedure/property terminators, parameter rules, `Exit`, `Next`,
  labels, and other context-dependent grammar restrictions.
- [x] Resolve and validate exactly one parameterless `Sub Main()` or
  `Function Main() As Long` for executable projects.
- [ ] Add an explicit library build mode that requires no `Main` and rejects
  executable entry-point selection.
- [~] Implement `ByRef`, `ByVal`, optional arguments, named arguments, omitted
  argument slots, and `ParamArray` semantics. The Bootstrap Profile supports
  `ByVal` plus explicit and default `ByRef` for directly addressable variables.
- [ ] Implement variable-hook validation and privileged backing-storage access.
- [ ] Implement `Inline`, `ForceInline`, and `Intrinsic` contract validation.
- [ ] Define object, class, interface, event, and lifetime semantics needed by
  the accepted VB6 surface.
- [ ] Implement configurable compatibility and modernization diagnostics.
- [ ] Assign stable diagnostic identifiers and test diagnostic wording,
  locations, notes, and fix suggestions.

Exit criteria: all accepted programs are fully typed or rejected before
lowering, and every static restriction in the language specification has tests.

## Phase 4: intermediate representation and lowering

- [ ] Define a typed, target-independent UBE intermediate representation.
- [ ] Lower declarations, expressions, calls, control flow, arrays, strings,
  objects, variants, errors, and variable hooks into that representation.
- [ ] Make evaluation order, overflow behavior, cleanup, and `ByRef` identity
  explicit in the IR.
- [ ] Represent potentially failing operations as an ordinary result plus
  explicit error status, including neutral-value substitution and
  procedure-local `On Error` branches.
- [ ] Implement control-flow and data-flow verification passes.
- [ ] Implement mandatory `ForceInline` expansion with hygiene, evaluate-once
  behavior, and recursive-cycle rejection.
- [ ] Implement ordinary `Inline` requests without making correctness depend on
  optimization.
- [ ] Define stable textual serialization for IR tests and bootstrap comparison.
- [ ] Add golden lowering tests and an IR verifier.

Exit criteria: semantically valid programs lower to verified,
target-independent IR whose behavior is fully specified without relying on
LLVM undefined behavior.

## Phase 5: LLVM backend and native output

- [ ] Select and document the supported LLVM version and integration method.
- [ ] Map UBE types, calling conventions, control flow, exceptions/errors, and
  debug locations to LLVM IR.
- [ ] Implement target triples, data layouts, ABI classification, symbol
  mangling, linkage, and foreign declarations.
- [x] Generate object code for the initial x86-64 Windows GNU target through
  LLVM 23 and Clang.
- [~] Integrate the platform assembler and linker: executable linking works for
  the initial bootstrap subset; library output remains to be implemented.
- [x] Lower the validated `Main` procedure to the platform process-entry
  adapter and propagate function-form exit codes.
- [ ] Implement compiler intrinsic registration, signature validation, target
  availability, and lowering.
- [ ] Gate inline assembly and bytecode behind the required unsafe setting.
- [ ] Add optimization-level handling without changing language semantics.
- [ ] Add deterministic-output controls and record all inputs needed for
  reproducible builds.
- [ ] Add executable integration tests and ABI tests against small C fixtures.
- [ ] Validate referenced `.UBR` entries and embed them in deterministic,
  target-appropriate read-only output without exposing unchecked offsets.

Exit criteria: stage zero can compile representative UBE programs into working
64-bit native executables with deterministic, tested behavior.

## Phase 6: minimal runtime substrate

- [ ] Specify and version the runtime ABI.
- [~] Implement process startup and shutdown: initial Windows x86-64 startup is
  verified; additional supported targets and complete shutdown behavior remain.
- [x] Invoke `Sub Main()` or `Function Main() As Long` through the initial
  platform entry adapter, mapping the `Sub` form to zero and propagating the
  `Function` result.
- [ ] Implement allocation, deallocation, and out-of-memory hooks.
- [ ] Implement string and array storage primitives required by generated code.
- [ ] Implement object lifetime and reference-management primitives.
- [ ] Implement thread-local `Err` state, neutral failure values, explicit
  clearing, procedure-local `On Error` support, and cleanup primitives without
  automatic dialogs or uncontrolled process crashes.
- [ ] Define and test the controlled noninteractive path for failures from
  which execution cannot safely continue, including resource exhaustion.
- [ ] Implement opaque, non-address object handles with a defined null handle
  for `Nothing` and stale-handle detection.
- [ ] Implement platform ABI adapters and foreign-function support.
- [ ] Implement only the irreducible operations represented by documented
  intrinsics.
- [ ] Add runtime unit, stress, sanitizer, leak, and ABI compatibility tests.

Exit criteria: generated programs can execute all core language constructs
without hidden compiler-only library behavior, and the runtime ABI is tested
and documented.

## Phase 7: standard library

Library implementation belongs in the root-level
[`std-lib/`](../std-lib/README.md), never inside a compiler
generation. Its focused resumable checklist is
[`std-lib/ROADMAP.md`](../std-lib/ROADMAP.md).

- [ ] Define the initial standard-library module layout and public API policy.
- [ ] Implement core conversions, math, strings, characters, dates, and error
  helpers in UBE wherever practical.
- [ ] Implement collections and common algorithms.
- [ ] Implement filesystem, stream, console, environment, and process APIs.
- [ ] Implement VB6-compatible intrinsic-style functions such as `Mid$` and
  `Left$` as ordinary library functions.
- [ ] Specify and implement broadly typed compatibility built-ins such as
  `Mid$` and `Len`, including invariant scalar-to-string conversion and the
  documented treatment of accepted object handles.
- [ ] Add conformance tests proving that broadly typed built-ins accept all
  documented scalar categories, reject unsupported categories, and never
  expose raw object addresses.
- [ ] Document every operation's failure sentinel and `Err` contract, including
  cases where the neutral value is also a valid successful result.
- [ ] Implement compatibility helpers for legacy file and runtime behavior.
- [ ] Define locale, encoding, time-zone, and platform behavior explicitly.
- [ ] Add API documentation, examples, unit tests, conformance tests, and
  performance tests.
- [ ] Establish compatibility and deprecation policies for public APIs.

Exit criteria: ordinary applications can be written without private runtime
entry points, and the supported standard-library surface is documented and
tested across supported targets.

## Phase 8: self-hosting compiler

- [~] Specify the exact UBE Bootstrap Profile used by compiler source; the
  evolving implemented subset and remaining compiler requirements are tracked
  in [`../lang-doc/bootstrap-profile.md`](../lang-doc/bootstrap-profile.md).
- [~] Implement the UBE compiler in UBE within that profile: the first narrow
  compiler is in `compiler/UBE_Compiler_v1`; the full compiler pipeline remains.
- [x] Make stage zero compile the current UBE compiler to produce stage one.
- [ ] Make stage one compile the same source to produce stage two.
- [ ] Define canonicalization and comparison rules for bootstrap artifacts.
- [ ] Compare normalized stage-one and stage-two output automatically.
- [ ] Record source hashes, compiler versions, LLVM version, target triple, and
  flags in bootstrap manifests.
- [ ] Archive and continuously test the stage-zero compiler after self-hosting.
- [ ] Perform a trust and reproducibility review of the complete bootstrap path.

Exit criteria: the documented stage-one/stage-two comparison passes
reproducibly from a clean checkout without requiring a pre-existing UBE binary.

## Public Developer Preview: Stage One

UBE is intended to become public at the first useful UBE-written compiler
milestone. This preview does not require full self-hosting, a complete standard
library, the debugger, or the IDE. It must provide a credible foundation that
contributors and testers can build, run, understand, and improve.

- [ ] The compiler is substantially written in the documented UBE Bootstrap
  Profile.
- [x] Stage zero compiles the current UBE compiler into a working stage-one
  compiler.
- [x] Stage one compiles and runs the checked-in `Sub Main` and `Function Main`
  showcase programs as native 64-bit executables.
- [x] `Sub Main()` and `Function Main() As Long` work end to end for the current
  native bootstrap subset, including process exit-code behavior.
- [ ] A clean checkout builds through one documented command using explicitly
  supported tool versions.
- [x] Automated tests cover the current stage-zero-to-stage-one compiler path
  and its two native showcase programs.
- [x] Small checked-in showcase programs are compiled and run by the documented
  build without knowledge of compiler internals.
- [x] The implemented Bootstrap Profile and the first stage-one compiler's
  limitations are documented.
- [ ] The repository has an open-source license, contribution guide, code of
  conduct, issue templates, and security-reporting instructions.
- [ ] Public-facing documentation explains the project's AI-authored origin and
  how human contributions will be reviewed and credited.
- [ ] Preview release artifacts and their corresponding source revision are
  published with build instructions and checksums.

Exit criteria: an external developer can clone UBE, build stage one, compile
and run the showcase, understand the supported subset, report defects, and
begin contributing without private project knowledge.

## Phase 9: debugging support and developer tooling

- [ ] Emit source-level debug information for variables, types, scopes,
  procedures, and generated control flow.
- [ ] Define debugging behavior for optimized code, inlined calls, variable
  hooks, and runtime-managed values.
- [ ] Support breakpoints, stepping, stack traces, local inspection, watches,
  and expression evaluation.
- [ ] Build a command-line debugger integration for the initial platform.
- [ ] Implement a language server with diagnostics, navigation, completion,
  hover information, references, rename, and formatting.
- [ ] Implement dependency-aware incremental compilation suitable for IDE use.
- [ ] Add compiler APIs for syntax trees, semantic queries, and refactoring.
- [ ] Implement the specified `.UBE` project and `.UBG` project-group loaders,
  dependency-aware build orchestration, and command-line build tool.

Exit criteria: users can build, navigate, diagnose, run, and debug multi-file
UBE projects without relying on compiler internals.

## Phase 10: native IDE

The IDE must be a native application. Tauri, Electron, webview shells, and
equivalent browser-based application shells are out of scope.

- [ ] Select and document a native, cross-platform UI strategy or explicitly
  define platform-specific front ends.
- [ ] Design the project explorer, code editor, form designer, properties
  window, toolbox, immediate window, and debugger experience around VB6's ease
  of use.
- [ ] Integrate the language server, build system, compiler, and debugger.
- [ ] Implement project creation, editing, build, run, and debug workflows.
- [ ] Implement native visual form and control designers with stable source and
  metadata serialization.
- [ ] Read and write `.frm`/`.ctl` text plus named `.UBR` entries atomically,
  preserving unknown textual metadata and never leaving a half-written pair.
- [ ] Support project-configured startup forms by generating form loading from
  the `Main` startup path without creating an alternative entry point.
- [ ] Support import and migration workflows for compatible VB6 projects.
- [ ] Add accessibility, localization, keyboard navigation, crash recovery,
  settings migration, and large-project performance testing.
- [ ] Package and sign native IDE releases for supported platforms.

Exit criteria: a user can create, design, edit, compile, run, and debug a real
UBE application entirely through a responsive native IDE.

## Phase 11: compatibility, quality, and performance

This work begins early and continues throughout all phases.

- [ ] Build a legally redistributable VB6 syntax and behavior compatibility
  corpus.
- [ ] Create end-to-end conformance tests from source through executable output.
- [ ] Add differential tests where a defined VB6 compatibility comparison is
  possible.
- [ ] Add fuzzers for source input, metadata, serialized IR, object generation,
  and debugger protocols.
- [ ] Run sanitizers and static analysis regularly on bootstrap and runtime code.
- [ ] Define security limits for hostile source files and build inputs.
- [ ] Establish compile-time, runtime-performance, memory-use, and binary-size
  benchmarks.
- [ ] Compare representative generated programs with VB6 and relevant native
  compilers, then address material regressions.
- [ ] Test long-running, multithreaded, large-source, and low-memory scenarios.
- [ ] Maintain a platform compatibility matrix and release qualification suite.

Exit criteria: the supported language and library behavior is measured by a
broad conformance suite, known incompatibilities are documented, and release
quality gates cover correctness, security, performance, and binary size.

## Phase 12: release and long-term maintenance

- [ ] Define alpha, beta, release-candidate, and stable-release quality gates.
- [ ] Publish installation, language, library, migration, embedding, debugging,
  and IDE documentation.
- [ ] Produce reproducible compiler, runtime, library, debugger, and IDE
  packages for supported platforms.
- [ ] Sign releases and publish checksums, source archives, bootstrap manifests,
  license material, and release notes.
- [ ] Establish vulnerability reporting and supported-release policies.
- [ ] Establish language evolution, proposal, compatibility, and deprecation
  processes.
- [ ] Maintain stage-zero rebuildability and self-hosting verification in every
  supported release line.

Exit criteria: UBE can be installed, used, audited, upgraded, and maintained as
a stable open-source native development platform.

## Definition of project completion

UBE reaches the initial complete milestone when all of the following are true:

- The documented language is implemented by a self-hosting compiler.
- The compiler reliably produces optimized 64-bit native programs for every
  declared supported target.
- Core runtime and standard-library APIs are stable, versioned, and documented.
- Source-level debugging and essential developer tooling work end to end.
- A native IDE provides the intended edit/design/build/run/debug workflow.
- Compatibility limits are explicit and covered by conformance tests.
- Clean bootstrap builds and release artifacts are reproducible and auditable.
- Correctness, security, performance, binary-size, and release-quality gates
  pass on all supported platforms.

This milestone does not end development. Additional targets, language
versions, libraries, optimizations, and IDE capabilities continue through the
normal proposal and release process.
