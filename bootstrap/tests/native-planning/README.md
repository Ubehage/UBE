# Native planning acceptance gate

Run from the repository root:

```powershell
rtk proxy powershell -NoProfile -File bootstrap/tests/native-planning/check.ps1 -BootstrapExe "C:\path\to\UBE-Bootstrap.exe"
```

Omit `-BootstrapExe` to build the VB6 bootstrap first. The runner uses the installed Clang/lld toolchain and the existing SDK-independent Windows import-library helper. Each child has a deadline, redirected evidence, and an exact exit-code assertion; generated executables must have the AMD64 PE machine field.

The UBE probe loads runtime source files through `FileBytes`, `SourceScanner`, `SourceParser`, and `ProjectSyntax`. It obtains fresh declaration, expression, aggregate-layout, and primitive-role facts before calling `NativePlanning`. The same source fixtures are independently admitted or rejected by the existing bootstrap's `--emit-llvm` path.

The native O0/O2 assertions cover:

- Four control cells, scalar/record/array storage, result identity, one cell per ordinary ByRef parameter, grouped ByRef temporary storage, record assignment and comparison snapshots, and reusable per-statement index-pin slots.
- Escape facts are derived before frame accounting. Promoted local storage charges one owner slot; an escaping pointer parameter charges its pointer and hidden owner. A fixed array passed through an ordinary ByRef call to an indexed `CallNew` capture uses owned payload storage, while the same nonescaping array remains subject to the inline frame bound. Boxed ByVal record captures charge both the owner slot and their value snapshot.
- Exact 128-cell frame and 64-parameter boundaries, with their first excess rejected.
- Module context offsets across two modules, including fixed and dynamic array descriptors.
- Ascending `FirstScopeSymbol` / `NextScopeSymbol` ownership lists, compared against an independent full declaration scan. These request-owned indexes let procedure cleanup visit its own declarations without repeatedly scanning unrelated modules.
- Case-insensitive and bracketed lifecycle names, a longer ordinary-name control, executable root `Err.Raise` rejection, and library admission of the same procedure.
- Transitive initialization chains, a diamond, cross-module cycles, source calls returning to the initializing module, and permitted same-module recursion.
- Diagnostic categories/reasons and source coordinates, zeroed summary fields on rejection, explicit scalar-precondition rejection, and recovery with fresh valid facts.
- Planning the actual compiler and portable library source bodies, followed by successful context disposal.

After each successful native run, the runner increases a runtime-loaded array bound without rebuilding the executable. The rerun must fail at the exact frame-size assertion. This checks that the facts depend on loaded source rather than fixed expected output.

`NativePlanning` is an internal scratch operation. Its matching semantic arrays are a caller precondition; the gate does not treat arbitrary forged facts as public authority or promise scratch-array preservation on failure. Atomic final output, allocation/depth fault injection, LLVM generation, and execution of planned user procedures belong to the enclosing emission gates. This gate verifies planning facts and host admission parity only.

The large generated assertion driver uses a test-only Windows stack-probe implementation. It is linked solely into the harness, not emitted by the UBE compiler or added to the production runtime. Artifacts retain input projects, host diagnostics, generated LLVM, assertion descriptions, executable files, and per-process output.
