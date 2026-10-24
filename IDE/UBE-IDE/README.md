# UBE IDE

This directory contains the native UBE development environment. Steps 1 and 2
are implemented: the headless project/document/safety foundation and a plain
native Windows application shell with a central document workspace, docked or
floating Project Explorer, Properties, and Output tools, native menus,
keyboard routing, accessibility, DPI handling, and safe layout recovery.

Run the complete Step 1 verification from the repository root:

```powershell
& .\IDE\UBE-IDE\tests\run-step1.ps1
```

Run the complete Step 2 verification with:

```powershell
& .\IDE\UBE-IDE\tests\run-step2.ps1
```

Add `-Launch` to open the interactive shell after verification. Generated
binaries, layouts, configurations, and LLVM remain under `out/`.

The verification builds the UBE sources with the preserved Compiler v3 release
and writes all generated files under `IDE/UBE-IDE/out/`. It checks source-locale
diagnostic coverage, builds and runs the native headless suite, exercises real
and injected failure paths, and compares two independent LLVM emissions for
byte identity.

Steps 1 and 2 are complete. The next vertical slice connects one real source
document to the native center workspace without moving document ownership or
undo history into the Windows adapter.
