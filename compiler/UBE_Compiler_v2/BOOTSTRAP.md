# UBE Compiler v2 bootstrap proof

`bootstrap/build.ps1` proves the following chain without a pre-existing UBE
compiler binary:

1. The C++ stage-zero compiler builds `Main.bas` as `ube-stage1-v2.exe`.
2. Stage one loads `UBE_Compiler_v2.UBE`, validates its ordered source entries,
   and compiles the project to `v2-self-smoke.ll`.
3. LLVM links that IR and the checked-in bootstrap runtimes as
   `ube-stage2-v2.exe`.
4. Stage two loads and compiles the same project to `v2-stage3.ll`.
5. The stage-two and stage-three LLVM files must have identical byte lengths
   and SHA-256 hashes. No fields are ignored or canonicalized.
6. Stages one and two must emit identical LLVM for both entry-point showcases
   and the backend feature program. The feature program executes calls,
   `ByRef`, records, arrays, `ReDim`, arithmetic, `If`, and `While`.
7. Every checked-in v2 negative case runs through both stages with identical
   diagnostics and exit status, and neither stage may leave an output artifact.

The build writes `bootstrap/out/v2-bootstrap-manifest.json` with tool versions,
target and optimization settings, input hashes, runtime hashes, compiler hashes,
and comparison hashes.

V2 accepts ordered `.bas` source entries, normalizes their project-relative
paths, rejects escapes and duplicate normalized inputs, loads every module
once, and compiles all modules in a shared declaration universe. The automated
gate places the entry module before its support module, resolves a record type
and calls across that boundary, compares stage-one/stage-two IR, links it, and
checks native output and exit status. Negative gates verify second-module
diagnostic locations and duplicate normalized paths.

V2 is the preserved transitional compiler used to develop and compile v3;
v3, not v2, is the first public-release target. PE files are recorded by hash
but are not compared as the reproducibility criterion; deterministic LLVM is
the comparison boundary.
