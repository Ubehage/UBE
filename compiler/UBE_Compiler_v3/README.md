# UBE Compiler v3

UBE Compiler v3 is the first public-release compiler target. It is developed
and compiled with the preserved, self-hosting UBE Compiler v2.

Release Preview 8 is the verified baseline. It is a v2-buildable, 39-module
self-hosting compiler. In addition to the RP7 managed, threading, event, and
component baseline, RP8 adds bounded `.UBG` project groups, hashed `.UBR`
resources, target/version/interface-pinned `.UBL` library bundles, project
optimization and debugger controls, explicit remaining-language compatibility
diagnostics, and Linux x86-64 ELF object emission.

The preserved v2 compiler builds RP8. That compiler rebuilds its own project
and the exact 16-module `UBECore` slice, and the self-built compiler repeats
both builds. Compiler LLVM is byte-identical, COFF objects match after
normalizing only the producer timestamp, library outputs match, and both stages
agree on 50 recorded inherited and preview corpus cases. The exact result is
recorded in `bootstrap/out/v3-rp8-build-manifest.json`.

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

The frozen RP8 toolchain contract is LLVM/Clang 23.x. Windows native builds
target `x86_64-w64-windows-gnu`; `x86_64-unknown-linux-gnu` is verified through
LLVM and ELF object production, not yet as a complete runtime. The
compiler-owned `--build-native` path
passes arguments directly to Clang, removes its intermediate file, and leaves
no false-success output after a controlled tool failure. Beta 1 hardening and
the deterministic multithreaded-compiler plan are next.

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
