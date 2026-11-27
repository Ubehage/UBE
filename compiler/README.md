# UBE compiler

The native Windows x64 compiler is written in UBE. Its project is
[Compiler.UBE](Compiler.UBE), beside this README. It owns the ordered compiler
and standard-library source list. Compiler sources use `src/`; current explicit
library inputs use `../std-lib/`.

## Build

From the repository root, with an existing qualified UBE compiler and LLVM:

```powershell
rtk proxy powershell -NoProfile -File bootstrap/tools/build-compiler.ps1 -CompilerExe C:\path\to\UBE.exe -Destination C:\path\to\new-build
```

The destination must not already exist. The script reads `compiler/Compiler.UBE`,
stages its source files into a self-contained build directory, and compiles the
resulting manifest. It packages the output `UBE.exe` with its LLVM assets and
managed support. The input compiler needs its own `llvm` and `support` folders.
LLVM defaults to `C:\Program Files\LLVM\bin\clang.exe`; use `-Clang` to override.

**Current limitation:** direct `UBE.exe --build compiler/Compiler.UBE ...` does
not yet work because source paths cannot escape the manifest directory. The
build script resolves the explicit sibling-library paths while staging. Automatic
standard-library discovery is not implemented; this project move does not claim it.

Build logs, actual invocation and project hash are retained in `build-input.json`,
with a source snapshot and hash ledger. Project/source inputs are checked for
changes during compilation. A fresh checkout needs an initial compiler; see the
[VB6 bootstrap](../bootstrap/README.md). No prebuilt compiler is bundled here.

## Verify self-building

```powershell
rtk proxy powershell -NoProfile -File bootstrap/tests/self-hosting/rebuild-check.ps1 -InitialCompilerExe C:\path\to\UBE.exe
```

This builds twice from the checked-in source list, the second time with the first
output, then compares sources/assets, emitted LLVM and native images (allowing
only the PE timestamp). Both builds use staged manifests.

See [Roadmap.md](Roadmap.md) for the development sequence and
[Progress.md](Progress.md) for the current handoff and bootstrap evidence.

The active definition work is the [compiler language surface](LANGUAGE-SURFACE.md)
and [VB6 runtime inventory](../std-lib/INVENTORY.md).
