# Stage-zero compiler

This directory contains the temporary C++ implementation used to bootstrap the
self-hosting UBE compiler. It requires a C++17-capable GCC installation.

## Build and test

From the repository root in PowerShell:

```powershell
./bootstrap/build.ps1
```

The script builds `bootstrap/out/ubec.exe`, runs the lexer, parser, semantic,
lowering, runtime, and native execution tests, preserves the complete v1 and
v2 build chains, and builds Compiler v3 RP4 with both v2 stages. It requires
byte-identical RP4 LLVM, links and runs the RP4 compiler, validates its full
front-end and semantic success/failure corpus, validates the `UBECore` project
boundary, and records `bootstrap/out/v3-rp4-build-manifest.json`.
Build output is intentionally not committed.

To inspect the token stream for a source file:

```powershell
./bootstrap/out/ubec.exe --dump-tokens example.bas
```

To lex and parse a source file with the currently implemented compiler subset:

```powershell
./bootstrap/out/ubec.exe --check example.bas
```

To emit LLVM IR for the currently supported executable subset:

```powershell
./bootstrap/out/ubec.exe --emit-llvm example.bas
./bootstrap/out/ubec.exe --emit-llvm example.bas example.ll
```

To compile and link a native 64-bit executable:

```powershell
./bootstrap/out/ubec.exe --compile example.bas -o example.exe
```

Native compilation currently requires LLVM 23 and the MinGW-w64 toolchain. Set
`UBE_CLANG` to an explicit `clang.exe` path when LLVM is not on `PATH` or in its
default installation directory. The build also produces
`bootstrap/out/bootstrap_runtime.o` and
`bootstrap/out/bootstrap_unicode_runtime.o`, containing the temporary runtime
functions referenced by generated IR. The Unicode object reuses the pinned,
checked-in Unicode 18.0 letter table; builds do not download Unicode data.

## Current scope

The first slice recognizes identifiers and reserved words, numeric, string and
date literals, operators, punctuation, comments, CRLF/LF newlines, UTF-8 BOMs,
and VB-style explicit line continuations. Tokens retain byte offset, line, and
column information for diagnostics.

UTF-8 is validated strictly, token locations use byte offsets with
character-based line and column numbers, bare identifiers accept Unicode 18.0
letters, and keyword comparison uses Unicode 18.0 simple case folding. Original
source spelling is retained in tokens.

The current native Bootstrap Profile also supports typed module-level
procedures with `ByVal` parameters and explicit or default `ByRef` parameters.
`ByRef` calls require a directly addressable variable of the exact declared
type and preserve caller-visible mutation and aliasing.

One-dimensional local dynamic arrays of `Long` and `String` are also native in
the current profile. They support indexed reads and writes, explicit or
zero-based bounds, `LBound`, `UBound`, `ReDim`, and `ReDim Preserve`.

Named Bootstrap Profile `Type` records support `Long` and `String` fields,
direct member reads and writes, deterministic zero initialization, and
exact-named-type `ByRef` parameters. Structurally identical record declarations
remain distinct types.

The dependency-free Unicode letter table is checked in. Regenerate it from the
pinned official Unicode data after intentionally changing the language's
Unicode version:

```powershell
./bootstrap/tools/generate-unicode-letter-ranges.ps1
./bootstrap/tools/generate-unicode-case-folding.ps1
```
