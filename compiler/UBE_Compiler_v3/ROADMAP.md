# UBE Compiler v3 roadmap

Status markers: `[ ]` pending, `[~]` active, `[x]` verified, `[!]` blocked.

## 0. Freeze the target

- [x] Create the generation directory, matching project manifest, and startup
  module.
- [x] Record the minimal-compiler, separate-library, and portable-platform
  architecture.
- [x] Complete and freeze the UBE 1.0 core language definition and grammar.
  The final completeness audit, conditional directive grammar, and initial
  conformance corpus are preserved under `../../lang-doc/`.
- [x] Resolve every core owner-level decision in the v3 language-definition
  draft. Architecture choices intentionally reserved for later resolution are
  isolated in `../../lang-doc/deferred-questions.md`.
- [x] Freeze the conversion, managed-memory, foreign-ABI, and threading
  contracts in focused staging documents.
- [x] Stage the approved syntax changes as an exact grammar delta.
- [x] Merge the staged contract into the normative specification and grammar.
- [~] Derive executable conformance cases from every normative rule.

## 1. Prove the bootstrap scaffold

- [x] Add the v3 scaffold build to the automated bootstrap harness.
- [x] Compile the v3 project with both preserved v2 stages and compare IR.
- [x] Link and execute the scaffold outside the source directory.
- [x] Record source, v2 compiler, runtime, target, tool, flag, and artifact
  identities.

## 2. Establish portable compiler foundations

- [ ] Split the compiler into ordered v2-compatible source modules.
- [ ] Implement bounded source/project ownership and stable diagnostics.
- [ ] Define host and target descriptions without Windows assumptions in core
  phases.
- [ ] Define and verify versioned compiler/core-library metadata.
- [ ] Build the target-independent type and IR contracts.

## 3. Implement the UBE 1.0 front end

- [ ] Implement the frozen grammar with bounded recovery.
- [ ] Implement declarations, scopes, frozen lookup/ambiguity rules,
  visibility, and modules. UBE 1.0 has no user-defined procedure overloading.
- [ ] Implement scalar, object, array, recursive custom-type, and callable
  typing.
- [ ] Implement the normative implicit-conversion matrix.
- [ ] Implement `CallNew`, regular `LongLong` thread identifiers, thread-safe
  argument capture, and
  event-source liveness semantics.
- [ ] Reject every unsupported or unsafe construct before lowering.

## 4. Implement verified IR and LLVM lowering

- [ ] Lower all accepted behavior into typed, target-independent IR.
- [ ] Verify types, ownership, references, CFG edges, failure paths, and source
  locations before backend entry.
- [ ] Implement target ABI descriptions and deterministic LLVM emission.
- [ ] Emit managed-reference layout and debug metadata.
- [ ] Validate generated IR and report tool failures without partial success.

## 5. Build the separate core library and platform substrate

- [ ] Define the minimal versioned intrinsic ABI.
- [ ] Build portable UBE core-library modules under
  `../../source-library/`, separately from the compiler.
- [ ] Implement the first Windows platform substrate behind portable APIs.
- [ ] Implement conversions, managed recursive references, thread operations,
  event-source registration, and thread-local `Err`.
- [ ] Implement tracing garbage collection with verified roots, type-layout
  metadata, safe points, barriers, cyclic-graph reclamation, and controlled
  low-memory behavior.
- [ ] Audit the compiler and libraries for explicit external-resource cleanup
  on success, error, cancellation, and early-exit paths.
- [ ] Add a second OS target before claiming full portability.

## 6. Self-host and release-gate v3

- [ ] Make v2 compile the complete v3 source and the required
  `../../source-library/` subset.
- [ ] Make v3 compile the identical source set to the next stage.
- [ ] Pass deterministic compiler and library comparison policies.
- [ ] Pass language, conversion, recursive-type, threading, event-lifetime,
  platform, ABI, malformed-input, and environmental-failure suites.
- [ ] Preserve and run v1 and v2 verification in the authoritative build.
- [ ] Publish the supported host/target matrix and bootstrap trust record.

V3 is ready only when the frozen UBE 1.0 contract is implemented and verified;
self-hosting alone is necessary but not sufficient.
