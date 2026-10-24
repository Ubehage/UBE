# Compiler v3 RP8 implementation and gate

RP8 closes the frozen UBE 1.0 surface without weakening the RP7 fixed point.
All generated test and compiler artifacts remain under `bootstrap/out/` until
the final verified executable is preserved in `compiler/release-previews/`.

## Slice A — project and target controls

- [x] Accept deterministic `Optimization = "0|1|2|3|Size"` and
  `DebugInformation = "None|Line|Full"` project settings.
- [x] Load bounded `UBE-ProjectGroup 1` manifests, reject unsafe or repeated
  paths, and analyze every project independently in manifest order.
- [x] Freeze x86-64 Linux ELF as the second code-generation target and verify
  that Clang accepts the emitted object.
- [x] Add all focused gates to the clean bootstrap build.

## Slice B — resources and compiled libraries

- [x] Freeze `UBE-Resource 1` as a 64 MiB, 1024-entry maximum, canonical
  little-endian container with sorted portable names, contiguous payloads,
  and a SHA-256 digest for every entry.
- [x] Provide an atomic deterministic writer and a bounded compiler-side
  validator; malformed, truncated, non-canonical, oversized, and hash-mismatched
  input is rejected without exposing partial data.
- [x] Freeze and implement the `.UBL` compiled-library bundle specialization,
  including semantic version, public-interface hash, intrinsic ABI, target,
  object format, and artifact identity.
- [x] Add source-plus-bundle fixtures for accepted, corrupt, and wrong-target
  containers.
- [x] Add consumer-declared semantic-version/interface requirements and
  incompatible-version, interface, and dependency-graph fixtures.

## Slice C — remaining source behavior

- [x] Preserve generated foreign ABI declarations and give foreign imports and
  `AddressOf` stable targeted diagnostics until their native lowering exists.
- [x] Verify `Inline`; give variable hooks and `ForceInline` their frozen
  targeted diagnostics where lowering or hygienic expansion cannot be guaranteed.
- [x] Gate unsafe assembly and bytecode explicitly. RP8 has no unsafe-enabled
  build context, so both forms deterministically reject with `UBE4030`.
- [x] Add targeted diagnostics for portable-code host-clock assignment and the
  reserved classic graphics statements.
- [x] Derive an executable closure matrix for every remaining grammar and
  semantic contract, with explicit diagnostics for intentionally unsupported
  UBE 1.0 compatibility forms.

## Slice D — debugger, library, and release proof

- [x] Verify full compile-unit, file, procedure, instruction, and variable
  debugger metadata under every debug level.
- [x] Complete and document the minimum `UBECore` API used by all conformance
  examples, keeping platform adapters separate.
- [x] Repeat v2-built/self-built LLVM and normalized-object comparison, exact
  library-slice comparison, all inherited corpora, malformed inputs, Windows
  native execution, and Linux ELF emission.
- [x] Preserve the verified RP8 executable and SHA-256, then update status
  documentation only from the clean manifest.

## Decisions

- Legacy `Date = ...` and `Time = ...` host-clock mutation is rejected in
  portable UBE 1.0 source. A future permission-aware platform library may
  expose clock mutation explicitly.
- `Circle`, `Line`, `PSet`, and `PaintPicture` remain reserved compatibility
  syntax. Portable graphics are ordinary calls in a separately linked library.
- Compiler v2 receives only the compiler-intrinsic declaration/mapping needed
  to bootstrap v3's bounded binary validator. Container policy and parsing stay
  in v3 and its linked compiler substrate.

## Exact next action

Begin Beta 1 with the deterministic compiler parallelization plan while
retaining the sequential v2 bootstrap seed and every RP8 release gate.
