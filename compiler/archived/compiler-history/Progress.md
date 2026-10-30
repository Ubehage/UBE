# UBE compiler progress

This file is the short handoff record for the active item in
`compiler/Roadmap.md`. Update it while working; do not use it as a second
roadmap.

## Current position

**Owner direction — 2026-10-30:** further compiler feature expansion is
deferred while a fresh UBECore is established in `../std-lib/`. The previous
library is preserved under `../archive/source-library/`. Resume from
`../std-lib/ROADMAP.md`; the milestone, next actions, and verification entries
below are historical handoff material, not the active assignment.

- Active milestone: **Compiler v4 compact parser and recovery**.
- Active item: **begin Task 5 from the verified Task 4 lexical pipeline**.
- Status: v3 Beta Phase 5 is closed as an optimization line. Its verified
  self-host fell from 800.730 seconds to 400.656 seconds after removing major
  repeated whole-program work, but its Phase 3/4 worker transport and coupled
  data distribution are not a suitable foundation. V3 is preserved as the
  executable UBE 1.0, diagnostic, ABI, package, test, and bootstrap oracle for
  v4. Tasks 0 through 4 are complete under `UBE_Compiler_v4/`; the production
  compiler adds immutable multi-source loading, preprocessing, and full lexing.
- Blockers: none. Task 5 may broaden the compact parser and recovery from the
  verified lexical and phase contracts. Linux runtime execution is
  still not claimed; v3 RP8 verifies the non-Windows boundary through LLVM and
  a Clang-accepted ELF object.

## Latest verification

- 2026-10-27: completed Compiler v4 Task 4. The v3-built native compiler
  matched the full RP2 lexical corpus and a multi-source conditional project,
  rejected malformed UTF-8, preprocessing, paths, dates, numbers, controls,
  and limits without a runtime bounds failure, and passed deterministic
  100/1,000/5,000-statement scaling evidence.

- 2026-10-27: completed Compiler v4 Task 3. The v3-built native compiler emits
  deterministic LLVM and seven phase dumps for a minimal `Sub Main`, matches
  v3 native behavior, rejects malformed inputs and all envelope mutations, and
  passes a 100,000-byte stress case without false-success artifacts.

- 2026-10-27: completed Compiler v4 Task 2. Preserved v3 builds the production
  `UBE_Compiler_v4.UBE` manifest and native `Main.bas` shell. Its complete
  frozen limits and sealed `ByVal` session envelopes feed sequential fake load,
  frontend, and tool adapters with stable diagnostics, sticky cancellation,
  explicit result release, stale-output removal, and atomic record publication.
  Thirteen validated case manifests ran in 15 native executions, covering
  positive startup/publication, exact 4096/4097-byte argument boundaries,
  invalid usage/target, empty/missing input, injected allocation/tool/write/
  cancellation failures, host cleanup rejection, repetition, and false-output
  cleanup. Repeated shell LLVM and published record bytes were identical. The
  cumulative Task 0/1/2 gates and all 221 grammar productions passed.

- 2026-10-27: completed Compiler v4 Task 1. The exact facility ownership and
  bootstrap dependencies are frozen in `UBE_Compiler_v4/TASK1_DEPENDENCIES.*`.
  The independent `UBECompilerSupport` 0.1.0-v4t1 project adds bounded text,
  portable relative paths, deterministic record fields, arguments,
  measurements, required-file I/O, atomic publication/cleanup, and
  separate-argument process execution without shared mutable module state.
  The focused gate compiled both UBECore and compiler support with preserved
  v3, repeated support LLVM deterministically, and passed native API,
  two-thread reentrancy, and I/O/process cleanup fixtures. Its 13 private hooks
  are existing `ube-intrinsic-abi-1` names; no intrinsic was added.

- 2026-10-27: completed Compiler v4 Task 0. The dependency-minimal
  `UBE-Test-Case 1` input format, cumulative runner contract, and generated
  `ube-v4-verified-build-1` evidence format are frozen. A compiled C++17
  non-production probe compared a full table syntax form with the selected
  selective hybrid representation over valid, malformed, depth 32/65, and
  100/1,000/5,000-statement inputs. Three repetitions preserved exact counters,
  spans, normalized meaning, and diagnostics; both modes matched v3 acceptance
  on the checked-in differential fixtures and stayed within the 1.20
  work/token scaling bound. On 30,025 tokens the hybrid used 240,060 syntax
  bytes versus 1,000,596. Task 0 also froze phase envelopes, one-based owner-
  local IDs, deterministic merges, initial compatibility limits, diagnostic
  comparison, complete first-slice dependency ownership, and rejected
  alternatives in `UBE_Compiler_v4/TASK0_DECISIONS.md`. The runner proved
  cleanup under injected publication failure and produced its verified record
  beneath `bootstrap/out/v4-task0/`. No production compiler or bootstrap source
  changed.

- 2026-10-27: the owner required every v4 roadmap step and every claimed
  working compiler build to pass small purpose-built positive, rejection,
  boundary, stress, failure, regression, differential, native, and determinism
  programs plus the cumulative earlier suite. The v4 verified-build policy now
  requires an exact generated evidence record; compilation alone is never a
  completed gate.

- 2026-10-27: the owner approved the proposed v4 Task 0 direction, including
  the reuse policy, ownership model, measured parser decision, library and
  compiler-support split, deterministic identity rules, performance and
  parallelism rules, bootstrap chain, deliverables, and exit gate. This
  authorizes bounded prototype work, not production scaffolding.

- 2026-10-27: drafted the Compiler v4 planning boundary. Added a proposed
  ownership/phase design, explicit v3 reuse/retire matrix, library-extraction
  candidates, an ordered 14-task roadmap, and task-specific agent instructions.
  The owner subsequently approved this direction for bounded Task 0 prototype
  work. No compiler source, project manifest, bootstrap script, or
  source-library implementation changed as part of the v4 draft.

- 2026-10-26: completed the bounded v3 Phase 5 investigation. Indexed IR edge
  verification, canonical function-range LLVM emission, indexed safe points,
  and numeric grammar-rule dispatch reduced the verified production self-host
  from 800.730 seconds to 400.656 seconds. Seed-built and self-built LLVM are
  byte-identical with SHA-256
  `C80FC435047E1B31BE8296EC54115BEE797022F8BE67B41ACEE46747F41D318C`.
  Normal Phase 3/4 worker activation remains suspended because private grammar,
  token, syntax, and semantic-universe transport costs exceed useful work. The
  detailed handoff is `UBE_Compiler_v3/performance/PHASE5_INVESTIGATION.md`.

- 2026-10-25: completed Beta 1 multithreading Phase 2. Added the v2-compatible
  bounded task/executor coordinator, logical worker registration, worker-owned
  result arena, cancellation/drain contract, deterministic merge, default and
  explicit `--jobs 1`, controlled rejection of larger counts, and injected
  `UBE5301` through `UBE5305` failure gates. The clean `bootstrap/build.ps1`
  gate passed in 3,484 seconds. Both Compiler v2 stages emitted seed LLVM
  `062F8BE9AADC68A23E44A4510A7F89A4A1AC37F6103D9C27E9D0CB9CABA49E99`;
  production stages two and three emitted identical LLVM
  `C0BDD103E39E227346B64578AEFD4A53225ABC96C6FC9DF14728151F0E4F2979`;
  their normalized objects both hash to
  `3EDAF4E414F5954092D35BF9943DA2B0F8EA5D6B45D812414C644C9B9FAADCFD`.
  Explicit `--jobs 1` matched default LLVM byte for byte, all five injected
  failures returned controlled diagnostics, merge failure removed its produced
  output, all owned worker/capture/arena state drained, and the complete
  50-case corpus and inherited RP8 gates passed.

- 2026-10-25: completed Beta 1 multithreading Phase 1. Added the permanent
  `UBE_Compiler_v3_seed.UBE` manifest and documented its production-only
  dependency boundary in `UBE_Compiler_v3/BOOTSTRAP_SPLIT.md`. A clean
  `bootstrap/build.ps1` run passed in 3,363 seconds. Compiler v2 stages one and
  two emitted identical seed LLVM
  `DFFDF03BBC62163F991E35692269EBB63063F51A496B7EF958FC26442FBA5D3D`.
  The seed-built production stage one and production stages two and three all
  emitted LLVM
  `5534121A8D3643210CAB2EF6AEB9E0D4E9E8DA3B85A20EAFCC36FCB9C08C9C32`;
  normalized stage-two/stage-three objects both hash to
  `38117ACAE7CA541548A19FB2818EB81AE630F0058C575ADCA16FF27A8F979C10`.
  The 50-case corpus and every inherited RP8 gate passed. Moving the corpus to
  the seed-built production compiler exposed a production-only parser stack
  overflow on the existing 800-parenthesis fixture. A v2-compatible token-level
  precheck now accepts the verified 10-level boundary and returns controlled
  `UBE3701` for level 11 and the former crash case. The generated trust record
  is `bootstrap/out/v3-beta1-build-manifest.json`; it identifies
  `ube-v3-sequential-seed-1`, `ube-v3-sequential-executor-1`, and one requested
  and effective job.

- 2026-10-25: completed Beta 1 multithreading Phase 0. Added the opt-in
  `--profile` compiler mode and a reproducible three-run harness. On the
  32-logical-processor Ryzen 9 3950X host, the sequential production compiler
  self-build median is 640,351 ms wall, 637,906 ms CPU, and 1,068,956 KiB peak
  working set. The 512-procedure fixture fell from 34,840 ms to 14,935 ms after
  bounded scope/name, owner/child, and default-form indexes removed measured
  superlinear scans; its semantic and IR-lowering series now doubles
  approximately linearly. All repeated LLVM outputs matched. Full hardware,
  toolchain, phase, size, input-hash, and output-hash evidence is in
  `UBE_Compiler_v3/performance/PHASE0_BASELINE.md`. The final clean
  `bootstrap/build.ps1` gate passed in 2,069 seconds: stage-two/stage-three LLVM
  both hash to
  `2BEF942837A1C95B46F8EAFAE1D445665C7CC1FBE4E8C57A18AF3C8E35845687`,
  normalized COFF objects both hash to
  `29614DD067CAA284672605EF77A501591C90EF9C8C64B76441E4950E893AC74F`,
  all 50 corpus cases pass, and profiled/unprofiled fixture LLVM is identical.

- 2026-10-24: completed Compiler v3 Release Preview 8. A clean
  `bootstrap/build.ps1` run passed with LLVM/Clang 23 targeting Windows x86-64
  and the Linux x86-64 ELF object boundary. Stage-two and stage-three compiler
  LLVM are byte-identical; normalized COFF and the 16-module `UBECore` outputs
  match; 50 cross-stage corpus cases pass. The build also verifies `.UBG`,
  `.UBR`, `.UBL` compatibility, all debugger and optimization modes, RP8
  compatibility diagnostics, Windows native execution, and the public core API.
  The manifest is `bootstrap/out/v3-rp8-build-manifest.json`; the preserved
  executable SHA-256 is
  `D9F854F914D99F90B92CB69F8146E6C318F61D437B0792DB19DCE80B69C8C00D`.

- 2026-10-23: completed Compiler v3 Release Preview 7. A clean
  `bootstrap/build.ps1` run passed with LLVM/Clang 23.1.3 targeting
  `x86_64-w64-windows-gnu`. The fixed-point compiler emitted byte-identical
  stage-two/stage-three LLVM and matching timestamp-normalized COFF; both
  compiler stages emitted identical LLVM and objects for the 16-module
  `UBECore` slice and agreed on 49 recorded corpus cases. Native probes cover
  independent error records, thread lifecycle/failure injection, reentrant
  monitors, atomics, waits, semaphores, FIFO queues, recursive/mutating events,
  dispatcher-cycle rejection, load rollback, component draining, startup and
  default forms, control parents, cancellation, and GC interaction. The build
  record is `bootstrap/out/v3-rp7-build-manifest.json`; the verified executable
  and SHA-256 are preserved under `compiler/release-previews/`.

- 2026-10-21: audited the frozen RP7 contracts and divided implementation into
  six executable slices in `UBE_Compiler_v3/RP7_IMPLEMENTATION.md`. The one
  default-form behavior that conflicts with UBE's no-hidden-reconstruction rule
  remains recorded in `lang-doc/deferred-questions.md`; RP7 will implement
  explicit `Load FormName` without silently choosing bare post-unload
  recreation. Work begins with the shared thread-local error substrate needed
  by every later thread, wait, callback, and unload failure path.

- 2026-10-21: completed Compiler v3 Release Preview 6. A clean
  `bootstrap/build.ps1` run passed with LLVM/Clang 23.1.3 targeting
  `x86_64-w64-windows-gnu`. The self-build reached byte-identical LLVM and
  equal normalized COFF objects; both compiler stages reproduced the
  seven-module `UBECore` slice and agreed on all 28 recorded corpus cases.
  Native coverage includes recursive lazy custom values, independent copies,
  fixed strings, Variants, object/interface/property dispatch, exact-once
  lifecycle hooks, deterministic module ordering, direct project references,
  tracing collection, cycle recovery, low-memory paths, and external library
  leases. The generated C header passed strict C17 validation and the external
  DLL probe passed. Reproducibility details are in
  `bootstrap/out/v3-rp6-build-manifest.json`; the release executable is
  preserved under `compiler/release-previews/`.

- 2026-10-19: audited the frozen RP6 contracts against the RP5 compiler and
  linked support. The grammar and semantic type table recognize much of the
  surface, but class identities, retained project references, managed IR
  metadata, tracing ownership, shared-library output, foreign leases, and
  callable UBECore modules remain distinct implementation layers. The ordered
  executable gates are recorded in
  `compiler/UBE_Compiler_v3/RP6_IMPLEMENTATION.md`; implementation begins with
  verifier-owned precise metadata before collector integration.
- 2026-10-19: implemented the first RP6 Slice A records and verifier. The
  v2-built and newly self-built v3 compilers produce identical deterministic
  `--dump-managed` output for a fixture containing a recursive custom value,
  a managed string field, a dynamic string array, and a Variant. The dump
  identifies the recursive lazy slot, reference slot, roots, allocation safe
  point, and managed-store barriers. Added a separate linked-support tracing
  probe covering precise roots, a two-object unreachable cycle, iterative
  reclamation, barriers, exactly-once finalization, and rejected resurrection.
  The tracing allocation path deliberately remains separate from RP5 string
  and array ownership until compiler-emitted root entry/leave calls are wired.

- 2026-10-19: a clean `bootstrap/build.ps1` run completed the RP5 gate with
  LLVM/Clang 23.1.3 for `x86_64-w64-windows-gnu`. V2-built and self-built v3
  emitted byte-identical compiler LLVM; their COFF objects matched after only
  the four-byte producer timestamp was normalized. Both stages agreed on all
  18 recorded corpus cases, including native output and exit codes. Both also
  emitted identical LLVM and objects for the `UBECore` slice
  `src/portable/CoreIdentity.bas`. The gate covered compiler-owned
  `--build-native`, debug line metadata, automatic local dynamic-array cleanup,
  and controlled arithmetic, bounds, tool, and output failures.
- Generated reproducibility record:
  `bootstrap/out/v3-rp5-build-manifest.json`.

- 2026-10-16: `lang-doc/tools/validate-grammar.ps1` passed with 202 core and
  19 conditional productions.
- 2026-10-16: a clean `bootstrap/build.ps1` run passed lexer, parser,
  semantic, codegen, native, v1, v2, RP1, RP2, and RP3 gates. Both v2 stages
  emitted byte-identical RP3 LLVM. The linked compiler parsed its own 18
  modules, the multi-module fixtures, `UBECore`, comprehensive UBE syntax, and
  legacy designer sources. Syntax dumps were deterministic; every parser-owned
  production was exercised; scanner-owned lexical productions retained RP2
  coverage; recovery emitted multiple bounded diagnostics; excessive nesting
  returned `UBE3701` without uncontrolled termination.
- Generated reproducibility record:
  `bootstrap/out/v3-rp3-build-manifest.json`.
- Stable RP0 through RP3 executables are preserved under
  `compiler/release-previews/` with SHA-256 hashes. RP0 through RP2 were rebuilt
  from their exact completion commits; all four preserved executables pass
  their preview-appropriate smoke tests.

## Verified baseline

- `UBE_Compiler_v1` is preserved with a matching project manifest and
  `Main.bas` startup module.
- Stage zero compiles v1 into the stage-one executable.
- Stage one emits LLVM IR for both checked-in showcase programs.
- Both showcase programs link and run with their expected output and exit code.
- V1 has automated negative coverage for malformed supported shapes, invalid
  arguments, source read failure, and output write failure.
- Dynamic arrays of compiler-defined records and explicit `ByRef` dynamic-array
  parameters are implemented and covered by native tests.
- The v2 design boundary, project, initial driver, and positive showcase tests
  exist. Stage zero builds v2 and the resulting executable emits working LLVM
  IR for both entry-point forms.
- V2 tokenizes its input into flat token records before recognizing the current
  showcase subset, and emits LLVM through joined text chunks. The new bounded
  join primitive has semantic, lowering, runtime, and native coverage.
- V2 discovers `Sub Main`/`Function Main`, `Print`, and function-result
  assignments from tokens with ASCII case-insensitive keyword matching. The
  acceptance input proves it ignores an earlier non-entry procedure's `Print`.
- V2 now has flat source and diagnostic records, strict UTF-8 validation,
  character-aware diagnostic columns, a 16 MiB source limit, a 100,000-token
  ceiling, and controlled diagnostics for lone CR and unterminated strings.
- The bootstrap runtime rejects embedded NUL bytes in text files instead of
  silently truncating them. V2 negative tests verify the exit code, diagnostic,
  and absence of a false-success output artifact.
- The lexer retains raw token spelling separately from decoded values, handles
  apostrophe/`Rem` comments and doubled string quotes, and LLVM emission escapes
  quote, backslash, control, and non-ASCII bytes.
- Entry parsing now produces a bounded `ProcedureSyntax` record and a flat
  `SyntaxNode` for the print expression. Token, syntax-node, diagnostic, and
  generated-output counts have explicit ceilings; token and text storage grow
  geometrically instead of reallocating for every item.
- String literals, parenthesized string expressions, and `&` concatenation now
  parse recursively into syntax nodes and lower from that tree. Function-result
  integer literals and parentheses use the same syntax-node path.
- V2 decodes UTF-8 identifiers and uses the repository's pinned Unicode 18.0
  letter table through a tested bootstrap intrinsic. Explicit continuations,
  including an optional trailing comment and LF/CRLF, are removed lexically.
- Unicode 18.0 simple folding is exposed by code point through the same runtime
  boundary. V2 keyword/name equality now walks UTF-8 scalars and compares their
  folded values rather than applying ASCII-only byte folding.
- V2 structurally collects all module-level procedures, `Type` declarations,
  and fields into geometrically grown bounded tables. It validates terminators,
  dynamic-array field markers, explicit field types, and Unicode-folded
  duplicate procedure/type/field names before entry parsing.
- Procedure headers now populate bounded parameter records with passing mode,
  dynamic-array status, explicit type, and owning procedure. Functions retain
  their result type. A semantic pass resolves exactly one non-intrinsic,
  parameterless `Sub Main()` or `Function Main() As Long`.
- Procedure body scanning now records typed `Dim`/`Static` locals, initializer
  ranges, assignments, and explicit calls. The first body semantic pass rejects
  folded local/parameter collisions, undeclared assignment bases, and unknown
  callees across v2's complete source.
- A general precedence-climbing parser now turns every stored initializer,
  assignment value, and explicit call into flat expression nodes. It supports
  literals, names, unary/binary operators, parentheses, calls/indexing, member
  access, and linked argument lists. Recursive semantic traversal resolves
  names/callees and checks argument counts across v2's own source.
- Expression nodes now receive stable scalar, record, and array type IDs.
  Recursive type resolution covers variables, procedure results, member fields,
  array indexing, calls, operators, and local initializer assignability across
  v2's complete source.
- Assignment targets are parsed as expressions and checked for addressability.
  Calls enforce exact `ByRef`, assignable `ByVal`, Long array indices, and
  callable/indexable bases. Unary/logical operands and symmetric numeric
  promotion are checked. A scalar-call regression guards a formerly reachable
  out-of-range runtime failure.
- Block `If/Else/End If` and `While/Wend` use a bounded explicit matching
  stack. Conditions use the shared expression tree and must be Boolean or
  integral. Structural and condition errors have focused regressions.
- Ordered statement lowering now retains block-local initializers, `ReDim`,
  calls, assignments, printing, exits, branches, and loops. The LLVM backend
  emits every non-intrinsic procedure, records, arrays, exact `ByRef`
  addresses, checked arithmetic, strings, intrinsic calls, and the native
  entry wrapper.
- V2 is self-hosting for its checked-in single-source Bootstrap Profile: stage
  one emits and links stage two, stage two recompiles the same source, and the
  two fixed-point LLVM outputs are byte-identical. Both compiler stages agree
  on the positive and negative v2 corpus.
- V2 loads ordered multi-source `.UBE` projects, normalizes and de-duplicates
  safe relative `.bas` paths, loads each module once, and maps diagnostics back
  to module-local paths and positions.
- A checked-in multi-module program places `Main` before its support module,
  uses a cross-module `Type`, and calls cross-module functions. Stages one and
  two emit identical IR; the linked program prints `multi-module` and exits 7.
- Negative multi-module gates cover an unknown call in the second module,
  duplicate normalized inputs, and a missing second source. Both stages agree
  and leave no false-success artifact.
- The bootstrap build now recreates `bootstrap/out` before every run. The full
  stage-zero, v1, v2, fixed-point, positive, negative, and native suite passed
  on 2026-10-15.

## Next actions

1. Copy the Task 3 packet into `UBE_Compiler_v4/Progress.md` and define the
   smallest real source-to-native fixture and phase dump/validator set.
2. Implement one genuine path through source snapshot, tokens, selective
   syntax, frozen declaration, typed body, verified local IR, LLVM, and native
   execution without broadening the language surface.
3. Preserve the complete v3 fixed point and RP8 corpus as v4 differential and
   bootstrap gates. Do not resume v3 worker expansion unless explicitly asked.

## Decisions in force

- Compiler generations and bootstrap stages are different concepts; see
  `compiler/Roadmap.md`.
- Routine v1 fixes do not create `UBE_Compiler_v2`.
- V2's transition gate is complete; routine public-language growth now belongs
  to v3.
- Previous working generations remain buildable and tested.
- V2 is transitional; v3 is the first public-release target and must be
  developed and compiled with preserved v2.
- V3 is now preserved as the executable reference/bootstrap bridge for v4;
  v4 is a deliberate architectural generation and must be built first with v3.
- The owner approved the v4 planning direction on 2026-10-27. Tasks 0 through
  2 are complete; the production shell and exact dependency boundary are now
  the fixed base for the Task 3 vertical slice.
- Fractional-to-integer conversion uses round-to-nearest, ties-to-even, with
  out-of-range failure. Invariant numeric text parsing trims surrounding
  whitespace, requires a complete match, accepts signs, decimal/exponent
  forms and integer `&H`/`&O`, rejects known-invalid constants at compile time,
  and records controlled failure for invalid runtime text. Boolean conversion
  preserves VB rules: zero/`False` is `0`, nonzero is true, `True` converts to
  `-1`, and text accepts case-insensitive Boolean words or numeric strings.
- Every core numeric type converts implicitly to every other with checked
  range and defined ties-to-even rounding; known failures are compile errors
  and dynamic failures produce neutral values plus `Err`. IEEE special values
  survive `Single`/`Double` and invariant string conversion but fail conversion
  to integer, fixed/decimal, date, or Boolean. `Date` converts implicitly only
  with invariant strings; numeric/Boolean serial-date behavior is explicit
  compatibility-library functionality.
- Integer, `Currency`, and `Decimal` arithmetic is checked: constant overflow
  is a compile error, runtime overflow/divide-by-zero returns neutral zero plus
  `Err`, and wrapping is never implicit. `Single`/`Double` follow IEEE-754,
  producing infinity/`NaN` without `Err`; incompatible later conversion still
  fails under the approved conversion table.
- `And`/`Or` remain eager. `AndAlso`/`OrElse` are Boolean short-circuit
  operators whose skipped operand has no effects. `IsNot` and `Is Not` are
  equivalent negated object-identity comparisons.
- `String * n` always stores exactly `n` characters. Assignment silently
  truncates longer values and right-pads shorter values with spaces; this is
  requested fixed-size behavior, not an error. Reads and copies retain all
  padding characters.
- `Enum` defaults to `LongLong` and may specify only `As Long` or
  `As LongLong`. Members are checked integer constants, omitted values
  auto-increment from zero, and duplicate values are allowed. Enum values act
  as their underlying integer for conversion, assignment, calls, comparison,
  arithmetic, bitwise operations, and numeric string formatting; there is no
  strong enum barrier or `Flags Enum` syntax.
- Arrays use `LongLong` bounds/indices, permit negative lower bounds, and fail
  out-of-range reads/writes safely through neutral result/no write plus `Err`.
  Assignment is an independent value copy; `Erase` unallocates dynamic arrays
  or clears fixed arrays; `ReDim Preserve` may resize any dimension while rank
  and type stay fixed, retaining the coordinate intersection and releasing
  removed managed values.
- String comparison defaults to Unicode-scalar, case-sensitive `Option Compare
  Binary`; `Text` uses versioned locale-independent Unicode case folding.
  Fixed padding participates, each expression uses its containing module's
  mode, locale-aware comparison is explicit library behavior, and legacy
  `Database` comparison is diagnosed as unsupported rather than guessed.
- `Variant` preserves the exact assigned runtime type. Extraction applies the
  ordinary conversion table; custom values require the same declared type and
  objects require a compatible object/class destination. `Empty` converts to
  the destination's neutral value without failure, while `Null` survives only
  in `Variant` and otherwise produces a neutral result plus `Err`. `IsEmpty()`
  and `IsNull()` are standard-library tests.
- Storing a statically object-valued expression in `Variant`, or extracting an
  object from one, requires `Set`. Scalar/value payloads use `=`. Whole-Variant
  `V2 = V1` copies the tag and payload; an object payload becomes another strong
  reference to the same identity, while incompatible extraction yields neutral
  value plus `Err`.
- `Null` propagates through Variant unary/arithmetic/concatenation/comparison
  expressions. Fixed-type use, including an `If` condition, converts to neutral
  plus `Err`; `IsNull()` tests it, `Null Is Nothing` is invalid, and `Empty`
  converts rather than propagates.
- Canonical `Date` text is `YYYY-MM-DDTHH:MM:SS[.fraction]`; date-only values
  use midnight, time-only values use `0001-01-01`, zero fractions are omitted,
  and nonzero fractions trim trailing zeroes through nine-digit precision.
  Core conversion is timezone-neutral and invariant. The standard library must
  separately provide explicit localized parsing, formatting, and timezone
  support without changing source or persistence semantics.
- Custom `Type` declarations have native value semantics. Recursive fields use
  hidden, lazily materialized managed storage: both reads and writes
  materialize only the depth accessed by executed code. `New`, `Nothing`,
  identity tests, and allocation-state queries are not exposed for these
  fields. Assignment creates an independent semantic copy, not a bytewise copy
  of owning managed addresses.
- Custom-type `=` and `<>` are fieldwise value comparisons when every field is
  equality-comparable. Hidden recursive allocation state is unobservable and
  comparison performs no materialization. Ordering is invalid for custom
  types, and `Is` remains restricted to object identity.
- Custom-type assignment independently copies scalars, strings, arrays, nested
  values, and materialized recursive descendants. Object and class fields copy
  the managed reference and therefore continue to identify the same object;
  UBE never implicitly clones an object. Such a containing custom type has no
  automatic `=` or `<>` unless an explicit class value-equality contract is
  defined in the future.
- UBE 1.0 has no public weak-reference or class value-equality facility.
  Ordinary references are strong; classes compare only with `Is`/`Is Not`.
  Public functions return custom datatypes as independent values and objects
  as transferred strong references. Ignored result references are released.
- Objects returned to non-UBE callers use opaque ABI handles backed by explicit
  external ownership leases, never raw GC pointers. They remain resident until
  the lease is explicitly released/unloaded or the library is orderly
  unloaded. Self-unload cleans internal resources and invalidates the token;
  later foreign calls receive controlled status, since UBE cannot clear a
  variable stored in foreign code.
- External leases are counted independently. Releasing one handle preserves
  other leases; an identity-wide self-unload invalidates every handle. Release
  is harmless for an already invalidated token, while all other stale-handle
  operations return controlled ABI status.
- Garbage collection is mandatory and automatic. The standard library also
  provides synchronous `Function CollectGarbage() As Long`; it completes
  collection and eligible termination for the unreachable snapshot without
  affecting reachable objects or their external resources, returning exactly
  `1` when that pass did cleanup and `0` when it did not.
- UBE 1.0 adds no `Try`/`Finally`, `Using`, `Defer`, or resource registry.
  Programmers explicitly close or dispose external resources on relevant paths.
  Host process teardown reclaims remaining handles but does not guarantee UBE
  buffer flushing or execution of user cleanup code.
- Object/class/form/control reference assignment requires `Set`; plain `=` is
  value assignment. `As New` constructs immediately when its declaration is
  reached (module initialization for globals, first declaration execution for
  statics), reports failure as `Nothing` plus `Err`, and never silently
  recreates an object after it is set to `Nothing`.
- UBE 1.0 construction is parameterless: `New ClassName` has no arguments and
  private `Class_Initialize()` runs automatically once and cannot be called
  directly. Parameterized setup uses an ordinary Sub or factory Function;
  overloaded/parameterized constructors are deferred.
- UBE 1.0 has no user-class implementation inheritance. Polymorphism uses
  `Implements` and interface-typed references; reuse uses composition/modules.
  Forms and controls keep their dedicated framework lifecycle.
- Native source begins `UBE SOURCE 1 MODULE|CLASS|FORM|CONTROL` followed by
  mandatory `Attribute UBE_Name = "..."`; kind must match `.bas/.cls/.frm/.ctl`.
  The source-format version is independent of language version. Legacy
  `VERSION`/`VB_Name` marks compatibility input and native save emits UBE
  identity metadata instead.
- `Public Export Sub/Function` explicitly exposes a standard-module procedure
  through generated foreign ABI metadata; `Export` requires `Public`, is not
  implied by ordinary visibility, and is limited to ABI-supported signatures.
  `Kind = "Library"` builds the target shared-library format with no executable
  startup; returned objects use the agreed opaque external leases.
- UBE has no separate runtime/VM or installed execution environment. GC,
  threading, errors, memory support, and platform adapters are compiled and
  linked into each native output, with unused support eligible for removal.
- Optional private `Module_Initialize()`/`Module_Terminate()` hooks cannot be
  called directly. Every module, including the `Main` module, initializes in
  manifest order before `Main`/library exports; successful modules terminate
  once in reverse order before globals are released, with controlled cleanup
  after partial initialization failure.
- `Public Interface Name ... End Interface` declares a contract with Sub,
  Function, Property, and Event signatures only. It has no storage, body,
  constructor, or instance. `Implements` uses automatic exact name/compatible
  signature matching; identical multi-interface requirements may share one
  member, conflicts fail, and interface variables are strong references using
  `Set`. VB6 interface-class input maps through compatibility import.
- `Class_Terminate` is an exactly-once notification before an unreachable class
  instance is reclaimed, including cycle collection and orderly shutdown.
  Collection may be delayed; releasing one reference does not destroy an
  instance that remains reachable elsewhere. Time-sensitive external-resource
  cleanup requires an explicit lifecycle operation.
- `CallNew` and the thread library use ordinary nonnegative `LongLong` UBE
  identifiers. Zero reports creation failure, identifiers are not dangerously
  recycled within a process, and platform-native thread IDs/handles require an
  explicit platform-library query.
- `CallNew Qualified.Sub(arguments)` is both expression and standalone syntax.
  Its directly visible Sub and ordinary parenthesized arguments are resolved
  statically; empty `()` is required, and functions, callback variables,
  computed addresses, or runtime names cannot be targets in UBE 1.0.
- Thread stopping is cooperative only. `ThreadRequestStop` sets a flag and
  wakes supported waits; interrupted waits return 0 without `Err`, and the
  worker checks `ThreadStopRequested()` before returning or using `Exit Sub`.
  No forced-stop or `Exit Thread` syntax exists, preserving normal scope and
  lock cleanup.
- The thread API signatures and results are frozen: IDs/current ID are
  `LongLong`; `ThreadWait` has an optional `LongLong` millisecond timeout and
  returns 1 for completion or 0 for timeout/cancellation; stop request returns
  1 when recorded; liveness is Boolean; yield is a Sub. Completed valid IDs are
  harmless, never-issued IDs set `Err`, self-wait fails, and multiple waiters
  are allowed.
- `CallNew` evaluates arguments left-to-right before publication and permits
  only `ByVal` target parameters. Scalars, strings, arrays, and custom values
  cross as independent snapshots; object/class arguments share one strong
  identity. No caller-stack reference may escape, and unsynchronized shared
  access may be logically unordered but can never cause memory unsafety or
  undefined behavior.
- Threads retain all access granted by ordinary lexical scope: visible globals,
  modules, statics, fields, objects, forms, and controls are cross-thread
  accessible, while another procedure's local remains out of scope. Platforms'
  UI-thread requirements are hidden through synchronous transparent runtime
  dispatch with controlled cycle failure; UBE source has no UI-owner-thread
  restriction.
- `SyncLock object ... End SyncLock` is the reentrant structured monitor. It
  provides full memory visibility, rejects `Nothing` safely, accepts no value
  identity, releases on every exit/error/cancellation path, and pins an object
  against reclamation while owned or awaited. It remains distinct from file
  `Lock`; lock-order deadlocks are program logic with optional diagnostics.
- Ordinary scalar/reference access is non-tearing and memory-safe but compound
  updates can race. Sequentially consistent `AtomicBoolean`, `AtomicLong`,
  `AtomicLongLong`, and `AtomicObject` wrappers provide applicable load/store,
  exchange, compare-exchange, increment/decrement, and add operations. UBE 1.0
  exposes no weaker memory orders; multi-value invariants use `SyncLock`.
- UBE 1.0 standard-library coordination consists of `ThreadEvent`, `Semaphore`,
  and FIFO `MessageQueue` carrying `Variant`; manual `Mutex` is deferred because
  `SyncLock` supplies safer structured locking. Waits take
  `LongLong` milliseconds (`-1` infinite, `0` poll), return `Long` 1 when
  satisfied and 0 on timeout, and use 0 plus `Err` for invalid input or dead
  objects. Exact library APIs, condition variables, and typed channels are
  deferred from the core language contract.
- Form `Unload` first calls `Form_Unload(ByRef Cancel As Integer)`. Nonzero
  cancellation leaves the form uninterrupted. Once accepted, its native
  window, handles, and event-source registration are released before returning
  to the initiating user code; existing form procedures may unwind. After the
  final active form procedure exits, `Class_Terminate` runs, every managed
  alias becomes `Nothing`, and storage is reclaimed. Control-event details and
  concurrent-call admission remain open.
- Language-level `Unload` applies to forms and controls, not ordinary classes.
  Resource-owning classes provide their own appropriately named cleanup method
  and still receive `Class_Terminate` before reclamation.
- After accepted form/control unloading, no new procedure may enter the
  component; existing calls on any thread drain normally. Native-handle use
  then fails safely. The initiating thread does not wait for other threads;
  final termination and alias clearing occur when the final active call exits.
  Controls use cancellable `Control_Unload(ByRef Cancel As Integer)`.
- `RaiseEvent` is synchronous, subscription-ordered, and reentrant on the
  raising thread. Nested same-event dispatch runs immediately with its own
  subscription snapshot; UBE never suppresses or coalesces it. Native callbacks
  enter through the platform dispatcher, and recursion exhaustion is a
  controlled unwind rather than a process crash.
- Classes, project structures, and advanced language/production features are
  reserved for v3 unless strictly required to compile v3.

## Files currently in scope

- `compiler/UBE_Compiler_v1/`
- `compiler/UBE_Compiler_v2/`
- `compiler/UBE_Compiler_v3/`
- `bootstrap/build.ps1`
- `compiler/Roadmap.md`
- `compiler/Progress.md`
- `lang-doc/v3-language-definition.md`
- `lang-doc/conversion-table.md`, `lang-doc/managed-memory.md`,
  `lang-doc/foreign-abi.md`, and `lang-doc/threading.md`
- `lang-doc/grammar/ube-v3-delta.md`
- `lang-doc/language-spec.md` and `lang-doc/grammar/ube.ebnf` during normative
  integration

## Verification log

- 2026-10-19: completed Compiler v3 Release Preview 5. The bounded typed IR,
  verifier, complete Bootstrap Profile lowering, LLVM backend, debug line
  metadata, target ABI, and compiler-owned Clang handoff are now part of the
  31-module compiler. A v2-built compiler rebuilt its own project and the
  `UBECore` `CoreIdentity.bas` slice; the self-built compiler repeated both
  builds deterministically. Compiler LLVM was byte-identical, normalized COFF
  objects matched, and all 18 positive/negative corpus cases produced
  identical results. The clean complete bootstrap suite passed with Clang
  23.1.3 targeting `x86_64-w64-windows-gnu`.

- 2026-10-16: completed Compiler v3 Release Preview 3. Both preserved v2
  stages emit byte-identical RP3 LLVM. The linked 18-module compiler parses
  itself, inherited multi-module and lexical fixtures, `UBECore`, comprehensive
  UBE 1.0 syntax, and legacy designer sources. Deterministic syntax dumps cover
  every parser-owned core production; scanner-owned productions remain covered
  by RP2. Bounded multi-error recovery and syntax-depth failures return
  controlled diagnostics. Grammar validation and the clean complete bootstrap
  suite passed. `bootstrap/out/v3-rp3-build-manifest.json` records the result.

- 2026-10-16: completed Compiler v3 Release Preview 1. V3 now builds as nine
  ordered v2-compatible modules for bootstrap intrinsics, limits, text,
  diagnostics, sources, projects, targets, driver behavior, and startup. Both
  preserved v2 stages emit byte-identical RP1 LLVM; LLVM links the native
  compiler; and RP1 validates its own project, a two-module executable, and
  the API-empty `UBECore` library project. Controlled tests cover usage,
  unsupported targets, normalized duplicates, path escapes, unknown keys,
  illegal library startup, missing files, manifest/source-count/source-size
  limits, and invalid source UTF-8. The clean complete bootstrap suite passed.
  `bootstrap/out/v3-rp1-build-manifest.json` records version, source, library,
  toolchain, target, and artifact identities. The next implementation target
  is RP2 source-envelope validation.

- 2026-10-16: completed and reverified Compiler v3 Release Preview 0. The
  scaffold, generated LLVM, executable, diagnostics, and build-manifest schema
  now identify RP0 explicitly. A clean `bootstrap/build.ps1` run passed the
  stage-zero unit suites, preserved v1/v2 builds and tests, v2 fixed-point and
  multi-module checks, byte-identical v2-stage RP0 LLVM comparison, and native
  RP0 execution. Grammar validation passed with 202 core and 19 conditional
  productions; all 11 indexed grammar fixtures and all 265 public HTML pages
  also passed their validators. The reproducibility record is generated as
  `bootstrap/out/v3-rp0-build-manifest.json`.

- 2026-10-15: promoted the resolved v3 design to the normative UBE 1.0
  specification and EBNF. The grammar integrity check passed with 175 unique
  productions, no undefined nonterminals, and all required v3 forms. Public
  documentation synchronization was deliberately deferred at the owner's
  direction; its existing grammar-word audit therefore reports the newly
  promoted words until that separate documentation work resumes.

- 2026-10-15: created the v3 project scaffold and design boundary. Both
  preserved v2 stages emitted byte-identical scaffold LLVM; LLVM linked it,
  the executable printed the expected design-stage message and exited 2, and
  `bootstrap/out/v3-scaffold-manifest.json` recorded compiler, source, runtime,
  target, tool, and artifact identities. The full bootstrap suite passed.

- 2026-10-14: stage zero compiled relocated v1; stage one compiled, linked, and
  ran both showcase programs successfully.
- 2026-10-14: the full `bootstrap/build.ps1` invocation passed lexer, parser,
  semantic, codegen, native profile, v1 positive, and v1 negative acceptance
  tests after expected native failures were isolated from PowerShell's
  terminating-error behavior.
- 2026-10-14: stage zero compiled the initial v2 driver; that binary emitted,
  linked, and ran the v2 `Sub Main` showcase successfully. Both v2 entry-point
  forms are now part of `bootstrap/build.ps1`.
- 2026-10-14: v2 added explicit token records, case-insensitive entry discovery,
  token-based showcase parsing, and chunk-joined LLVM emission. The complete
  bootstrap, v1, and v2 suite passes.
- 2026-10-14: v2 added bounded source/diagnostic storage, strict UTF-8 checking,
  located lexer diagnostics, and negative acceptance tests for malformed text.
  The full suite passes, including the embedded-NUL runtime regression.
- 2026-10-14: v2 added retained comments, escaped-string decoding, LLVM byte
  escaping, geometric token/text storage, and its first bounded flat syntax
  node. Parser-negative and end-to-end output tests pass in the full suite.
- 2026-10-14: v2 parses and lowers parenthesized and concatenated string
  expressions through recursive flat nodes; function-result literals also use
  syntax nodes. Positive and malformed-expression tests pass in the full suite.
- 2026-10-14: v2 added Unicode 18.0 identifier-letter classification and
  explicit continuation handling using only checked-in data. The showcase now
  exercises a Unicode procedure name and a commented continuation; the full
  bootstrap suite passes.
- 2026-10-14: v2 added pinned Unicode simple-fold lookup and UTF-8 scalar-wise
  case-insensitive equality. Semantic, lowering, native intrinsic, v1, and v2
  tests pass together.
- 2026-10-14: v2 added bounded procedure, type, and field declaration tables
  with Unicode-folded duplicate checks and controlled structural diagnostics.
- 2026-10-14: v2 added complete Bootstrap Profile procedure-header records and
  semantic entry-point resolution. Positive self-source parsing and negative
  parameter/result/entry diagnostics pass in the full suite.
- 2026-10-14: v2 added local, assignment, and call records plus initial body
  name resolution. Its own source passes; malformed declarations and unknown
  names have controlled regression diagnostics.
- 2026-10-14: v2 added general expression AST construction and recursive name,
  callable, indexing, and argument-count validation. Its complete source and
  malformed-expression corpus pass together.
- 2026-10-14: v2 added recursive expression type resolution and local
  initializer checks for intrinsic scalars, records, arrays, calls, members,
  and operators. Positive self-source and incompatible-type tests pass.
- 2026-10-14: v2 added typed lvalues, call contracts, operand constraints,
  numeric promotion, and callable classification. A negative test exposed and
  now guards an eager-`And` out-of-range crash path.
- 2026-10-14: v2 added structural and typed block `If` and `While` records.
  Stage one parses and analyzes all v2 source in every full bootstrap run; all
  bootstrap, v1, v2, and native tests pass.
- 2026-10-14: v2 added ordered `Dim`, `ReDim`, `Print`, and `Exit` lowering,
  bounded target-independent instruction records, and an initial verifier.
- 2026-10-14: v2 replaced showcase-only emission with whole-program LLVM for
  its Bootstrap Profile. Stage one builds stage two; stage two recompiles v2;
  fixed-point LLVM is byte-identical; positive and negative stage behavior is
  compared automatically. The complete build suite passes.

## Handoff template

Replace these fields when work begins or ends:

- Active item:
- Status:
- What changed:
- Decisions made:
- Commands run and results:
- Remaining failures or blockers:
- Exact next action:
