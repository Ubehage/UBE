# UBE Bootstrap Profile

**Status:** complete v2-to-v3 RP5 bootstrap profile  
**Language definition:** 0.3  
**Initial target:** x86-64 Windows GNU ABI

## Current foundation additions - 2026-10-30

The current source-built v2 is qualified separately from the historical RP5
coverage below. It implements nominal opaque `Type Name As StorageType` values
for Byte, Integer and Long, with one-component aggregate ABI, synthesized zero/
copy/calls/results, equality/inequality and explicit Value.Pack/Value.Unpack
intrinsic attributes. Payload fields, implicit representation conversion,
ordering, invalid bindings and unsupported representations diagnose.
`std-lib/tools/check-native-type.ps1` checks independent native/layout/Err/IR
and rejection oracles through both source-built v2 stages. Bare test modules
remain the documented bootstrap source exception; project/package/foreign ABI,
general namespaces/module privacy, managed representations and full record equality are not
qualified by this addition. Stage zero does not acquire this syntax; v2's own
source stays in the existing stage-zero subset.
Binding authority is enforced from the existing source-module provenance:
only the native type's defining module can attach Pack/Unpack implementations.
V2 uses its flat declaration universe and local procedure attribute targets;
this does not claim full qualified-namespace lookup or private procedure access.

The owner subsequently approved managed storage and extending v2 as needed for
bootstrap. Ordinary Byte arrays and finite array-containing records now pass
independent assignment/ByVal/result, exact layout, nested-root, borrowed-element,
scope cleanup, allocation retry/failure and stale-Err tests through both stages.
The recorded source gate passes 276 assertions; this includes the retained
rootless decoder's eight assertions and zero measured allocations. Indices and
counts are signed Long; arrays remain one-dimensional. Inline record cycles,
malformed binding declarations and array-valued Main diagnose before LLVM.

Explicit attributes additionally bind Array.Length, Array.TryResize,
Memory.Collect, Array.TryCopy and Memory.CopyBytes. Exact signatures and
failure/ownership rules are in
[`../std-lib/MANAGED-STORAGE-EVIDENCE.md`](../std-lib/MANAGED-STORAGE-EVIDENCE.md).
This uses the existing intrinsic-attribute syntax, not new grammar. Value.Pack/
Value.Unpack remain scalar-only. Builtin String, objects, managed opaque native
representations, foreign ABI and the full Library source envelope are not
qualified by this ordinary Byte/record proof. Failure concerns one operation;
no implicit transaction or procedure-abort rule is introduced.

The current build command is `bootstrap/build-v2.ps1`; its exact identities and
evidence are in `../compiler/UBE_Compiler_v2/FOUNDATION-VERIFICATION.md` and
`../std-lib/tests/native-type/`. The historical table below retains its original
scope and must not be read as verification of the reset v3.

The UBE Bootstrap Profile is the deliberately bounded subset of UBE used to
write the first compiler in UBE. It is not a separate language: every profile
program is an ordinary UBE program, and profile restrictions disappear as the
self-hosting compiler gains full-language support.

This document records two things independently:

- what the current C++ stage-zero compiler can compile all the way to a native
  executable;
- what the preserved v2 and verified RP5 compilers use to reproduce v3.

Agents must update these tables when support changes. A feature is “native”
only after a generated executable has been run in an automated test.

## Source-input bootstrap extension

The first fresh-v3 consumer additionally requires bounded direct source Library
references, native MODULE envelope/identity and Startup validation, recoverable
raw-byte reading, Unicode command arguments and explicit error recording.
The exact roles are File.TryOpen, File.TryRead, File.TryClose,
Process.TryArgument and Error.Set; all use the existing validated intrinsic
attribute syntax. Contracts:
`../std-lib/FILE-BYTES-CONTRACT.md` and
`../compiler/UBE_Compiler_v2/tests/source-reference/CONTRACT.md`.
The active consumer contract is
`../compiler/UBE_Compiler_v3/SOURCE-INPUT-CONTRACT.md`.
This is not general package lookup, standalone shared-library output, source
language checking or a new String implementation. Qualification results are
recorded separately from the historical profile below.

The current combined source gate passes 470 checks. Exact source/tool/artifact
identities, native entry-admission behavior, source-input results and measured
limits are in `../compiler/UBE_Compiler_v3/SOURCE-INPUT-EVIDENCE.md`.

## Current native subset

| Area | Implemented behavior |
|---|---|
| Source | Strict UTF-8, Unicode 18.0 letters and simple case folding, LF/CRLF, comments, and continuations |
| Entry point | One parameterless `Sub Main()` or `Function Main() As Long` |
| Procedures | Module-level `Sub` and `Function`, calls with parentheses, `ByVal`, explicit or default `ByRef`, and `Long` function results |
| Locals | Procedure-scoped `Dim` declarations with explicit supported types and optional initializers; one-dimensional dynamic `Long()` and `String()` arrays |
| Compiler records | Named `Type` records with `Long` and `String` fields, direct member reads/writes, zero initialization, and exact-type `ByRef` parameters |
| Types | Native lowering currently centers on `Boolean`, `Integer`, `Long`, and `LongLong`; limited `Double` and `String` values can be printed |
| Expressions | Literals, names, unary operators, arithmetic, integer comparisons, and eager integer/Boolean logical operators |
| Statements | Assignment, `Print`, `Exit Sub`, `Exit Function`, block `If/Else/End If`, and `While/Wend` |
| Output | Deterministic typed IR, verified LLVM IR, source-line debug metadata, and linked x86-64 Windows GNU executables through LLVM/Clang 23.x |
| Runtime | Integer, floating-point, string, and newline console-output adapters |

Unsupported constructs must produce a controlled lexer, parser, semantic, or
lowering diagnostic. They must never silently acquire different semantics.
`ByRef` parameters use the language default when no passing modifier is
written. The current profile requires a directly addressable value of the
exact parameter type; variables, members, and indexed array elements retain
their address identity.

## Verified profile coverage

The following facilities form the bounded profile used to build Compiler v3
RP5. Items deliberately left pending are broader language features, not RP5
bootstrap requirements:

- [x] Native executable generation and both forms of `Main`.
- [x] Typed module-level procedures, explicit `ByVal` parameters, and calls.
- [x] Local variables, assignments, block conditionals, and loops.
- [x] Complete checked integer arithmetic and conversions used by offsets,
  lengths, line numbers, and code points. Native `Long` addition, subtraction,
  multiplication, integer division, remainder, negation, and `For` increments
  now detect overflow and invalid division through controlled runtime failures;
  all widths and explicit conversions used by the profile follow controlled
  failure edges.
- [x] `ByRef` parameters for efficient builders and mutable compiler state.
- [x] Dynamic arrays with indexing, bounds, and resizing. Native one-dimensional
  `Long()`, `String()`, and compiler-defined record arrays support indexed
  reads/writes, `LBound`, `UBound`, `ReDim`, and `ReDim Preserve`; dynamic
  arrays can be passed explicitly `ByRef`; local dynamic-array storage is
  released automatically on normal and failure exits. Additional ranks are
  outside the v2 Bootstrap Profile.
- [x] User-defined types needed for tokens, syntax nodes, diagnostics, and
  compilation state. Native named `Type` records support the fields, member
  access, arrays, nesting, initialization, and exact-type `ByRef` behavior used
  by the compiler.
- [~] String length, byte indexing/slicing, search, concatenation, ordinal
  comparison, byte construction, `Long` formatting, and linear joining of a
  bounded `String()` chunk array are available through the documented
  bootstrap intrinsic layer; full Unicode-aware library operations and a
  reusable standard-library builder remain.
- [x] Pinned Unicode 18.0 letter-category lookup is available to UBE compiler
  code through the checked-in bootstrap runtime boundary.
- [x] Pinned Unicode 18.0 simple case folding is available by code point to UBE
  compiler code through the checked-in bootstrap runtime boundary.
- [x] File reading and writing, command-line argument access, and bounded
  shell-free compiler-tool invocation for the initial Windows bootstrap host.
  The private ABI contract is recorded in
  [`bootstrap-intrinsics.md`](bootstrap-intrinsics.md).
- [x] `For` loops and sufficient structured early-exit behavior. Native loops
  support positive and negative `Step`, matching `Next` validation, `Exit For`,
  and `Exit While`; a zero step follows a controlled runtime failure path.
- [x] A clear profile-compatible dispatch pattern using structured `If`.
  `Select Case` remains outside the bounded profile.
- [x] Heap allocation and deterministic cleanup for dynamic compiler data used
  by the profile, including automatic local dynamic-array release on all exits.
- [x] Multiple source files and the project input model. V2 safely loads
  ordered `.bas` entries from `.UBE`, rejects escapes and normalized
  duplicates, resolves supported cross-module declarations, and reports the
  originating source path/line/column. `.UBG` orchestration and `.UBR`
  resources are reserved for v3 as defined in
  [`project-files.md`](project-files.md).
- [x] Stable diagnostic emission with file, line, and column information is
  active for the v2 bootstrap contract; broader severity/note presentation is
  outside the bounded profile.
- [x] A UBE API emits LLVM IR files and the compiler-owned `--build-native`
  path invokes LLVM/Clang through separate bounded arguments with controlled
  cleanup on success and failure.

## Verification gates

Before the UBE compiler source becomes authoritative, all of these gates must
pass from a clean checkout:

1. Stage zero builds with the documented GCC and LLVM versions.
2. Every profile feature has positive, negative, and native execution tests.
3. Unsupported source fails with a diagnostic rather than invalid LLVM IR or a
   compiler crash.
4. Stage zero compiles the compiler source into a stage-one executable. **Passes.**
5. Stage one compiles the published `Sub Main` and `Function Main` showcase
   programs. **Passes.**
6. Stage one compiles its own source to produce stage two. **Passes.**
7. Stage-two and stage-three LLVM is byte-identical under the documented
   comparison policy. **Passes.**

The Public Developer Preview may occur after gates 1 through 5 are stable. A
claim of self-hosting requires all seven.
