# UBE compiler roadmap

The owner authorized a restart on 2026-11-10. This plan preserves the approved
UBE language and minimal compiler/library boundary. It does not carry forward
completion claims from removed implementations.

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
- [ ] Compile the UBE-written compiler and rebuild it with its own output.
  Compare deterministic generated artifacts and run the same conformance
  corpus with both generations before claiming self-hosting.

## Complete language and product support

- [ ] Implement the frozen grammar and semantic contracts, with ordinary
  algorithms in UBE libraries and only irreducible operations as intrinsics.
- [ ] Prove managed memory, checked arithmetic, conversions, native threads,
  object/event lifetimes and foreign boundaries with focused acceptance tests.
- [ ] Deliver source-level debug information, compiler services and
  thread-safe parallel compilation for the native IDE.
- [ ] Qualify optimization, diagnostics, malformed-input recovery and target
  portability independently; LLVM target availability alone is not evidence.
- [ ] Meet release requirements, sample requirements and offline documentation
  coverage, with implemented and planned behavior clearly distinguished.

The immediate task and exact evidence belong in [Progress.md](Progress.md).
