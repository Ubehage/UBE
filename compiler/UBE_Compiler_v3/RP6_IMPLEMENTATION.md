# RP6 implementation contract

This file is the resumable engineering plan for Release Preview 6. The
normative behavior remains in `../../lang-doc/`; this document maps that frozen
behavior to compiler, linked-support, source-library, and test deliverables.

RP6 is complete only when every gate below passes through both the v2-built and
self-built v3 compiler. Parser or semantic acceptance without linked native
behavior is not completion.

## Existing baseline

- RP5 provides bounded typed IR, verification, deterministic LLVM, a compiler-
  owned Clang handoff, and a byte-identical self-build fixed point.
- The grammar recognizes class, interface, property, `Implements`, `New`,
  `As New`, `Set`, `Nothing`, `Variant`, `Empty`, and `Null` forms.
- Semantic types already reserve scalar, object, Variant, null-state, fixed-
  string, array, custom-type, enum, and interface identities.
- Current linked support owns temporary strings and arrays in an exit-time
  allocation list. It is not a tracing collector and does not yet expose
  precise roots, barriers, safe points, finalization, or external leases.
- Project manifests parse `Reference` entries but do not retain or load their
  paths. Library projects are analyzed but do not yet emit the frozen exported
  ABI or a shared-library product.

## Slice A: precise managed IR and metadata

- [x] Add bounded target-independent records for managed layouts, reference
  slots, roots, safe points, barriers, pins, and finalizers.
- [x] Classify strings, object/interface references, Variants, arrays with
  managed elements, and recursive custom-type edges without recursive compiler
  traversal or raw target pointers.
- [x] Emit deterministic target layouts and LLVM metadata/tables from the
  verified records; reject a managed store lacking its barrier.
- [x] Publish roots before allocation, calls, loop backedges, explicit
  collection, waits/callbacks when those later become available, and foreign
  transitions.
- [x] Add deterministic dump/golden coverage plus malformed-metadata verifier
  tests.

Gate A: v2-built and self-built compilers emit byte-identical managed metadata
for scalar-free, nested, recursive, array, Variant, local, global, Static,
parameter, result, and temporary fixtures while retaining the RP5 fixed point.

## Slice B: managed values and conversions

- [x] Replace temporary string/array ownership with collector allocations and
  precise element-layout descriptors.
- [x] Implement recursive custom-type fields as lazy hidden managed edges;
  reading or writing allocates exactly the accessed depth.
- [x] Implement independent custom-value and array assignment with range
  barriers and correct removal cleanup for `ReDim Preserve`.
- [x] Implement fixed-string width, padding, truncation, copying, and comparison.
- [x] Implement the frozen Variant payload/tag model plus `Empty`, `Null`, and
  `Nothing` distinctions.
- [x] Implement all checked conversions in `conversion-table.md`, including
  compile-time rejection and neutral-value plus error-state runtime failure.

Gate B: native fixtures prove value independence, recursive lazy allocation,
managed nested copies, fixed strings, Variant type preservation, Null
propagation, Empty conversions, and every conversion-table cell used by RP6.

## Slice C: object and module lifecycle

- [x] Create semantic class/interface identities from `.cls`, `.frm`, and
  `.ctl` envelopes; validate `Implements`, properties, signatures, and object-
  only `New`/`As New`/`Set`/`Nothing` rules.
- [x] Lower object allocation, identity assignment, lazy `As New`, dispatch,
  module singleton identity, and dependency/source-order initialization.
- [x] Generate exact-once `Class_Initialize`/`Class_Terminate` and parameterless
  module initialize/terminate hooks with reverse partial-failure unwind.
- [x] Reject resurrection, disconnect future callbacks before termination, and
  retain storage until admitted calls drain. Event execution remains RP7.

Gate C: native fixtures prove shared object identity, lazy construction,
interface/property dispatch, deterministic initialization order, exactly-once
termination, cycle finalization, and partial-construction unwind.

## Slice D: references, libraries, and foreign ownership

- [x] Retain normalized `Reference` paths, load the complete acyclic source-
  project graph, diagnose duplicates/name collisions/cycles, and expose only
  direct public declarations to lookup.
- [x] Emit `Kind = "Library"` shared output, versioned ABI metadata, generated
  C declarations, fixed status-returning entry thunks, and bounded diagnostic
  retrieval for the frozen `Public Export` subset.
- [x] Implement generation-checked object/module handles, independently counted
  leases, idempotent release, identity-wide self-unload invalidation, and
  orderly library shutdown with active-call draining.
- [x] Never expose moving addresses or host C `long`; custom values cross by
  independently copied opaque handles and schema identity.

Gate D: an external C fixture loads the library, validates metadata, calls
exports, copies/releases values, exercises multiple object leases and stale
handles, and shuts down cleanly. Invalid pointers, lengths, versions, targets,
and handles return controlled statuses.

## Slice E: collector and UBECore

- [x] Implement an iterative precise tracing collector with bounded work state,
  automatic pressure scheduling, one retry after collection, cycle recovery,
  finalization queue, pins, and coordinated safe-point state.
- [x] Implement synchronous `CollectGarbage() As Long`, returning 1 only when
  work was performed and 0 when nothing was ready.
- [x] Add documented UBECore modules organized by responsibility for managed
  memory, conversions, strings, variants, and errors. Every public declaration
  must follow `source-library/AGENTS.md` comment requirements.
- [x] Confirm collector shutdown never assumes ownership of user-opened files,
  sockets, handles, or other external resources.
- [x] Add deterministic allocation-failure injection for retry, partial
  construction, finalizer bookkeeping exhaustion, and controlled fatal-path
  tests.

Gate E: repeated stress covers every root class, deep and cyclic graphs,
barriers during copies, exactly-once finalization, forbidden resurrection,
pin expiry, external leases, automatic and explicit collection, low-memory
retry, orderly shutdown, and concurrency-safe invariants without yet adding
the RP7 thread surface.

## Final release gate

- [x] Run the complete clean RP1-RP5 suite unchanged.
- [x] Build v3 and the exact UBECore slice with preserved v2, then repeat both
  builds with self-built v3 under the documented deterministic comparison.
- [x] Run identical RP6 positive, negative, low-memory, ABI, lifetime, and
  stress corpora through both compiler stages.
- [x] Record exact inputs, tools, comparison policy, corpus results, and
  artifacts in `bootstrap/out/v3-rp6-build-manifest.json`.
- [x] Update public status/handoff documents and preserve the verified RP6
  executable plus SHA-256 under `compiler/release-previews/`.

## Completion record

Completed on 2026-10-21. The clean build manifest is generated at
`bootstrap/out/v3-rp6-build-manifest.json`; the preserved release executable
and checksum are in `compiler/release-previews/`. RP7 begins from this fixed
self-hosting and managed-runtime baseline.
