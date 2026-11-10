# UBE compiler roadmap

The owner authorized a restart on 2026-11-10. This plan preserves the approved
UBE language and minimal compiler/library boundary. It does not carry forward
completion claims from removed implementations.

The final UBE-written compiler must be multithreaded, with all compiler code
thread-safe from its initial design. This is mandatory independently of the
IDE; the VB6 bootstrap may remain sequential. Ownership, dependency ordering
and shared-state rules are in the development plan's concurrency requirement.

## Bootstrap and self-hosting

- [x] Prove the owner-selected VB6 bootstrap path using the gate in
  [Progress.md](Progress.md).
- [~] Define compiler/UBECore ownership and inventory VB6 runtime names before
  selecting the bootstrap subset. See [LANGUAGE-SURFACE.md](LANGUAGE-SURFACE.md)
  and [library inventory](../std-lib/INVENTORY.md).
- [~] Specify the minimum source subset needed by the UBE-written compiler.
  Enumerate syntax, types, storage, errors, library dependencies and target
  facilities, plus positive and negative acceptance cases. The initial planned
  scalar admission set is in `../lang-doc/bootstrap-profile.md`; expansion to
  actual self-hosting dependencies remains evidence-driven.
- [x] Qualify the native failure-flow prototype: the command in Progress.md
  passed eight assertions at O0/O2 and rejected both negative controls.
- [x] Compile matching UBE source through the real pipeline.
  [ACCEPTANCE.md](ACCEPTANCE.md) separates native feasibility from compiler
  conformance. The native gate passed 23 groups, including all eight actual
  source-oracle checks at O0/O2 and the input-zero negative control.
- [x] Start the VB6 bootstrap with `.UBE` project loading and multiple ordered
  modules. Qualify bounded loading and manifest/source-header diagnostics before
  feeding the same retained sources to the parser. The 54-case gate in
  Progress.md passed.
- [x] Implement the bounded lexer/parser with retained syntax trees, source
  spans and malformed/unsupported-input diagnostics. The 37-case syntax gate
  and all 54 loading regressions passed on the same VB6 build.
- [x] Implement name resolution and scalar type checking over the retained
  trees, including entry validation, module visibility and official Err binding.
  The bounded semantic gate passed 76 cases, plus all parser/loading regressions.
- [ ] Implement the bootstrap subset with bounded input handling, controlled
  failures, source locations and deterministic output.
  The initial bounded scalar profile now compiles to native Windows x64, with
  checked error flow and output-preserving backend invocation. The same build
  passed 23 native, 76 semantic, 37 parser and 54 loading groups/cases.
  Expansion to the source/storage/library dependencies needed for self-hosting
  remains the next approved development-plan item; measure those dependencies
  before selecting each extension.
  Byte, Integer and LongLong storage and checked conversions are now complete,
  motivated in `../bootstrap/DEPENDENCIES.md`. The integer dependency gate passed
  46 groups, including 113 boundary cases at O0/O2, and all earlier gates pass.
  Fixed rank-one arrays and finite scalar-field records now provide bounded
  source buffers and retained token/tree storage; the admission boundary is
  `../bootstrap/AGGREGATES.md`; the aggregate-storage gate passed 38 groups.
  Validated Array.Length/Memory.CopyBytes bindings and ordinary UBECore
  AppendBytes source now pass the 25-group counted-buffer gate at O0/O2.
  Those counted operations allocate nothing. Dynamic scalar/finite-record
  growth, independent copies and owner-approved original-storage aliases now
  pass the 41-group dynamic-storage gate at O0/O2; see DYNAMIC-STORAGE.md in
  bootstrap for the ownership and allocation boundary.
  Managed text and broader aggregate ownership remain separate dependencies.
  Counted file input/output now adds explicit owned tokens, exclusive creation,
  bounded OS byte packing and ordinary UBECore read/write progress algorithms;
  its gate and limits are in `../bootstrap/FILE-IO.md` and Progress.md.
  The source-scanning dependency now adds Do/Loop, Exit Do, subtraction, Or/Not
  and the first UBE-written scanner with portable UTF-8 validation. Its 82-group
  file/token gate, 42 allocation/depth checks, 37 UTF-8 cases and 13 syntax cases
  pass alongside prior regressions; scope is in SOURCE-SCANNING.md in bootstrap.
  The UBE-written module parser now retains indexed syntax trees and parses
  actual compiler/library modules, including its own source. Its storage
  dependency admits 1 MiB sources/arrays and 65,536 tokens/nodes, with bounded
  transfer buffers and checked allocation quotas. Contracts and limits are in
  bootstrap/MODULE-PARSING.md; exact native evidence is in Progress.md.
  UBE-written project storage and declaration binding now retain ordered module
  pools and resolve scoped symbols, declared types, procedure signatures and
  executable entry identity. Native acceptance covers real compiler modules,
  nominal recursive references, malformed input, symbol limits and preserved
  results after failure; scope is in bootstrap/DECLARATION-BINDING.md.
  Next implement expression/reference binding and checked constant evaluation
  over these declaration identities, measuring any additional source-language
  dependencies before extending the same bootstrap. Keep primitive authority,
  aggregate layout and lowering explicit separate responsibilities; declaration
  success alone does not establish complete program validity.
- [ ] Compile the UBE-written compiler and rebuild it with its own output.
  Compare deterministic generated artifacts and run the same conformance
  corpus with both generations before claiming self-hosting.
- [ ] Implement and qualify concurrent compilation in the UBE-written compiler:
  execute independent project work in parallel, isolate simultaneous requests,
  and pass the concurrency gate in ACCEPTANCE.md. Preserve the same semantics
  and deterministic results in single-worker and multi-worker execution.

## Complete language and product support

- [ ] Implement the frozen grammar and semantic contracts, with ordinary
  algorithms in UBE libraries and only irreducible operations as intrinsics.
- [ ] Prove managed memory, checked arithmetic, conversions, native threads,
  object/event lifetimes and foreign boundaries with focused acceptance tests.
- [ ] Deliver source-level debug information and compiler services for the
  native IDE, using the compiler's required thread-safe parallel implementation.
- [ ] Qualify optimization, diagnostics, malformed-input recovery and target
  portability independently; LLVM target availability alone is not evidence.
- [ ] Meet release requirements, sample requirements and offline documentation
  coverage, with implemented and planned behavior clearly distinguished.

The immediate task and exact evidence belong in [Progress.md](Progress.md).
