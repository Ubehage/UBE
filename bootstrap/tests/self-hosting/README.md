# Compiler CLI conformance

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File bootstrap/tests/self-hosting/check.ps1 -CompilerExe <actual-UBE-compiler.exe> -BootstrapExe <UBE-Bootstrap.exe> -Clang 'C:\Program Files\LLVM\bin\clang.exe'
```

The actual compiler must already have its reviewed `llvm/templates.bin`, `llvm/windows-runtime.ll` and `llvm/kernel32.def` beside its executable. The harness does not replace those assets or add a host driver to the UBE executable. Both compilers receive only their supported `--emit-llvm` and `--build` commands; one deliberately incomplete command checks usage exit 2.

Every source is copied into an isolated project. The seven common executable families cover return values, multiple modules, source errors and initializer FAIL continuation, dynamic array preservation/copying, explicit file ownership with independently expected bytes, finite records/element aliases/checked failures, and source `CallNew` ownership. The values family checks independent record copying, an original-storage ByRef alias surviving source resize, Long overflow and array bounds handlers preserving assignment destinations, and successful recovery. The worker family reuses the checked-in acceptance sources from `runtime/tests/callnew` without copying their algorithms: creator-return aliases, ordered snapshots, grouped temporaries, fresh failure delivery, nested workers and the live-worker admission bound. Both compilers emit repeated byte-identical LLVM and build/run every fixture at O0 and O2. Native programs must return 42, except the shared worker acceptance bridge whose prescribed success result is zero. The ordinary changed-source negative control must alter the LLVM and produce exit 43. For source workers, changing the expected scalar observation must change the IR and produce exact assertion exit 1; restoring the source must recover both the original IR hash and successful native execution.

Success assertions include exit 0, empty stderr and exact stdout. The seed's stdout includes its documented PROJECT/MODULE inventory; the UBE compiler emits its exact success marker. Controlled failures require exit 1, a diagnostic, unchanged prior output bytes and no adjacent `.ube-*` stage. Negative cases include malformed source in both modes with exact `Malformed.bas:5:17` location, missing manifests/sources, an isolated actual UBE executable missing its assets, source/manifest/output identity, a source hardlink, and missing, nonzero, absent-output and timed-out native backends. Independently compiled fake tools exercise the actual backend failure paths. Timeout assertions require the real 30-second policy interval as well as the correct diagnostic; a failure earlier in tool setup cannot satisfy them. Every backend failure is followed by a real Clang build and native exit-42 recovery. The full gate therefore includes two deliberate 30-second waits.

`-SeedOnly` validates fixtures against the seed while an actual UBE executable is being prepared. Its output explicitly disclaims UBE compiler conformance. `-CompilerSources <manifest>` additionally requests one actual UBE build of that supplied compiler-source manifest, with a longer harness deadline. It neither infers a compiler package nor claims a fixed point from a single successful rebuild. Rebuild-chain equality and distribution qualification remain separate acceptance evidence.

`-CompilerOnly` runs the same complete corpus against a subsequent UBE rebuild, reusing a separately recorded seed result. It is mutually exclusive with `-SeedOnly` and does not reduce the UBE assertions.

`-ValuesOnly` runs only the added finite-record/alias/checked-failure family and usage check. It can qualify that family against existing rebuilds while retaining separately recorded full CLI and negative evidence; it does not claim the omitted checks passed during that invocation.

All generated sources, LLVM, executables, logs and stdout/stderr evidence are retained in the reported unique temporary directory. `package-check.ps1` separately qualifies source packaging and is not a self-build test.

## Rebuild fixed-point gate

```powershell
rtk proxy powershell -NoProfile -File bootstrap/tests/self-hosting/rebuild-check.ps1 -InitialCompilerExe <actual-UBE-compiler.exe>
```

This script calls `bootstrap/tools/build-compiler.ps1` twice into fresh directories:
the initial compiler builds the first output, which builds the second. Optimization
defaults to 2; `-Optimization 0` selects O0 for both builds. `-Clang` selects the native
backend. The initial compiler must already have its support assets.

For builds already witnessed separately, supply `-FirstGenerationDirectory <package>`
and/or `-SecondGenerationDirectory <package>`. Each supplied package must retain its
successful build logs, source ledger, manifest, executable and support assets. Reuse
is explicitly recorded: the comparison run does not claim to have independently
witnessed the predecessor invocation. Omitting either directory builds that output
using its immediate predecessor.

The gate verifies every source against its ledger and current repository bytes;
compares both manifests, ledgers and all three assets bytewise; and has both UBE
outputs emit the identical first compiler-source package. LLVM must be byte-identical.
Each full compiler emission has a 600-second harness deadline and exact success-output
checks. The gate compares native executables raw first. If unequal, only differences
within the four-byte PE COFF `TimeDateStamp` field are permitted: the report records
the exact field offset, differing offsets and original bytes, and retains copies
with only those four bytes zeroed for an additional bytewise comparison. Any size,
header-layout or other byte difference fails. This does not normalize paths, code,
imports, debug data, checksums or any other field.

The unique evidence directory retains LLVM, stdout/stderr, optional normalized copies
and `report.txt`. The report names the initial executable hash and both result hashes.
Rebuild equality is separate from the CLI corpus and full-language conformance.

Passed on 2026-11-13 using the two separately built packages:

```powershell
rtk proxy powershell -NoProfile -File bootstrap/tests/self-hosting/rebuild-check.ps1 -InitialCompilerExe "C:\Users\Ubehage\AppData\Local\Temp\ube compiler bounded native build\UBE.exe" -FirstGenerationDirectory "C:\Users\Ubehage\AppData\Local\Temp\ube compiler self build one" -SecondGenerationDirectory "C:\Users\Ubehage\AppData\Local\Temp\ube compiler self build two"
```

All source/asset comparisons passed. Both emitted 11,349,661 identical LLVM bytes,
SHA256 `4B50601911EDD1CEEE88C5E6E89966F822C66F8C50209F569A3CEE511CE84ACF`.
Native executables differed only at byte offset 128, within the COFF timestamp
field 128–131: first `49-77-F6-6A`, second `BA-77-F6-6A`. The retained copies with
those four timestamp bytes zeroed were byte-identical. No other byte differed.
Both normalized files have SHA256
`A86BCD238FEBA41C7F6249CFAF9084C9C7C1E11F45976B6E5978E3762FABFBD1`.
The raw native hashes and reuse qualification are in
`C:\Users\Ubehage\AppData\Local\Temp\ube compiler rebuild 88b30588-00d5-4f3c-b649-ffdd273efda0\report.txt`.
