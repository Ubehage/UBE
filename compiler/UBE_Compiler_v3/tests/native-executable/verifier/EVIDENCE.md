# Focused LLVM verifier probe

On 2026-11-02 the local Clang identified itself as 23.1.3, executable
`C:\Program Files\LLVM\bin\clang.exe`, SHA-256
`F3425B2BFF01BC401C84AF6E5E180629182FAFC2EB35CF971A3E50C9CF13F263`.
`clang -cc1 --help` lists `-llvm-verify-each` as running the LLVM verifier after
every LLVM pass. The following commands were run from the repository root:

```powershell
rtk proxy "C:\Program Files\LLVM\bin\clang.exe" --target=x86_64-w64-windows-gnu -O0 -Xclang -llvm-verify-each -c -x ir compiler/UBE_Compiler_v3/tests/native-executable/verifier/valid.ll -o bootstrap/out/valid-verifier-probe.o
rtk proxy "C:\Program Files\LLVM\bin\clang.exe" --target=x86_64-w64-windows-gnu -O0 -Xclang -llvm-verify-each -c -x ir compiler/UBE_Compiler_v3/tests/native-executable/verifier/invalid-dominance.ll -o bootstrap/out/invalid-dominance-verifier-probe.o
```

The valid module returned 0 with an expected warning that the target triple was
overridden. The invalid module returned 1 with `Instruction does not dominate
all uses!`; its branch-defined value is used on a path that does not define it.
This is an independent structural negative control, not a fresh-v3 compiler
or native-executable test. It does not establish that all malformed IR is
rejected or that the emitted code has correct UBE semantics. The future gate
must run an equivalent control with its selected exact tool and validate the
same raw module it compiles and links.

As an independent tool-failure control, both modules were also passed to the
same Clang invocation with output set to
`bootstrap/out/verifier-missing-parent-probe/no-output.o`. The parent directory
was absent, as confirmed by `Test-Path` after the runs. Both commands exited 1
and reported inability to open the output file; neither output established an
IR verifier result. In particular, the invalid module's structural defect was
masked by the earlier output failure. This supports the diagnostic draft's
requirement not to classify every nonzero tool exit as invalid generated LLVM.
The host experiment does not provide a machine-readable verifier disposition or
qualify the eventual production validation gate.

The installed LLVM directory has `bin/LLVM-C.dll` and `lib/LLVM-C.lib`, though
the search found no `opt.exe` or `llvm-as.exe` there or in the examined WinLibs
bin directory. A separate test-only `api-probe.c` dynamically loads that DLL,
parses a file and invokes `LLVMVerifyModule` with the return-status action; it
does not create an object file. It distinguishes its own outcomes for valid IR,
invalid dominance, syntax failure and a missing input. The LLVM documentation
describes the [IR reader](https://llvm.org/docs/doxygen/group__LLVMCCoreIRReader.html)
and [return-status verifier action](https://llvm.org/doxygen/llvm-c_2Analysis_8h_source.html).
These commands passed on this host:

```powershell
rtk proxy "C:\Program Files\LLVM\bin\clang.exe" --target=x86_64-w64-windows-gnu -std=c17 -Wall -Wextra -Werror -municode compiler/UBE_Compiler_v3/tests/native-executable/verifier/api-probe.c -o bootstrap/out/llvm-api-probe.exe
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/verifier/check-api-probe.ps1 -Probe bootstrap/out/llvm-api-probe.exe -Library "C:/Program Files/LLVM/bin/LLVM-C.dll"
```

The comparator checks the program's actual exit statuses 0, 1, 2 and 3 and
their respective output. Direct invocation through `rtk proxy` normalized the
nonzero process status, so it was not used as the status oracle. This narrowly
demonstrates a candidate machine-readable verifier boundary. It does not select
an implementation, qualify a DLL dependency, guarantee safe behavior on every
malformed module, bind the parsed bytes to later compilation, or establish
Unicode path support in general. Production integration and failure containment
remain unresolved.

The separate `check-optimized-verifier.ps1` runs Clang with `-O2` and
`-llvm-verify-each`, once with `-g` and once without it. In both modes the valid
IR produced a nonempty object and the dominance-violation control exited 1
with the expected verifier diagnostic. The command returned 0:

```powershell
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/verifier/check-optimized-verifier.ps1 -Clang 'C:\Program Files\LLVM\bin\clang.exe' -OutputDirectory bootstrap/out/optimized-verifier
```

The inputs are hand-written and do not contain UBE debug metadata. This
supports the specific optimized invocation as a candidate; it does not prove
debug information correctness, tool identity binding, process containment or
validation of future generated modules.

`check-debug-version.ps1` generates test-only debug IR from C, then makes a
copy with an invalid debug-info version. At O2 with `-g` and
`-llvm-verify-each`, Clang exited 0 for both. For the changed version it warned
that it ignored debug info. `llvm-readobj --sections` found `.debug_info` and
`.debug_line` in the valid object and neither section in the changed object.
The following command returned 0 after checking all of these outcomes:

```powershell
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/verifier/check-debug-version.ps1 -Clang 'C:\Program Files\LLVM\bin\clang.exe' -Readobj 'C:\Program Files\LLVM\bin\llvm-readobj.exe' -OutputDirectory bootstrap/out/debug-version
```

This demonstrates why verifier/tool exit 0 alone cannot establish Full debug
information. The test covers one version mutation and object format; section
presence alone does not prove correct source or variable locations, and this
does not test UBE-generated metadata or final linked debug information.
The same harness was extended to link the valid debug object twice, once
normally and once with `-Wl,--strip-debug`. Both linked executables returned 7;
the normal executable contained `.debug_info` and `.debug_line`, while the
stripped executable contained neither. The command above returned 0 again.
This shows one way debug information can be lost after a valid object is built;
it is a test-controlled linker option, not a claim that the UBE build uses it.

`check-api-unicode.ps1` then copied the valid and invalid-dominance fixtures
into a test-owned directory containing `æøå` and U+10400. This command passed,
checking the API probe's actual valid/invalid dispositions on those paths:

```powershell
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/verifier/check-api-unicode.ps1 -Probe bootstrap/out/llvm-api-probe.exe -Library "C:/Program Files/LLVM/bin/LLVM-C.dll" -OutputDirectory bootstrap/out/llvm-api-unicode
```

This is one Windows-host path experiment using the probe's UTF-8 conversion
and LLVM's file reader; it does not qualify arbitrary paths, library loading,
production integration, or the rest of the native tool argument boundary.

The disposition comparator was extended with a wrong-status and wrong-output
control for each of its four cases. Rerunning the `check-api-probe.ps1` command
above returned 0 and reported four disposition checks and eight rejected
comparator controls. SHA-256 identities for that run were:

| Input or artifact | SHA-256 |
| --- | --- |
| LLVM-C.dll | `87110CB42B3074A1E384BF0B96CB4A052B6EB44CD2441AE3A65648F8EAD7AE72` |
| api-probe.c | `0D4756A873B5EC5A0819EEB48240879CE764FF32055DB67726BD7F7BAF3F2A47` |
| llvm-api-probe.exe | `F6A51D860314C07CCBEF4276B9DF07AFAD43F79E51F5FECD75B30CE40A40ECE1` |
| check-api-probe.ps1 | `63CB70433BE6D0C55561B0903D84A548950B9A38B7BAD457A82068EE19E2C58A` |
| valid.ll | `C03995971F056D77F2A5C76D9AE739B4CC7D2545A91F168A47DFB631EDA3DC62` |
| invalid-dominance.ll | `A1B0DB575BE61413C7C2B699C9960BFFADF8ED45A9A307794023C1F72266123B` |
| invalid-syntax.ll | `035AAB40D013302B7AB4DA21C230CFFE4CE55A9DFF591F74D397EF4334EE78FE` |

The hand-authored `checked-division.ll` probes one candidate lowering shape:
branch around `sdiv` when the divisor is zero or the operands are Long minimum
and -1, set a test error flag and return zero; otherwise divide and preserve the
flag. Its entry uses volatile loads so these test inputs are not simply literal
call arguments. This command compiled and linked with Clang's verifier enabled
at O0 and O2, then observed Windows exit 82 from each executable:

```powershell
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/verifier/check-division-probe.ps1 -Clang "C:/Program Files/LLVM/bin/clang.exe" -OutputDirectory bootstrap/out/checked-division-probe
```

The probe checks the overflow, zero-divisor and ordinary minimum/1 result, plus
the test flag's retention after a successful division. Its first compilation
attempt hit a target-triple warning under PowerShell's stop-on-error setting;
adding the intended target triple to the probe preceded the passing run. This is
not generated UBE code, a production Err implementation, or proof of all
operand values and LLVM transformations. It illustrates a candidate guard and
does not replace the independent native fixture and real Err observer.

The script now also generates a test-only mutation that suppresses the error
flag update. Rerunning the same command passed: the original returned 82 and
the mutated executable returned the fixture's failure value 99 at both O0 and
O2. This checks sensitivity to that one missing update; it does not qualify the
real thread-local Err implementation or all possible erroneous lowering.
The hand-authored module was also extended with a guarded minimum/-1 remainder
branch and a test parameter representing the two error-state alternatives that
were under review at the time. The same O0/O2 command passed for both parameter values without
executing `srem` on that operand pair. This is an exploration of both branches,
not a test of UBE semantics; its test flag is not the real Err. The owner has
since selected the no-error behavior for Long minimum `Mod -1`.
The no-error branch was subsequently changed to retain a preseeded test flag,
and a second test-only mutation clears that flag. Rerunning the same command
passed at O0 and O2: the correct probe returned 82, and each missing-error and
cleared-error mutation returned the fixture's failure result 99. This checks the
hand-authored probe's flag behavior, not the production Err implementation.

The separate hand-written `remainder-widths.ll` exercises guarded i16 and i64
minimum `srem -1`, normal negative remainders, preservation of a preseeded
simulated error slot, and one i16 division-by-zero failure. The command
`rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/verifier/check-remainder-widths.ps1 -Clang "C:\Program Files\LLVM\bin\clang.exe" -OutputDirectory bootstrap/out/remainder-widths`
passed at O0 and O2; a deliberately incorrect expected preserved value returned
failure at both levels. The calls use constant arguments, which optimization
may fold. This is host evidence for this hand-authored module only, not UBE
lowering, a real thread-local Err, all operand values, or debug equivalence.

The same script now also compiles the two hand-written remainder functions with
the separate `remainder-widths-driver.c`. Its volatile operands are read at
runtime; it checks both widths for minimum/-1, -17 Mod 5, and a zero divisor,
including simulated error-slot preservation or update. Both O0 and O2 builds
returned 0, and an intentionally wrong error expectation returned 7 in both.
This improves on the constant-argument probe but still does not test UBE-generated
operations, the real Err store, or all operand pairs.

## Host linker repeatability observation

`check-link-determinism.ps1` initially built the same test-only C source twice per mode,
using the same input path, output path, working directory, target and Clang
invocation, separated by two seconds. It ran every executable and required
exit 7, then compared entire executable bytes and the PE timestamp field. The
following command returned 0 on the current host:

```powershell
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/verifier/check-link-determinism.ps1 -Clang "C:\Program Files\LLVM\bin\clang.exe" -Readobj "C:\Program Files\LLVM\bin\llvm-readobj.exe" -OutputDirectory bootstrap/out/link-determinism
```

For the default link, timestamps were 1793650850 and 1793650852 and the two
executables differed in two bytes. With `-Wl,--no-insert-timestamp`, both PE
timestamps were zero and the executable bytes were identical in this single
pair. Their SHA-256 was
`7981111610D86273407D95A2FDAD1E449DF62BF965DC63C1F1F702AA3DFECEA6`.
This is a local toolchain observation, not proof of binary reproducibility across
paths, debug modes, machines, tool versions, or UBE-generated modules. The
flag was an experiment at this checkpoint. The later staged-command review below
selects it for the draft contract. Matching executables
does not establish that fresh-v3 raw LLVM is deterministic.

The script was subsequently extended to build with `-g` as well, and the
command above describes the current version. In a repeat run the default debug
pair had differing timestamps and two differing bytes. The debug pair built
with `--no-insert-timestamp` had zero timestamps and identical bytes, SHA-256
`F7F817C4D1AB0849F69B7BB67B01D5E17B8E9F3F51C5BF9D011AC6C2BE39087A`.
All eight executions returned 7, and `llvm-readobj --sections` found both
`.debug_info` and `.debug_line` in each debug executable. Presence of those
sections does not establish correct source locations or debugger behavior;
the same host, paths and source were used, and no UBE code was generated.

`check-output-path-determinism.ps1` generated optimized C-derived LLVM with
debug metadata and linked two debug executables at different output paths, with
the same source path and working directory and timestamp insertion disabled.
In this host run the two raw LLVM hashes matched, and the two executable hashes
matched; both executables returned 7 and contained `.debug_info` and
`.debug_line` sections. One-byte changes to copies of the LLVM and executable
were distinguished by the hash comparison. The harness reports equality rather
than assuming it as a portable toolchain guarantee.

```powershell
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/verifier/check-output-path-determinism.ps1 -Clang "C:\Program Files\LLVM\bin\clang.exe" -Readobj "C:\Program Files\LLVM\bin\llvm-readobj.exe" -OutputDirectory bootstrap/out/output-path-determinism
```

This checks one C source and two candidate paths, not UBE lowering, source-path
relocation, debug line correctness, multiple toolchains or binary reproducibility
in general. The timestamp option was not selected at that checkpoint. The later
review below selects it for the draft contract and corrects this test's
source-to-executable connection. The command above records the earlier version;
the current script also requires `-Linker` and uses the staged path below.

### Selected staged compile/link commands: host qualification

Review found that the earlier output-path script generated LLVM for comparison
but compiled its executables directly from the C source. It did not test a
connection between those LLVM bytes and the linked program. The corrected
script compiles its generated LLVM with the selected O2 verifier invocation,
links only that object with an explicit `--ld-path`, disables PE timestamp
insertion and selects the console subsystem. In both Full and None modes it
builds at two candidate paths, checks zero object/PE timestamps, compares raw
LLVM, object and executable hashes, and requires exit 7. An independent change
to only the LLVM global initializer, from 7 to 9, must produce exit 9 while the
unchanged C source still says 7. This control detects accidentally rebuilding
the C source at link time. Only test-owned executables are run.

The first corrected run failed the newly added object-hash comparison. Its
LLVM and executable hashes matched, but the object timestamps were one second
apart (`0x6AE921AD`, `0x6AE921AE`), as independently reported by
`llvm-readobj --file-headers --symbols` for the two `Full.o` files under
`bootstrap/out/output-path-determinism/abb4c6f91591495e83f83451eda019c4`.
Adding `-mno-incremental-linker-compatible` to object compilation gave zero
COFF timestamps. The harness now separates the two builds by 1100 ms so a
same-second run cannot conceal that default. Two subsequent harness failures
were corrected: PowerShell unwrapped the single None flag into a scalar before
splatting, and Clang's `-g0` IR retained a `DICompileUnit` with
`emissionKind: NoDebug`. The None assertion now checks that emission kind and
absence of subprogram/location records rather than rejecting that bookkeeping.

The following current command returned 0. Both mode pairs matched in all three
comparisons, all four ordinary executions returned 7, and both LLVM-only
mutations returned 9. The report records the exact script, fixture, Clang,
linker and reader hashes and the observed artifact hashes:

```powershell
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/verifier/check-output-path-determinism.ps1 -Clang 'C:\Program Files\LLVM\bin\clang.exe' -Readobj 'C:\Program Files\LLVM\bin\llvm-readobj.exe' -Linker 'C:\Program Files\LLVM\bin\ld.lld.exe' -OutputDirectory bootstrap/out/output-path-determinism
```

Report: `bootstrap/out/output-path-determinism/e8b8bd1d39dd4294adb31a55ac219794/report.json`.
Full executable SHA-256:
`F7F817C4D1AB0849F69B7BB67B01D5E17B8E9F3F51C5BF9D011AC6C2BE39087A`.
None executable SHA-256:
`7981111610D86273407D95A2FDAD1E449DF62BF965DC63C1F1F702AA3DFECEA6`.
The report identifies Clang as
`F3425B2BFF01BC401C84AF6E5E180629182FAFC2EB35CF971A3E50C9CF13F263`
and LLD as
`8D1DD3BA3A3810AFC78A8BD97406B30BC5B9C301F9238224D35D030B0A826680`.

The existing source-location/side-effect probe was also run with these object
and link options, including the explicit linker. Both commands returned 0:

```powershell
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/verifier/check-ir-stream-debug.ps1 -Clang 'C:\Program Files\LLVM\bin\clang.exe' -Objdump C:\Users\Ubehage\Documents\WinLibs\mingw64\bin\objdump.exe -Linker 'C:\Program Files\LLVM\bin\ld.lld.exe' -OutputDirectory bootstrap/out/ir-stream-debug -Behavior
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/verifier/check-ir-stream-debug.ps1 -Clang 'C:\Program Files\LLVM\bin\clang.exe' -Objdump C:\Users\Ubehage\Documents\WinLibs\mingw64\bin\objdump.exe -Linker 'C:\Program Files\LLVM\bin\ld.lld.exe' -OutputDirectory bootstrap/out/ir-stream-debug -Behavior -NoDebug
```

Outputs are under `bootstrap/out/ir-stream-debug/749bea72c04d4f6bb05d6987083ddd62`
(Full) and `43c8d5b67263417f9d5aba01c1688314` (None). Each path/stdin pair returned
8 and had matching object hashes. Full source-line addresses matched the
corresponding linked function ranges, with wrong procedure/line and swapped
association controls rejected. None lacked the fixture's source records. These
are the existing probe's specific checks, not a full debug validator. Its stdin
comparison does not select stdin as the production input mechanism.

The updated `check-optimized-verifier.ps1`, run with the same Clang and
`-OutputDirectory bootstrap/out/optimized-verifier`, returned 0: valid input
produced objects and the dominance control returned 1 with its expected
diagnostic, both with and without `-g`. That test's IR has no source debug
metadata; the source-location probe supplies the separate debug observation.

These results support the selected command options and DWARF 4 direction in
`NATIVE-EXECUTABLE-CONTRACT.md`. They do not qualify UBE lowering, runtime
support, arbitrary debug records, binary reproducibility across installations,
process containment, safe tool-path acquisition or publication. At that
checkpoint MinGW startup/archive resolution still lacked a recorded input
cohort; the later explicit-support section below addresses that choice.
Specifying the LLD path does not establish which image ran in a path-substitution
race.

### Explicit support cohort and environment

The later contract review selects explicit startup/archive paths, an allowlisted
tool environment, `--no-default-config` on object and link invocations,
`-nostdlib` for linking, and LLD `--threads=1` plus
`--Xlink=/nodefaultlib`. The startup mechanism remains ordinary console CRT.
The driver still adds search directories, but the tested link has no bare `-l`
arguments and suppresses default-library directives. Other object directives,
tool/DLL image identity and production containment remain separate obligations.

The focused test recompiled the retained LLVM under that environment, required
the object hash to match the earlier object, linked its newly generated object,
required the executable hash to match the earlier executable, and required
native exit 7. Full and None both passed. The test then supplied a deliberately
invalid default `clang.cfg`: the protected invocation produced the same bytes,
while omitting `--no-default-config` failed with its unique marker and no output.
A separate COFF object requested a nonexistent default library; explicit
libraries linked successfully with `/nodefaultlib`, while omitting that option
failed with the missing-library marker and no output. These controls do not
claim all environment or directive combinations are qualified.

The test-only LLD `--reproduce` archive held exactly 14 distinct input files:
13 startup/archive files below and the newly generated fixture object. Every
reproduced file matched its explicitly named input's SHA-256, and unexpected
files were rejected. All ten archives had the ordinary embedded-member archive
signature; this signature test does not inspect every member's COFF content.
The script records absolute argument vectors, the selected environment, fixture,
tool and script identities, controls, input hashes and PE import names. Tar
inspection is test infrastructure, not a required runtime or production tool.

Commands (both returned 0):

```powershell
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/verifier/check-explicit-link-inputs.ps1 -Clang 'C:\Program Files\LLVM\bin\clang.exe' -Linker 'C:\Program Files\LLVM\bin\ld.lld.exe' -Readobj 'C:\Program Files\LLVM\bin\llvm-readobj.exe' -Ir 'bootstrap/out/output-path-determinism/e8b8bd1d39dd4294adb31a55ac219794/candidate one/Full.ll' -Object 'bootstrap/out/output-path-determinism/e8b8bd1d39dd4294adb31a55ac219794/candidate one/Full.o' -ReferenceExecutable 'bootstrap/out/output-path-determinism/e8b8bd1d39dd4294adb31a55ac219794/candidate one/Full.exe' -MingwLibraryDirectory C:\Users\Ubehage\Documents\WinLibs\mingw64\x86_64-w64-mingw32\lib -GccLibraryDirectory C:\Users\Ubehage\Documents\WinLibs\mingw64\lib\gcc\x86_64-w64-mingw32\16.2.0 -OutputDirectory bootstrap/out/explicit-link-inputs
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/verifier/check-explicit-link-inputs.ps1 -Clang 'C:\Program Files\LLVM\bin\clang.exe' -Linker 'C:\Program Files\LLVM\bin\ld.lld.exe' -Readobj 'C:\Program Files\LLVM\bin\llvm-readobj.exe' -Ir 'bootstrap/out/output-path-determinism/e8b8bd1d39dd4294adb31a55ac219794/candidate one/None.ll' -Object 'bootstrap/out/output-path-determinism/e8b8bd1d39dd4294adb31a55ac219794/candidate one/None.o' -ReferenceExecutable 'bootstrap/out/output-path-determinism/e8b8bd1d39dd4294adb31a55ac219794/candidate one/None.exe' -MingwLibraryDirectory C:\Users\Ubehage\Documents\WinLibs\mingw64\x86_64-w64-mingw32\lib -GccLibraryDirectory C:\Users\Ubehage\Documents\WinLibs\mingw64\lib\gcc\x86_64-w64-mingw32\16.2.0 -OutputDirectory bootstrap/out/explicit-link-inputs
```

Reports under `bootstrap/out/explicit-link-inputs/`:
`bee0b5b583564dbfbc5ecf3044da557b/report.json` (Full) and
`318209f12b5b4f0282acf596c47e6386/report.json` (None). The executable hashes remain
the Full/None hashes in the preceding staged-command evidence. These results
cover this fixture and host installation, not all UBE runtime helpers or a
portable release. The current WinLibs `version_info.txt` identifies GCC 16.2.0,
MinGW-w64 14.0.0 UCRT, POSIX thread model, personal build r2 packaged 2026-09-29.
This is an installed package's identity claim, not independently verified
provenance or a restored repository toolchain lock.

| Input basename | SHA-256 |
| --- | --- |
| crt2.o | 02C1AD7529DE04A081D522E002B39A7E1CFDCD60CCFC9A4373C282FA24BB3539 |
| crtbegin.o | DF66FCC38A204EFFF82C565E225DCD55BBD6CD6AA5E53439E0972DC87AB3064B |
| libmingw32.a | F0528405537CB6E8246A0AD9384E599D2303BA7AB2B8F5E75FCF34951CE2BEDB |
| libgcc.a | A9B36DE60650531FA72541252E136B879B9CBFEA101ACC4A00E84D347E089792 |
| libgcc_eh.a | A3BD5C8A989F3D9B18198923861A9783CFB557C71B9A4D76FC020698D7B65122 |
| libmoldname.a | 45040D33A242822A6EA82BBF6504BFDD97B3BFFF13DC0BEC52BEDE2123132EE0 |
| libmingwex.a | AB1D88F19ACB11567F66D895AC8DB1350AEB0D12DE36B2C53477F6525536FC57 |
| libmsvcrt.a | ECA4BF8A12D594191E75938779D3D4762F40EB3C450BA827BC57E184ACA73615 |
| libadvapi32.a | F7F6ECD9BE716C39611DA2615E6A96E2D89BE6161EF815B171914635107BF3C5 |
| libshell32.a | 62643E26BEFF8F7CF95D5D8F79CC3AAE82084741D122A6472EB7CBDC76361E63 |
| libuser32.a | 40E1EEE7E3C03CB2AF9E08B628DF7E110982642606DAFE982946331A151FEA09 |
| libkernel32.a | BE32D89DBA0C931DCE6F531B8244318E9F2CA8C9399155D02E6F20F7A9C83CCC |
| crtend.o | 967C20D4B4ECDA3CABF5BE702DB4A52FD3C6B56BA4188E4642F7991082BAD12D |

The independent `llvm-readobj --coff-imports` observation found `KERNEL32.dll`
and eight `api-ms-win-crt-*-l1-1-0.dll` imports: environment, heap, locale,
math, private, runtime, stdio and string. The script now requires that exact
fixture list and retains the complete report in `imports.txt`. In particular,
the filename `libmsvcrt.a` does not imply an `msvcrt.dll` dependency in this
UCRT distribution. This observation does not prove runtime DLL image identity
or extend the compiler's supported Windows versions. A successful return from
this small program also does not qualify all CRT failure paths.

The retained `check-support-object-inventory.ps1` then inspected all 13 support
files, requiring the explicit-link report's source hashes. Its independent
archive-envelope walk counts payloads, classifies ordinary AMD64 COFF records,
checks section tables/string names and reads raw `.drectve` data. It compares
those counts and directive contents with `llvm-readobj --file-headers
--coff-directives`, and with the recorded per-file cohort counts. Command:

```powershell
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/verifier/check-support-object-inventory.ps1 -SourceReport bootstrap/out/explicit-link-inputs/318209f12b5b4f0282acf596c47e6386/report.json -Readobj 'C:\Program Files\LLVM\bin\llvm-readobj.exe' -OutputDirectory bootstrap/out/support-input-audit
```

Exit 0; report `bootstrap/out/support-input-audit/c99859969f174831b607ac647a5f1a6f/report.json`.
All 13 reader invocations returned 0 with empty stderr. The ten ordinary
archives contained 7,307 payload members; the three CRT objects bring the count
to 7,310 AMD64 COFF records and 52,655 sections. No thin archive, short-import,
bigobj, standalone LLVM bitcode, script or unknown member appeared. The section
scan found no `.llvmbc`, `.llvm.lto` or `.gnu.lto*` name. This is a fixed-cohort
inventory, not a general-purpose COFF validator or proof against every possible
hidden payload encoding.

Three members contained the only directive sections; raw bytes and tool text
matched. The selected cohort permits these four common-symbol alignments:

| Archive/member | Directives |
| --- | --- |
| libmingw32.a / lib64_libmingw32_a-tls_atexit.o | `-aligncomm:"__dso_handle",3` |
| libmingwex.a / lib64_libmingwex_a-getopt.o | `-aligncomm:"__mingw_optreset",2` and `-aligncomm:"optarg",3` |
| libmingwex.a / lib64_libmingwex_a-stack_chk_guard.o | `-aligncomm:"__stack_chk_guard",3` |

No entry, stack, subsystem, include, default-library or file-loading directive
was present. The report preserves tool/helper identities, every input hash,
counts, raw directives and text-report hashes. The initial independent audit is
also retained under `bootstrap/out/support-input-audit/e90201c5f98a46f68a2c3743abb38073`;
the maintained helper above replaces its fixed-path scratch invocation. Neither
inventory establishes which archive members contributed executable code or
qualifies UBE error/stack support, process-image binding or concurrent changes.

`--threads=1` selects LLD's work setting, not an OS-thread cap. The installed
revision's [COFF driver](https://raw.githubusercontent.com/llvm/llvm-project/0d261d1ca552c95a8f007e061c787ac7132fbcbc/lld/COFF/Driver.cpp)
uses separate asynchronous file reads on Windows. The external process tree's
resources and the combined tool/publication boundary still require review and
qualification. No production source-change monitoring is implied.

## Driver and verifier observations

On this host, a `clang -###` trace for the C-link probe selected
`C:\Program Files\LLVM\bin\ld.lld` and MinGW startup objects and libraries from
`C:\Users\Ubehage\Documents\WinLibs\mingw64`. `ld.lld.exe --version`
reported LLD 23.1.3; its SHA-256 was
`8D1DD3BA3A3810AFC78A8BD97406B30BC5B9C301F9238224D35D030B0A826680`.
The traced `crt2.o` SHA-256 was
`02C1AD7529DE04A081D522E002B39A7E1CFDCD60CCFC9A4373C282FA24BB3539`.
This is an additional driver trace, not a complete inventory or proof that a
future build resolves the same linker and support inputs.

The test-only `check-driver-linker-identity.ps1` invoked the same unchanged
Clang binary twice with distinct `--ld-path` values. Two separately built test
linkers emitted different markers and deliberately returned failure; each
corresponding marker was observed, Clang failed, and no output executable was
created. The linkers have different hashes. This demonstrates that the same
driver identity does not identify its linker for these two explicit options.
It does not establish how a UBE build discovers, guards or records the actual
child, startup objects, libraries or dynamically loaded dependencies.

```powershell
rtk proxy "C:\Program Files\LLVM\bin\clang.exe" --target=x86_64-w64-windows-gnu -std=c17 -Wall -Wextra -Werror compiler/UBE_Compiler_v3/tests/native-executable/verifier/linker-identity-probe.c -o bootstrap/out/linker-identity-one.exe
rtk proxy "C:\Program Files\LLVM\bin\clang.exe" --target=x86_64-w64-windows-gnu -std=c17 -Wall -Wextra -Werror -DALTERNATE_LINKER compiler/UBE_Compiler_v3/tests/native-executable/verifier/linker-identity-probe.c -o bootstrap/out/linker-identity-two.exe
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/verifier/check-driver-linker-identity.ps1 -Clang "C:\Program Files\LLVM\bin\clang.exe" -FirstLinker bootstrap/out/linker-identity-one.exe -SecondLinker bootstrap/out/linker-identity-two.exe -OutputDirectory bootstrap/out/driver-linker-identity
```

The trace for an IR compile with `-Xclang -llvm-verify-each` contained both
`-disable-llvm-verifier` and `-llvm-verify-each`. Their simultaneous appearance
does not establish verifier behavior or precedence. The test-only
`check-verifier-modes.ps1` instead ran valid and invalid-dominance IR through
the actual driver at O0 and O2, with and without the explicit verify-each
option. All four valid runs created objects; all four invalid runs returned 1,
reported the dominance error and created no object. This is one invalid IR
case, not proof that default compilation verifies every invariant.

```powershell
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/verifier/check-verifier-modes.ps1 -Clang "C:\Program Files\LLVM\bin\clang.exe" -OutputDirectory bootstrap/out/verifier-modes
```

## Streaming a held IR file after a path swap

`check-ir-stream-swap.ps1` opens the valid IR fixture for read without write
sharing, moves its pathname and substitutes the invalid-dominance fixture at
the original name. A new write-open to the held original was denied. The
script independently hashed the open original, rewound it before each run,
and streamed its bytes twice to Clang using `-x ir -` and `-llvm-verify-each`.
Both invocations succeeded and produced objects with equal hashes. Streaming the
substituted file instead produced the expected dominance diagnostic and no
object. This command returned 0:

```powershell
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/verifier/check-ir-stream-swap.ps1 -Clang "C:\Program Files\LLVM\bin\clang.exe" -OutputDirectory bootstrap/out/ir-stream-swap
```

This is a test-only streaming handoff to Clang, with verification and compilation
in each invocation; it is not a separate verifier-to-compiler binding proof.
It does not qualify the production process boundary, bounded diagnostic capture,
descendants, cancellation, partial or broken input, all IR, linking, or final
publication. Streaming would require an explicit change to the current closed-input
proposal and remains unselected.

`check-ir-path-guard.ps1` tests a separate pathname-based option compatible
with closed stdin. On this host, a pre-existing writable handle prevented a
read-only-sharing guard; once acquired, that guard prevented a new writer and
moving the test file name. Clang then compiled and verified the guarded valid
IR twice. After releasing the guard, the test moved the valid file, put the
invalid-dominance fixture at the original path, and observed the expected
rejection with no object. The held input's hash matched the independent valid
fixture. Command:

```powershell
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/verifier/check-ir-path-guard.ps1 -Clang "C:\Program Files\LLVM\bin\clang.exe" -OutputDirectory bootstrap/out/ir-path-guard
```

In the latest run the object hashes matched; an earlier run observed a mismatch,
so equality is recorded rather than required. This is a single ordinary file
on one host. It does not prevent or test parent-component redirection, all
writable mappings, tool substitution, full process containment, or separate
validator-to-compiler handoff. A guard on the final file name alone is not a
qualified path chain or selected production boundary.

`check-ir-junction-swap.ps1` supplies a controlled counterexample to relying on
the held final-file guard alone. It first compiled valid IR through a junction
while holding that file open with read-only sharing. It then moved the junction,
substituted one pointing to invalid-dominance IR, and compiled the same selected
path again. Clang rejected the substituted IR, while the held file still hashed
to the valid fixture and the selected path hashed to the invalid fixture. The
command returned 0:

```powershell
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/verifier/check-ir-junction-swap.ps1 -Clang "C:\Program Files\LLVM\bin\clang.exe" -OutputDirectory bootstrap/out/ir-junction-swap
```

This demonstrates a parent-junction redirection on one host; it does not test a
complete path guard, all reparse types, or a production verifier-to-compiler
boundary. It complements rather than invalidates the ordinary-file guard result.

The same harness with `-JunctionGuard bootstrap/out/native-junction-guard.exe`
also tested the existing separate junction guard. The guard signaled readiness,
the controlled junction move was denied, and Clang still compiled valid IR.
After guard release, the junction move and substituted-invalid-IR control
succeeded. Both this guarded run and the unguarded run returned 0:

```powershell
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/verifier/check-ir-junction-swap.ps1 -Clang "C:\Program Files\LLVM\bin\clang.exe" -OutputDirectory bootstrap/out/ir-junction-swap -JunctionGuard bootstrap/out/native-junction-guard.exe
```

This combines one existing junction guard and the final-file guard with actual
Clang input on the local host. The junction guard is separately acquired; the
test does not qualify safe acquisition of a whole path, ancestor changes, all
reparse mutations, or the actual compiler process boundary.

`check-ir-mapping-guard.ps1` separately tested a pre-existing writable mapping
of the valid IR fixture. Before attempting the guard, the test changed a byte
through the mapping, observed that change through an independent file handle,
and restored it. On this host, the writable mapping prevented acquisition of
the read-only-sharing guard. After the mapping was released, the guard could be
acquired, the restored file hash matched the fixture, and Clang compiled it.
The command returned 0:

```powershell
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/verifier/check-ir-mapping-guard.ps1 -Clang "C:\Program Files\LLVM\bin\clang.exe" -OutputDirectory bootstrap/out/ir-mapping-guard
```

The script also checks and reports the adverse outcome if another host allows
guard acquisition and the existing mapping changes the held bytes. This is one
mapping and sharing combination, not qualification of every filesystem,
mapping type, parent path, or real compiler handoff.

`check-ir-stream-debug.ps1` separately generates optimized debug LLVM from the
existing C debug fixture and compiles the same IR from a path and from standard
input. GNU objdump observed `probe.c`, `double_value` and a decoded line 3 in
both objects; deliberately wrong source, procedure and line expectations were
rejected. The two object hashes matched in this one run. Command:

```powershell
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/verifier/check-ir-stream-debug.ps1 -Clang "C:\Program Files\LLVM\bin\clang.exe" -Objdump C:\Users\Ubehage\Documents\WinLibs\mingw64\bin\objdump.exe -OutputDirectory bootstrap/out/ir-stream-debug
```

The script was then extended to link and run both objects. Both returned 8.
It compared decoded line addresses with disassembled symbol ranges: line 3 fell
within `double_value`, and line 7 within `main`; swapping those associations
was rejected. The command above passed again. These checks cover two ranges in
one C-derived fixture; optimization may fold the call in `main`, so they do not
show that `double_value` actually ran. They do not establish debugger behavior,
generated UBE code, all source paths, or the final debug contract. Streaming
remains unqualified for production.

The same script now accepts `-Behavior`, `-MutateCalls` and `-NoDebug`. With
`-Behavior`, it uses the separate no-inline function whose volatile counter
must be incremented once for Main to return 8. Both path and streamed IR builds
returned 8 with and without debug information; the mutated two-increment control
returned 99 in both modes and both handoffs. For debug builds the comparator
also checked the function's side-effect line and Main's call line against their
linked symbol ranges, rejecting swapped associations. For no-debug builds it
checked for absence of the fixture's matching source records. The command above
was rerun once for each of `-Behavior`, `-Behavior -MutateCalls`,
`-Behavior -NoDebug`, and `-Behavior -MutateCalls -NoDebug`; all returned 0.
An earlier version of the comparator overlooked object line addresses printed
as bare zero and was corrected before the passing runs. Across these separate
experiments object hashes sometimes differed, so one matching pair is not a
determinism guarantee. These C host controls do not demonstrate UBE execution,
an operational debugger, or runtime visibility of optimized variables.
