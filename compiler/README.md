# UBE compiler

The native Windows x64 compiler is written in UBE. Its checked-in project is
[Compiler.UBE](../Compiler.UBE), at the repository root so its compiler and
standard-library sources remain within the project tree. That manifest owns
the ordered source list; build packages read it rather than maintain another list.

## Build

From the repository root, with an existing qualified UBE compiler and LLVM:

```powershell
rtk proxy powershell -NoProfile -File bootstrap/tools/build-compiler.ps1 -CompilerExe C:\path\to\UBE.exe -Destination C:\path\to\new-build -RepositoryProject
```

The destination must not already exist. This command compiles the checked-in
`Compiler.UBE` directly, at its declared Optimization 2, and places `UBE.exe`,
its LLVM assets and managed support in the destination. The input compiler
must already have its own `llvm` and `support` directories. LLVM defaults to
`C:\Program Files\LLVM\bin\clang.exe`; use `-Clang` for another installation.

The underlying compiler invocation is:

```powershell
& C:\path\to\UBE.exe --build .\Compiler.UBE C:\path\to\output\UBE.exe --clang "C:\Program Files\LLVM\bin\clang.exe"
```

Use the build script when you need the output compiler packaged with its support
assets. It retains build logs, the actual invocation and project hash in
`build-input.json`, plus a source snapshot and hash ledger; it checks that project
and source inputs did not change during compilation. Existing test fixtures
can still request flattened packages without `-RepositoryProject`.

A fresh checkout still needs an initial compiler: see the
[VB6 bootstrap](../bootstrap/README.md). No prebuilt compiler is bundled here.

## Verify self-building

```powershell
rtk proxy powershell -NoProfile -File bootstrap/tests/self-hosting/rebuild-check.ps1 -InitialCompilerExe C:\path\to\UBE.exe -RepositoryProject
```

This builds the repository project twice, the second time with the first output,
then compares source/assets, emitted LLVM and native images (allowing only the
PE build timestamp). Full compiler conformance is a separate test gate.

See [Roadmap.md](Roadmap.md) for the development sequence and
[Progress.md](Progress.md) for the current handoff and bootstrap evidence.

The active definition work is the [compiler language surface](LANGUAGE-SURFACE.md)
and [VB6 runtime inventory](../std-lib/INVENTORY.md).
