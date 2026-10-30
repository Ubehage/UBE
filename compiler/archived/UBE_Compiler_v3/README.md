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
The default is one. The production compiler contains bounded deterministic
workers for the source frontend and procedure semantics, but normal Phase 3/4
worker activation is currently suspended: profiling found that private grammar,
token, and frozen-semantic copies cost more than the work they distribute.
Requested job counts remain accepted and profiles record the effective fallback
count honestly. Explicit fault injection continues to exercise worker cleanup,
and every job count must retain artifact parity. Phase 5 must use shareable
immutable inputs before enabling parallel IR or LLVM work. The sequential seed
remains separate and contains no parallel-only worker code.

The frozen RP8 toolchain contract is LLVM/Clang 23.x. Windows native builds
target `x86_64-w64-windows-gnu`; `x86_64-unknown-linux-gnu` is verified through
LLVM and ELF object production, not yet as a complete runtime. The
compiler-owned `--build-native` path
passes arguments directly to Clang, removes its intermediate file, and leaves
no false-success output after a controlled tool failure. Beta 1
multithreading Phases 0 through 4 are complete: `--profile` supplies
phase and resource measurements, measured superlinear name lookups are
repaired, and the v2→seed→production trust chain is now a permanent clean-build
gate. Phase 2 adds the bounded executor; Phases 3 and 4 implement deterministic
frontend and procedure worker paths while retaining default and explicit
`--jobs 1` artifact parity. Their normal activation is performance-gated off
pending a shared immutable worker representation. See
[`performance/PHASE0_BASELINE.md`](performance/PHASE0_BASELINE.md) and
[`performance/PHASE5_INVESTIGATION.md`](performance/PHASE5_INVESTIGATION.md), and
[`BOOTSTRAP_SPLIT.md`](BOOTSTRAP_SPLIT.md).

The final measured Phase 5 production self-host baseline is 400.656 seconds for
44 sources and 299,684 tokens. Indexed IR edge validation, canonical
function-range LLVM emission, and numeric grammar-rule dispatch replaced major
repeated whole-program work. Profiles expose deterministic backend work counts
so the clean gate can reject a recurrence without a machine-dependent limit.
V3 is retained as the executable reference and bootstrap bridge for v4.

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
