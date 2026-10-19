# UBE Bootstrap Profile

**Status:** complete v2-to-v3 RP5 bootstrap profile  
**Language definition:** 0.3  
**Initial target:** x86-64 Windows GNU ABI

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
