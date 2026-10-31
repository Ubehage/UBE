# UBE Compiler v2 bootstrap proof

Use `bootstrap/build-v2.ps1` for the current bounded source-only gate. It uses
no pre-existing UBE compiler binary and keeps every run in a separate directory.
The earlier `bootstrap/build.ps1` also contains this historical chain but goes
on to build archived compilers and recreates all of `bootstrap/out/`.

1. The C++ stage-zero compiler builds `Main.bas` as `ube-stage1-v2.exe`.
2. Stage one loads `UBE_Compiler_v2.UBE`, validates its ordered source entries,
   and compiles the project to `v2-stage2.ll`.
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

The current build writes `bootstrap/out/v2/<run>/manifest.json` with tool versions,
target and optimization settings, input hashes, runtime hashes, compiler hashes,
and comparison hashes, complete commands and independent acceptance assertions.
The source-only gate retains an immutable core-build manifest, then runs the
native-value, ordinary-record, managed-substrate, compiled managed-value and
UTF-8 decoder proof suites against that exact candidate.
Their report hashes and assertions are incorporated in the final manifest;
only the complete gate updates `bootstrap/out/v2/current.json`. The recorded
managed-foundation run passes 276 assertions; subsequent proof additions must
retain their own counts and identities.
No failed proof can replace the previous selection. See
`FOUNDATION-VERIFICATION.md` for the exact current-source result. The old copied
`bootstrap/out/v2-bootstrap-manifest.json` describes backup artifacts only.

V2 accepts ordered `.bas` source entries, normalizes their project-relative
paths, rejects escapes and duplicate normalized inputs, loads every module
once, and compiles all modules in a shared declaration universe. The automated
gate places the entry module before its support module, resolves a record type
and calls across that boundary, compares stage-one/stage-two IR, links it, and
checks native output and exit status. Negative gates verify second-module
diagnostic locations and duplicate normalized paths.

The owner approved extending v2 as needed for bootstrap, including managed
array/record support for ordinary UBECore storage. The compiler's own source
remains compatible with the clean seed; this adds no compiler generation or
replacement architecture. [Managed evidence](../../std-lib/MANAGED-STORAGE-EVIDENCE.md)
records the exact scope and limits.

V2 is the transitional compiler used to develop and compile v3;
v3, not v2, is the first public-release target. PE files are recorded by hash
but are not compared as the reproducibility criterion; deterministic LLVM is
the comparison boundary.

The current combined gate passes 470 checks, adding direct source Library
references, native envelope/identity/Startup validation, counted Unicode byte
input and fresh executable admission to the earlier storage proofs. Complete
declarations and library manifests are consumed through actual References;
standalone shared-library output and general package lookup remain outside the
bounded route. Every explicitly inventoried code/header/test/semantic-contract
identity is checked by the compile helper. Current provenance and limits:
`../UBE_Compiler_v3/SOURCE-INPUT-EVIDENCE.md`.
