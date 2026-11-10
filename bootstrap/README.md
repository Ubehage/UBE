# UBE bootstrap

The owner selected VB6 as the preferred bootstrap implementation on 2026-11-10,
subject to a successful build and native-output feasibility test. This folder
contains the VB6 project loader, lexer, parser, semantic checker and
LLVM emitter. The pipeline builds admitted multi-module programs into
native Windows x64 executables.

The bootstrap is a temporary development prerequisite. The final compiler is
written in UBE; generated UBE programs do not depend on the VB6 runtime.

The UBE-written components now retain syntax across ordered source modules and
resolve declaration identities, types and signatures. The
[declaration-binding contract](DECLARATION-BINDING.md) and
[expression-binding contract](EXPRESSION-BINDING.md) describe checked declarations,
references, calls and constants. Primitive authority, layout and complete
self-hosting remain distinct responsibilities.

The bridge is textual LLVM IR emitted by a 32-bit VB6 program and
compiled by a separate LLVM toolchain for the selected 64-bit target. This
separates host bitness from target bitness without an in-process LLVM binding.
The fixed IR bridge passed on 2026-11-10 with VB6 6.00.9782 and Clang 23.1.3;
see the compiler progress record for the exact assertions and command. This
probe does not compile UBE source.

Microsoft documents VB6's 32-bit nature and IDE support limitations in its
[support statement](https://learn.microsoft.com/previous-versions/visualstudio/visual-basic-6/visual-basic-6-support-policy).
LLVM documents backend toolchain composition in the
[Clang toolchain guide](https://clang.llvm.org/docs/Toolchain.html).

See [compiler progress](../compiler/Progress.md) for the required proof.

## Project input

Build `UBE-Bootstrap.vbp` with the installed VB6 compiler. Its command is:

```text
UBE-Bootstrap.exe --check path/to/Project.UBE
```

Keep the VB6 `.vbp` and `.bas` files in CRLF format; `.gitattributes` enforces
this on checkout. LF-only versions produced an undefined-function build error
in VB6 despite the referenced function being present.

The loader reads the manifest and retains every source buffer in its specified
order for the parser. Paths resolve relative to the project file, not the
process's working directory. The
[two-module sample](examples/multi-module/Demo.UBE) shows the project structure;
its cross-module call compiles and the generated executable returns 42.
`--check` checks project metadata and source headers, not procedure bodies or
whether `Main` exists. It produces no target executable.

The current admission boundary is Exe/Library projects with `.bas` modules,
native source headers, and Name, Kind, Startup, Source, Optimization and
DebugInformation keys. Other project features receive unsupported diagnostics.
Text is strict UTF-8, with an optional initial BOM. Project and module names
currently accept ASCII identifiers of at most 128 characters; full Unicode
identifiers await the language's pinned Unicode tables.

Input limits are 64 KiB per manifest, 1 MiB per module, 8 MiB of source bytes per
project, 128 modules and 32767 characters per host path.
These are bootstrap admission limits, not new language
limits. Project data is owned by one load context rather than global mutable
compiler state. Loading is sequential; concurrent compilation is not qualified.

Run the [project-loading assertion gate](tests/project-loading/README.md) with:

```powershell
rtk proxy powershell -NoProfile -File bootstrap/tests/project-loading/check.ps1
```

VB6 is an explicit temporary installed prerequisite. A restricted sandbox can
block its registry access; the earlier feasibility build succeeded outside the
sandbox without registry changes. The loader tests do not require LLVM.

On 2026-11-10, that command passed outside the sandbox with VB6 6.00.9782:
the build succeeded and all 54 project-loading/CLI cases passed.

## Source parsing

```text
UBE-Bootstrap.exe --parse path/to/Project.UBE
UBE-Bootstrap.exe --dump-ast path/to/Project.UBE
```

`--parse` validates the admitted scalar syntax in every module. `--dump-ast`
also prints its retained syntax tree, including child links and physical source
spans. Both fail the whole request on the first error; no partial tree is
published as success. The diagnostic includes the source path, line and column.

The implemented syntax covers typed Boolean/Byte/Integer/Long/LongLong declarations, Subs/Functions,
ByVal/ByRef parameters, scalar expressions, qualified calls, assignments,
single-line and block If/ElseIf/Else, labels/GoTo, Exit Sub/Function and the
three admitted On Error forms. Err members are ordinary syntax at this point.
Comments, continuations, ASCII bracketed identifiers and integer literal
spellings retain source positions. Unsupported syntax receives a diagnostic.

Parsing does not resolve names or types, check that Main exists, implement FAIL
behavior or generate executable code. The [bootstrap profile](../lang-doc/bootstrap-profile.md)
distinguishes this syntax support from later semantic requirements.

Limits: 65,536 tokens per module, 262,144 tokens per project, 65,536 syntax nodes,
64 recursive parsing levels, 4,096 UTF-16 code units per token and 128 decoded
ASCII characters per identifier. One diagnostic ends a failed invocation.
See [pipeline design](DESIGN.md) for ownership, spans and the dump format.

Run the [source-parsing assertion gate](tests/source-parsing/README.md):

```powershell
rtk proxy powershell -NoProfile -File bootstrap/tests/source-parsing/check.ps1
```

On 2026-11-10 this gate passed all 37 cases with VB6 6.00.9782. The same binary
also passed all 54 project-loading cases. See the compiler progress record for
exact artifact paths and the assertions covered.

## Semantic checking

```text
UBE-Bootstrap.exe --analyze path/to/Project.UBE
UBE-Bootstrap.exe --dump-bound path/to/Project.UBE
```

These commands resolve declarations across modules, enforce visibility and
unique names, validate Main, check scalar expressions/calls/assignments and
ByRef storage, bind labels and error-handler targets, and check exact integer
constant arithmetic. The dump exposes declaration identities, argument modes,
types, conversions and constants for inspection.

Official Err support has trusted declaration identities. A user module named
Err has ordinary members and cannot acquire built-in Raise behavior by spelling.
The [semantic contract](SEMANTICS.md) defines this binding and explicit limits:
16,384 symbols, 128 semantic recursion levels and a bounded lookup-work budget.
It also records the deferred operator/constant/qualifier cases. Failures produce
one source-located diagnostic and no successful partial semantic result.

```powershell
rtk proxy powershell -NoProfile -File bootstrap/tests/source-semantics/check.ps1
```

On 2026-11-10, the semantic gate passed 76 cases with VB6 6.00.9782; the same
binary passed all 37 parser and 54 loader cases. No UBE procedures are executed
by these static checks. Native execution has its own gate below.

The [native failure-flow gate](tests/failure-flow/README.md) separately checks
the agreed FAIL protocol and statement continuation with hand-authored LLVM.
It is not generated by a UBE source compiler. The planned source admission set
is in [bootstrap profile](../lang-doc/bootstrap-profile.md), and source-compiler
acceptance is in [compiler acceptance](../compiler/ACCEPTANCE.md).

## Native compilation

```text
UBE-Bootstrap.exe --emit-llvm path/to/Project.UBE output.ll
UBE-Bootstrap.exe --build path/to/Project.UBE output.exe
UBE-Bootstrap.exe --build path/to/Project.UBE output.exe --clang "C:\Program Files\LLVM\bin\clang.exe"
```

These commands use the same loaded modules, syntax trees and resolved symbols.
The emitter implements the admitted scalar calls, storage, checked arithmetic,
conversions and error flow. Native builds use the installed Clang and LLD;
the tested version is Clang 23.1.3. The default Clang path is shown above.
Manifest Optimization selects O0/O1/O2/O3/Size. Builds download nothing and
preserve an earlier valid output when a frontend, backend or publication step
fails. Library projects can emit IR; public native library builds are deferred.

Run the actual source-to-native gate with:

```powershell
rtk proxy powershell -NoProfile -File bootstrap/tests/native-compilation/check.ps1
```

It compiles the actual error oracle and multi-module fixtures, asserts behavior
at O0 and O2, checks x64 output and deterministic IR, and exercises failed-build
preservation. Exact evidence is in [compiler progress](../compiler/Progress.md).
The [lowering contract](LOWERING.md) documents the internal ABI, limits and
deferred boundaries. Source positions remain in the pipeline and IR comments;
Line/Full debugger information is not yet emitted. This is a bounded bootstrap
compiler, not full VB6 compatibility or a self-hosting compiler.

## Integer dependencies

Byte, Integer and LongLong storage now join Boolean and Long throughout the
same pipeline. Integer suffixes `%`, `&` and `^` work on declarations, uses and
literals; a use suffix must match its declaration. Arithmetic and narrowing
conversions check the selected type's range, preserving the error behavior
described above. The private scalar ABI does not define foreign memory layouts.

```powershell
rtk proxy powershell -NoProfile -File bootstrap/tests/integer-types/check.ps1
```

This gate tests exact constants, typed conversions, ByRef rules and actual
native execution at O0/O2. The [dependency assessment](DEPENDENCIES.md) explains
why these types come next and what is still needed before self-hosting.

## Source buffers and finite records

Fixed rank-one arrays and finite scalar-field Type records now represent source
bytes and retained token/tree data in UBE. Checked indexing, field access,
ByRef borrowing and independent copies follow the explicit
[aggregate admission boundary](AGGREGATES.md). Records may contain other finite
records. Arrays may contain scalars or those records.

```powershell
rtk proxy powershell -NoProfile -File bootstrap/tests/aggregate-storage/check.ps1
```

The gate checks actual source execution at O0/O2, including bounds failures and
copy/alias behavior. Growing arrays extend this boundary as described below;
managed text and aggregate ByVal/results remain later dependencies.
Exact results are in compiler/Progress.md.

## Counted buffers and UBECore

The bootstrap validates explicitly attributed Intrinsic declarations for
Array.Length and Memory.CopyBytes. The first portable UBECore source modules
compose those primitives in ordinary AppendBytes code. CopyBytes returns usable
Boolean status; AppendBytes explicitly raises a language error when it fails.
The [counted-buffer contract](COUNTED-BUFFERS.md) records the exact boundary.

```powershell
rtk proxy powershell -NoProfile -File bootstrap/tests/counted-buffers/check.ps1
```

This gate passed 25 groups, including actual UBECore execution at O0/O2, overlap,
failure preservation and exact binding. The UBECore project is
`../std-lib/UBECore.UBE`. Consumers currently include its source modules in their
manifest; automatic library discovery and native library packaging remain
unimplemented. File I/O remains a separate dependency.

## Growing arrays

Dynamic rank-one arrays can hold the admitted scalars and finite records.
Array.TryResize and Array.TryCopy prepare replacement storage before publishing
it. Whole-array assignment copies values and bounds independently. Element
references prepared before replacement keep their original storage alive until
the call or assignment finishes.

```powershell
rtk proxy powershell -NoProfile -File bootstrap/tests/dynamic-storage/check.ps1
```

The [dynamic-storage contract](DYNAMIC-STORAGE.md) defines ownership, limits,
allocation retry and failure behavior. Native builds that allocate use the
installed LLVM `llvm-dlltool.exe` beside Clang to create their Windows import
library offline. ReDim/Erase syntax and managed elements remain unsupported.

## Counted file input/output

The current file-I/O increment has a separate native acceptance gate. Its attributed
primitives open counted UTF-8 paths, create new files exclusively, read/write
byte spans, flush and close explicit file tokens. Ordinary UBECore helpers own
the progress loops and publish whole-input results only after successful close.
They admit at most 1,048,576 bytes per whole-input result and transfer at most
65,536 bytes per OS request. Paths retain their separate 4,096-byte bound.

```powershell
rtk proxy powershell -NoProfile -File bootstrap/tests/file-io/check.ps1
```

[FILE-IO.md](FILE-IO.md) records the boundary and tests. Tokens retain ownership
when close fails. Current Byte cells require bounded packing for OS calls;
this implementation adds no C runtime, CRT dependency or SDK import library.
General String/file syntax and Process.TryArgument remain outside this increment.

## UBE-written source scanning

The bootstrap now compiles Do/Loop and Exit Do, checked subtraction, eager Or
and Not. These support the first UBE-written compiler component: a bounded
scanner that reads retained UTF-8 bytes and produces tokens with exact source
positions. A failed If or loop condition skips the complete construct under
default continuation, rather than supplying a Boolean.

```powershell
rtk proxy powershell -NoProfile -File bootstrap/tests/source-scanning/check.ps1
```

The [scanning contract](SOURCE-SCANNING.md) and
[gate README](tests/source-scanning/README.md) describe the 1 MiB input and
65,536-token boundaries and separate syntax, UTF-8 and allocation/depth tests.
The current scanner gate passed 86 groups.

## UBE-written module parsing

`compiler/src/SourceParser.bas` parses retained scanner tokens into independent
caller-owned indexed trees. `SyntaxTokens.bas` classifies ASCII keywords and
decoded identifiers without managed String storage. The parser covers the
current admitted module grammar, including native envelopes, typed declarations,
records, procedures, intrinsic metadata, expressions, calls, If and Do forms.
It retains type references without resolving recursive record layouts.

The [parser contract](MODULE-PARSING.md) defines the API, node fields, diagnostic
categories and limits. The [module gate](tests/module-parsing/README.md) passed
19 cases at O0/O2, parsing actual compiler/library modules including the parser's
own source as data. It checks tree/spans and rejects a changed-input control.
This is syntax acceptance; UBE-written binding, lowering and self-hosting remain
separate work. The VB6 command-line compiler remains the build implementation.
