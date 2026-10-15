# UBE source-library roadmap

Status markers: `[ ]` pending, `[~]` active, `[x]` verified, `[!]` blocked.

## 0. Establish the boundary

- [x] Create a root-level directory separate from compiler generations.
- [x] Record dependency, portability, ownership, and preview rules.
- [ ] Resolve the canonical core-library package identity in
  `../lang-doc/deferred-questions.md`.
- [ ] Freeze compiler/library compatibility metadata and versioning.
- [ ] Create the checked-in `.UBE` project manifest when its real module list
  and package identity are known; no implementation source may be added before
  the manifest exists.

## 1. Compiler-preview subset

- [ ] Derive the minimum APIs needed by the first Compiler v3 preview.
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

- [ ] Record the exact library module set required by every compiler preview.
- [ ] Preserve successful compiler-plus-library build commands and identities.
- [ ] Test self-compilation and library recompilation whenever the preview is
  capable of them; do not make premature self-hosting a prerequisite.
- [ ] Prevent a preview from silently depending on APIs introduced later.

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

When implementation begins, record the active compiler preview, trusted
compiler artifact, selected library modules, intrinsic dependencies,
verification commands, known failures, and exact next action here.
