# UBE IDE

This directory contains the native UBE development environment. The current
implementation is the headless Step 1 foundation: project/workspace state,
documents and undo, atomic save and recovery coordination, commands, settings,
localization catalogs, diagnostics, and versioned service envelopes.

Run the complete Step 1 verification from the repository root:

```powershell
& .\IDE\UBE-IDE\tests\run-step1.ps1
```

The verification builds the UBE sources with the preserved Compiler v3 release
and writes all generated files under `IDE/UBE-IDE/out/`. It checks source-locale
diagnostic coverage, builds and runs the native headless suite, exercises real
and injected failure paths, and compares two independent LLVM emissions for
byte identity.

Step 1 is complete. The next implementation work is the plain native shell in
the parent roadmap, after the remaining Phase 0 UX contracts are settled.
