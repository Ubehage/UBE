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
- [ ] Test self-compilation and library recompilation whenever the preview is
  capable of them; do not make premature self-hosting a prerequisite.
- [x] Prevent RP1 from silently depending on later APIs by recording an empty
  `source_library_slice` in its build manifest.

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

- Active compiler preview: RP3, built by both preserved v2 stages.
- Selected callable modules: none.
- Boundary-only module: `src/portable/CoreIdentity.bas`.
- Intrinsic dependencies: none from `UBECore`; RP1 compiler bootstrap
  intrinsics are recorded separately as `ube-intrinsic-abi-1`.
- Verification: `bootstrap/build.ps1`; RP3 parses `UBECore.UBE` and records
  all identities in its generated build manifest.
- Known failures: none.
- Exact next action: derive the first non-empty library slice only when RP4 or
  a later preview proves it needs a public operation.
