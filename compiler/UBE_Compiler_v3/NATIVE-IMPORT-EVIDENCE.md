# Native import-address association evidence

The implementation contract is NATIVE-IMPORT-IMPLEMENTATION.md.
TryBindNativeImportTarget binds an exact aligned eight-byte RIP-relative read to
one ordinary unbound import slot with a frozen DLL/function identity. It checks
complete descriptor/thunk termination, matching lookup/IAT values, initialized
resident storage, unique target ownership and metadata isolation from IAT writes.
The complete cell range publishes only after all descriptors pass.

NativeObjects now shares the existing unique initialized image-span mapper and
PE directory-header reader previously used by NativeUnwind. Its range helper
constructs a complete initialized range. NativeUnwind retains its directory-
specific absence, size, alignment and permission checks. NativeBindings exposes
the existing anchor comparison; no second copy of those mechanisms was added.

## Qualification - 2026-11-04

Commands executed from the repository root:

~~~powershell
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/objects/check.ps1 -DiagnosticOnly
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/objects/check-instructions.ps1 -ReaderReport bootstrap/out/native-objects/9d30e5d75f1745baac27187da3281caa/report.json -BindingReport bootstrap/out/native-extent-bindings/1ee39e22ed974005bec0d08bcd718b3f/report.json -WholeCode
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/objects/check-instructions.ps1 -ReaderReport bootstrap/out/native-objects/9d30e5d75f1745baac27187da3281caa/report.json -BindingReport bootstrap/out/native-extent-bindings/1ee39e22ed974005bec0d08bcd718b3f/report.json
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/objects/check-unwind.ps1 -ReaderReport bootstrap/out/native-objects/9d30e5d75f1745baac27187da3281caa/report.json -GraphReport bootstrap/out/native-graph/3ae0e5a87d014b82a61adaae0cc28595/report.json
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/objects/check-image-unwind.ps1 -ReaderReport bootstrap/out/native-objects/9d30e5d75f1745baac27187da3281caa/report.json -RetentionReport bootstrap/out/native-retention/876d3469520c48f981ea378503704593/report.json
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/objects/check-extent-bindings.ps1 -ReaderReport bootstrap/out/native-objects/9d30e5d75f1745baac27187da3281caa/report.json -GraphReport bootstrap/out/native-graph/3ae0e5a87d014b82a61adaae0cc28595/report.json -RetentionReport bootstrap/out/native-retention/876d3469520c48f981ea378503704593/report.json
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/objects/check-fixups.ps1 -ReaderReport bootstrap/out/native-objects/9d30e5d75f1745baac27187da3281caa/report.json -BindingReport bootstrap/out/native-extent-bindings/a7ef821e947647789217975145a7a058/report.json -InstructionReport bootstrap/out/native-code-instructions/780d119dfe1a48fc96cf8bb0036fcc55/report.json -ImportTargets
~~~

All seven gates passed. Report paths below are relative to bootstrap/out:

| Gate | Report | Groups | Commands | Summed child ms | Input records |
| --- | --- | ---: | ---: | ---: | ---: |
| Component | native-objects/9d30e5d75f1745baac27187da3281caa/report.json | 108 | 219 | 771058 | 113 |
| Complete instructions | native-code-instructions/780d119dfe1a48fc96cf8bb0036fcc55/report.json | 2240 | 2352 | 57815 | 264 |
| Retained leaves | native-instructions/e44678f3e216404ab8d2955b4492bbcf/report.json | 128 | 160 | 5637 | 152 |
| Object unwind | native-unwind/88a19a58c60048ebaef5ae8491bd6b9e/report.json | 288 | 576 | 17960 | 264 |
| Image function tables | native-image-unwind/7fec6295db014735aed2f788aa40d715/report.json | 32 | 48 | 2128 | 136 |
| Retained extent bindings | native-extent-bindings/a7ef821e947647789217975145a7a058/report.json | 416 | 576 | 37162 | 429 |
| Import/reference/generated/signed targets | native-fixups/bd503b8cb0644bc8bd4a6c82e8850be1/report.json | 3424 | 3428 | 163405 | 1159 |

Both stages pass 46,160,914 component assertions. The independent literal import
fixture covers direct directory/range results, 19 descriptor/access mutations,
33 image mutations, DLL case folding and case-sensitive procedure identity,
read-only/writable IAT storage, duplicate ownership and metadata overlap,
null termination, unsupported binding/ordinal encodings and malformed names.
It observes exactly 737 bytes and 234 events for its positive import case,
checks both budget boundaries and every cancellation point, allocation/copy
independence, actual root refusal, immutable inputs, prior Err number preservation
and complete old-result retention. Corrupted range and forced true/false controls
reject through both stages. Existing unwind component costs remain 136 bytes/35
events for the function table and 252/65 and 260/67 for the two extents.

Raw LLVM is identical: 1,978,935 bytes, SHA-256
34D109904D98C943377DD7BC5937379ED457EAB3E4A4BFDE44EDF32A0C6C50EA.
Current implementation identities:

| Source | Bytes | SHA-256 |
| --- | ---: | --- |
| NativeImports.bas | 14246 | 2C45E5FB80456B39A0E130F161FDA465F7AA08ED279D29CD067DAA8F97EBB698 |
| NativeObjects.bas | 20867 | 22A2B513EA91145FAE47D6648A7A859945CE952D676BA61E19EF38EA20EEE482 |
| NativeUnwind.bas | 13813 | 670A31F0B8103E975E0EA009A17AE02A666E719C2A686ABAA7EFEF7E8750141F |
| NativeBindings.bas | 26461 | B61134363A0875843B3CECAFD77D778DD7FA49F9D264EE64F4ED57B3FCDC9AC9 |

The target gate independently freezes KERNEL32.dll and the four generated API
names ExitProcess, Sleep, TerminateProcess and VirtualQuery. Its expected names
do not come from the candidate import descriptors. Both readers match all 80
import references in 16 platform objects (160 observations), and compare each
complete cell range with the independent symbol/section oracle. Wrong frozen
DLL, wrong API, shifted slot and changed IAT value reject in every platform
object through both readers: 128 new controls. Together with the retained 2,976
target/encoding controls, all 3,104 negative controls reject.

The same matrix retains 1,880 reference-pointer uses, 3,128 generated references,
all 5,712 signed fields, 32 frozen-owner comparisons and 288 object/image
comparisons. Complete instruction qualification retains 36,192 instruction
observations, 5,712 fields and 1,792 controls; retained leaves keep 2,496
observations and 64 controls. Shared-reader regressions pass 720 object unwind
observations, 2,352 image function-table observations and 720 bound extents,
including 128 extent-mutation rejections.

The final input audit confirms all 622 distinct input paths across these seven
gates and the retained reference-cell/PE-directory diagnostics unchanged.
bootstrap/out/native-import-input-audit.json records the result. The exact audit
procedure uses the available Node REPL to import
bootstrap/out/audit-native-import-inputs.mjs and call its exported auditReports
with the repository root and the seven absolute report paths listed above.
A command-line node attempt could not start because node is absent from PATH;
the audit then completed through the available Node runtime. The audit compares
all recorded SHA-256/byte identities and rejects conflicting records.
Source consistency checking is verification-only; production does not monitor,
reject or retry source changes. PowerShell syntax and edited-file whitespace
checks pass. A repository-wide whitespace check separately finds an existing
trailing-space line in samples/01-hello-ube/src/Main.bas, outside this change.

The two full probes took 164710 and 156269 ms; summed component child time is
771058 ms. Existing 240-second full-probe and 900-second enclosing test allowances
remain unchanged, as do all production caps. These times establish bounded test
completion, not compiler-performance qualification. The full bootstrap and final
native build were not rerun or qualified by these component/retained gates.

## Focused diagnostics and continuation

Before the complete gate, stage0-probe.exe --imports passed the literal fixture.
The focused actual platform driver passed eight signed fields, one generated
reference, one reference cell and five imported accesses; all four import
mutations rejected with 1506. Its command/results remain under
bootstrap/out/native-import-focused/fb7bcc89040b40228f4034ee666f6650.
The maintained gates above supply the qualification result.

Next bind the TLS index and generated TLS extents to the actual PE template.
The subsequent runtime base/index register chain, image DIR64 rebasing, remaining
global aliases, CRT callbacks/startup, whole-function dataflow/control flow,
stack/reserve and debug checks, builder ownership and final acceptance remain
required. IAT identity does not prove API signatures/effects, register propagation
or arbitrary loader/CRT behavior. The original native-executable goal stays active.
