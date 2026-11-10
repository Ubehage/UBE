# UBE bootstrap

The owner selected VB6 as the preferred bootstrap implementation on 2026-11-10,
subject to a successful build and native-output feasibility test. This folder
contains the VB6 project loader, lexer, parser and separate feasibility tests.
The source pipeline retains syntax trees; semantic analysis and code generation
remain unimplemented.

The bootstrap is a temporary development prerequisite. The final compiler is
written in UBE; generated UBE programs do not depend on the VB6 runtime.

The proposed bridge is textual LLVM IR emitted by a 32-bit VB6 program and
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
its cross-module call is intended for the later semantic/code-generation gate.
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

The implemented syntax covers typed Boolean/Long declarations, Subs/Functions,
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

The [native failure-flow gate](tests/failure-flow/README.md) separately checks
the agreed FAIL protocol and statement continuation with hand-authored LLVM.
It is not generated by a UBE source compiler. The planned source admission set
is in [bootstrap profile](../lang-doc/bootstrap-profile.md), and source-compiler
acceptance is in [compiler acceptance](../compiler/ACCEPTANCE.md).
