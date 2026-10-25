# UBE Compiler v3

UBE Compiler v3 is the first public-release compiler target. It is developed
and compiled with the preserved, self-hosting UBE Compiler v2.

Release Preview 8 is the verified baseline. Its dedicated 42-source sequential
seed is v2-buildable and produces the 43-source production compiler. In
addition to the RP7 managed, threading, event, and
component baseline, RP8 adds bounded `.UBG` project groups, hashed `.UBR`
resources, target/version/interface-pinned `.UBL` library bundles, project
optimization and debugger controls, explicit remaining-language compatibility
diagnostics, and Linux x86-64 ELF object emission.

The preserved v2 compiler reproducibly builds the dedicated sequential seed
manifest. That seed builds the production manifest without a pre-existing
production binary, and production stages one, two, and three emit identical
LLVM. Production builds repeat the exact 16-module `UBECore` slice, COFF
objects match after normalizing only the producer timestamp, and both compared
stages agree on 50 recorded inherited and preview corpus cases. The exact
result is recorded in `bootstrap/out/v3-beta1-build-manifest.json`.

The current RP8 commands are:

```text
ube-v3-rp8 <project.UBE|group.UBG> <target-triple>
ube-v3-rp8 --dump-tokens <project.UBE> <target-triple>
ube-v3-rp8 --dump-syntax <project.UBE> <target-triple>
ube-v3-rp8 --dump-semantics <project.UBE> <target-triple>
ube-v3-rp8 --dump-ir <project.UBE> <target-triple>
ube-v3-rp8 --dump-managed <project.UBE> <target-triple>
ube-v3-rp8 --emit-llvm <project.UBE> <target-triple> <output.ll>
ube-v3-rp8 --build-native <project.UBE> <target-triple> <clang> <runtime.o> <unicode-runtime.o> <output.exe> <intermediate.ll>
```

Every command accepts `--jobs N`, where `N` is a positive decimal `Long`.
The default is one. The production compiler runs independent source-file
preprocessing, lexing, and parsing concurrently, bounded by the source count
and 32 worker slots, then merges all worker results in manifest order. The
sequential seed remains separate and contains no parallel-only frontend code.

The frozen RP8 toolchain contract is LLVM/Clang 23.x. Windows native builds
target `x86_64-w64-windows-gnu`; `x86_64-unknown-linux-gnu` is verified through
LLVM and ELF object production, not yet as a complete runtime. The
compiler-owned `--build-native` path
passes arguments directly to Clang, removes its intermediate file, and leaves
no false-success output after a controlled tool failure. Beta 1
multithreading Phases 0 and 1 are complete: `--profile` supplies sequential
phase and resource measurements, measured superlinear name lookups are
repaired, and the v2→seed→production trust chain is now a permanent clean-build
gate. Phase 2 adds the bounded executor, and Phase 3 adds the deterministic
parallel source frontend while retaining default and explicit `--jobs 1`
artifact parity. See
[`performance/PHASE0_BASELINE.md`](performance/PHASE0_BASELINE.md) and
[`BOOTSTRAP_SPLIT.md`](BOOTSTRAP_SPLIT.md).

Authoritative inputs:

- [`../../lang-doc/v3-language-definition.md`](../../lang-doc/v3-language-definition.md)
  records the approved and frozen UBE 1.0 language contract.
- [`DESIGN.md`](DESIGN.md) defines the compiler/library/platform boundaries.
- [`ROADMAP.md`](ROADMAP.md) is the resumable implementation checklist.
- [`../UBE_Compiler_v2/V3_BOOTSTRAP_CONTRACT.md`](../UBE_Compiler_v2/V3_BOOTSTRAP_CONTRACT.md)
  defines the subset available while v2 builds the initial v3 compiler.

Generated IR, objects, logs, and intermediate executables belong in
`bootstrap/out/`, never in this directory. Each completed preview's final
verified executable is preserved separately in
[`../release-previews/`](../release-previews/README.md).
