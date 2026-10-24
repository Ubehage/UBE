# UBE IDE

This directory contains the native UBE development environment. Steps 1 through
5 are implemented: the headless project/document/safety foundation, a plain
native Windows application shell with a central document workspace, docked or
floating Project Explorer, Properties, and Output tools, native menus,
keyboard routing, accessibility, DPI handling, safe layout recovery, and one
real editable UBE source document carried end to end by the UBE-owned model,
and real ordered Project Explorer, Properties, and bounded Output state that
survives layout customization and restart.
The first isolated language-service path also supplies version-matched
diagnostics and semantic View Definition for project and exact-identity
`UBECore` source.

Run the complete Step 1 verification from the repository root:

```powershell
& .\IDE\UBE-IDE\tests\run-step1.ps1
```

Run the complete Step 2 verification with:

```powershell
& .\IDE\UBE-IDE\tests\run-step2.ps1
```

Run the RP8 real-document checkpoint with:

```powershell
& .\IDE\UBE-IDE\tests\run-step3.ps1
```

Run the RP8 real-workspace checkpoint with:

```powershell
& .\IDE\UBE-IDE\tests\run-step4.ps1
```

Run the RP8 compiler/navigation checkpoint with:

```powershell
& .\IDE\UBE-IDE\tests\run-step5.ps1
```

Add `-Launch` to open the interactive shell after verification. Generated
binaries, layouts, configurations, and LLVM remain under `out/`.

The verification builds the UBE sources with the preserved Compiler v3 release
and writes all generated files under `IDE/UBE-IDE/out/`. It checks source-locale
diagnostic coverage, builds and runs the native headless suite, exercises real
and injected failure paths, and compares two independent LLVM emissions for
byte identity.

Steps 1 through 5 are complete. The next vertical slice validates the
architectural risk gates for accessibility, mixed DPI, service failure,
cancellation, malformed input, low-memory behavior, and performance budgets.
