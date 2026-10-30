# UBE source-library roadmap

Status markers: `[ ]` pending, `[~]` active, `[x]` verified, `[!]` blocked.

## 0. Establish the boundary

- [x] Create a root-level directory separate from compiler generations.
- [x] Record dependency, portability, ownership, and preview rules.
- [x] Resolve the canonical core-library package identity as `UBECore` in
  `../lang-doc/deferred-questions.md`.
- [x] Freeze the semantic-version plus exact public-interface-hash
  compatibility model and the RP1 identities in
  `../project-docs/versioning.md`.
- [x] Create `UBECore.UBE` with its API-empty `CoreIdentity` module before any
  public implementation source is added.

## 1. Compiler-preview subset

- [x] Derive the minimum APIs needed by RP1: the slice is intentionally empty
  because the project-validation shell needs no public library operation.
- [ ] Assign every API to a meaningfully named functional module and keep its
  filename, `UBE_Name`, manifest entry, tests, and documentation consistent.
- [ ] Require declaration comments for every library procedure and focused
  rationale comments for complex algorithms, invariants, portability choices,
  failure handling, and cleanup paths.
- [ ] Separate ordinary UBE procedures from unavoidable compiler intrinsics.
- [ ] Define each public declaration, failure result, ownership rule, thread
  behavior, and platform availability before implementation.
- [ ] Implement the portable subset in UBE and target adapters only where
  required.
- [ ] Build the subset with the same trusted compiler that builds the preview.
- [ ] Add focused positive, boundary, malformed-input, and environmental-
  failure tests.
- [ ] Review source comments with each module: descriptions must still match
  the declarations, implementation, ownership rules, and verified behavior.

## 2. Preview preservation

- [x] Record RP1's empty callable module slice and the non-linked
  `CoreIdentity` project-boundary module.
- [x] Preserve RP1's compiler and library project validation in
  `bootstrap/build.ps1` and `bootstrap/out/v3-rp3-build-manifest.json`.
- [x] Test self-compilation and library recompilation whenever the preview is
  capable of them; do not make premature self-hosting a prerequisite.
- [x] Prevent RP1 from silently depending on later APIs by recording an empty
  `source_library_slice` in its build manifest.
- [x] Compile the RP5 `CoreIdentity.bas` source slice with both the v2-built and
  self-built v3 compiler and require deterministic LLVM and object output.
- [x] Compile the RP6 seven-module portable slice with both compiler stages and
  require deterministic LLVM and object output.
- [x] Add documented modules for runtime intrinsics, conversions, strings,
  managed memory, Variants, and status helpers as required by RP6.
- [x] Compile the RP7 16-module portable slice with both compiler stages and
  require deterministic LLVM and object output.
- [x] Add documented error, thread, atomic, event, semaphore, queue, and
  synchronization modules required by RP7.

## 3. Complete library after Compiler v3 Beta 1

- [ ] Inventory the complete public library surface from the frozen language
  and public documentation.
- [ ] Plan strings, conversions, collections, files, console, dates,
  mathematics, errors, memory, threading, events, processes, networking, and
  platform adapters as small independently testable goals.
- [ ] Establish public API compatibility, deprecation, bug-report, security,
  and release processes.
- [ ] Verify the full library on every claimed target.
- [ ] Publish versioned API documentation only from verified declarations.

## Handoff

- Active compiler preview: RP8, built by preserved v2 and repeated by
  self-built v3.
- Selected callable modules: `Conversions`, `Strings`, `Memory`, `Variants`,
  `Errors`, `Threads`, the four atomic wrappers, `ThreadEvent`, `Semaphore`,
  `MessageQueue`, and `Synchronization`.
- Boundary and intrinsic modules: `CoreIdentity` and `RuntimeIntrinsics`.
- Intrinsic dependencies: none from `UBECore`; RP1 compiler bootstrap
  intrinsics are recorded separately as `ube-intrinsic-abi-1`.
- Verification: `bootstrap/build.ps1`; RP8 compiles `UBECore.UBE` through typed
  IR to LLVM and COFF with both compiler stages, compares the outputs, and
  records all identities in `bootstrap/out/v3-rp8-build-manifest.json`.
- Known failures: none.
- Exact next action: preserve the RP8 slice during Beta 1 hardening and add
  APIs only with complete contracts and cross-stage conformance fixtures.
