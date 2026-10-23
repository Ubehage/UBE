# UBE Compiler v3

UBE Compiler v3 is the first public-release compiler target. It is developed
and compiled with the preserved, self-hosting UBE Compiler v2.

Release Preview 7 is the verified baseline. It is a v2-buildable, 37-module
self-hosting compiler. In addition to the RP6 managed-value, object, project,
collection, and foreign-ABI baseline, RP7 implements thread-local `Err` and
structured recovery, `CallNew`, cooperative thread lifecycle, `SyncLock`,
atomics and coordination objects, synchronous events, and form/control
component lifetime.

The preserved v2 compiler builds RP7. That compiler rebuilds its own project
and the exact 16-module `UBECore` slice, and the self-built compiler repeats
both builds. Compiler LLVM is byte-identical, COFF objects match after
normalizing only the producer timestamp, library outputs match, and both stages
agree on 49 recorded inherited, RP6, and RP7 corpus cases. The exact result is
recorded in `bootstrap/out/v3-rp7-build-manifest.json`.

The current RP7 commands are:

```text
ube-v3-rp7 <project.UBE> <target-triple>
ube-v3-rp7 --dump-tokens <project.UBE> <target-triple>
ube-v3-rp7 --dump-syntax <project.UBE> <target-triple>
ube-v3-rp7 --dump-semantics <project.UBE> <target-triple>
ube-v3-rp7 --dump-ir <project.UBE> <target-triple>
ube-v3-rp7 --dump-managed <project.UBE> <target-triple>
ube-v3-rp7 --emit-llvm <project.UBE> <target-triple> <output.ll>
ube-v3-rp7 --build-native <project.UBE> <target-triple> <clang> <runtime.o> <unicode-runtime.o> <output.exe> <intermediate.ll>
```

The frozen RP7 toolchain contract is LLVM/Clang 23.x targeting
`x86_64-w64-windows-gnu` with `-O2`. The compiler-owned `--build-native` path
passes arguments directly to Clang, removes its intermediate file, and leaves
no false-success output after a controlled tool failure. RP8 is the next
milestone.

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
