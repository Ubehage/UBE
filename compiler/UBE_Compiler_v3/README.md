# UBE Compiler v3

UBE Compiler v3 is the first public-release compiler target. It is developed
and compiled with the preserved, self-hosting UBE Compiler v2.

Release Preview 5 is the verified baseline. It is a v2-buildable, 31-module
compiler with bounded target-independent typed IR, an IR verifier, deterministic
lowering of the complete v2 Bootstrap Profile, LLVM emission with source-line
debug metadata, and a frozen target/toolchain boundary. Lowering makes
evaluation order, checked arithmetic, exact `ByRef` addresses, automatic local
dynamic-array cleanup, and controlled failure edges explicit.

The preserved v2 compiler builds RP5, and that v2-built compiler rebuilds its
own project and the current `UBECore` slice (`src/portable/CoreIdentity.bas`).
The self-built compiler repeats both builds. The compiler LLVM is
byte-identical, its COFF objects match after normalizing only the producer
timestamp, the library outputs match, and both compiler stages agree on the
recorded positive and negative native corpus. The exact result is recorded in
`bootstrap/out/v3-rp5-build-manifest.json`.

The current RP5 commands are:

```text
ube-v3-rp5 <project.UBE> <target-triple>
ube-v3-rp5 --dump-tokens <project.UBE> <target-triple>
ube-v3-rp5 --dump-syntax <project.UBE> <target-triple>
ube-v3-rp5 --dump-semantics <project.UBE> <target-triple>
ube-v3-rp5 --dump-ir <project.UBE> <target-triple>
ube-v3-rp5 --emit-llvm <project.UBE> <target-triple> <output.ll>
ube-v3-rp5 --build-native <project.UBE> <target-triple> <clang> <runtime.o> <unicode-runtime.o> <output.exe> <intermediate.ll>
```

The frozen RP5 toolchain contract is LLVM/Clang 23.x targeting
`x86_64-w64-windows-gnu` with `-O2`. The compiler-owned `--build-native` path
passes arguments directly to Clang, removes its intermediate file, and leaves
no false-success output after a controlled tool failure. RP6 is the next
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
