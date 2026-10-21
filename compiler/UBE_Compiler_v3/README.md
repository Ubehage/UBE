# UBE Compiler v3

UBE Compiler v3 is the first public-release compiler target. It is developed
and compiled with the preserved, self-hosting UBE Compiler v2.

Release Preview 6 is the verified baseline. It is a v2-buildable, 35-module
self-hosting compiler. In addition to the RP5 typed-IR and native backend
baseline, RP6 implements managed metadata and values, recursive custom-value
storage, object and interface dispatch, lifecycle hooks, project references,
automatic tracing collection, callable `UBECore` modules, and the first frozen
foreign-library ownership ABI.

The preserved v2 compiler builds RP6. That compiler rebuilds its own project
and the exact seven-module `UBECore` slice, and the self-built compiler repeats
both builds. Compiler LLVM is byte-identical, COFF objects match after
normalizing only the producer timestamp, library outputs match, and both stages
agree on the recorded inherited and RP6 corpora. The exact result is recorded
in `bootstrap/out/v3-rp6-build-manifest.json`.

The current RP6 commands are:

```text
ube-v3-rp6 <project.UBE> <target-triple>
ube-v3-rp6 --dump-tokens <project.UBE> <target-triple>
ube-v3-rp6 --dump-syntax <project.UBE> <target-triple>
ube-v3-rp6 --dump-semantics <project.UBE> <target-triple>
ube-v3-rp6 --dump-ir <project.UBE> <target-triple>
ube-v3-rp6 --dump-managed <project.UBE> <target-triple>
ube-v3-rp6 --emit-llvm <project.UBE> <target-triple> <output.ll>
ube-v3-rp6 --build-native <project.UBE> <target-triple> <clang> <runtime.o> <unicode-runtime.o> <output.exe> <intermediate.ll>
```

The frozen RP6 toolchain contract is LLVM/Clang 23.x targeting
`x86_64-w64-windows-gnu` with `-O2`. The compiler-owned `--build-native` path
passes arguments directly to Clang, removes its intermediate file, and leaves
no false-success output after a controlled tool failure. RP7 is the next
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
