# Native TLS storage association evidence

The implementation contract is NATIVE-THREAD-STORAGE-IMPLEMENTATION.md.
TryReadNativeThreadStorage prepares complete directory, template, loader-index
and callback-array ranges. TryBindNativeThreadIndex binds exact four-byte
RIP-relative index reads. TryValidateNativeThreadMember checks producer-bound
TLS members against the template origin, complete geometry and zero initialization.
Per-use SECREL width/offset checking remains in the existing generated-target
validator. The member validator can be used once per immutable bound definition;
it has no instruction parameter and introduces no hidden cache or owner arena.

NativeObjects shares the existing overlap predicate formerly private to imports;
NativeBindings exposes its existing retention-permission predicate. Directory,
section/range mapping and isolation machinery is reused. No new intrinsic,
external dependency, language behavior, resource cap or compiler phase is added.

## Qualification - 2026-11-04

Commands executed from the repository root:

~~~powershell
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/objects/check.ps1 -DiagnosticOnly
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/objects/check-instructions.ps1 -ReaderReport bootstrap/out/native-objects/8ecde2f7f8c14e389ad2b9dfd3ef4d9a/report.json -BindingReport bootstrap/out/native-extent-bindings/a7ef821e947647789217975145a7a058/report.json -WholeCode
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/objects/check-instructions.ps1 -ReaderReport bootstrap/out/native-objects/8ecde2f7f8c14e389ad2b9dfd3ef4d9a/report.json -BindingReport bootstrap/out/native-extent-bindings/a7ef821e947647789217975145a7a058/report.json
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/objects/check-unwind.ps1 -ReaderReport bootstrap/out/native-objects/8ecde2f7f8c14e389ad2b9dfd3ef4d9a/report.json -GraphReport bootstrap/out/native-graph/3ae0e5a87d014b82a61adaae0cc28595/report.json
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/objects/check-image-unwind.ps1 -ReaderReport bootstrap/out/native-objects/8ecde2f7f8c14e389ad2b9dfd3ef4d9a/report.json -RetentionReport bootstrap/out/native-retention/876d3469520c48f981ea378503704593/report.json
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/objects/check-extent-bindings.ps1 -ReaderReport bootstrap/out/native-objects/8ecde2f7f8c14e389ad2b9dfd3ef4d9a/report.json -GraphReport bootstrap/out/native-graph/3ae0e5a87d014b82a61adaae0cc28595/report.json -RetentionReport bootstrap/out/native-retention/876d3469520c48f981ea378503704593/report.json
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/objects/check-fixups.ps1 -ReaderReport bootstrap/out/native-objects/8ecde2f7f8c14e389ad2b9dfd3ef4d9a/report.json -BindingReport bootstrap/out/native-extent-bindings/9bc69abe9ea945a79ee433f182ad2e16/report.json -InstructionReport bootstrap/out/native-code-instructions/7d168a969e0f4a3582ab8310b3d04733/report.json -ThreadStorage
~~~

All seven gates passed. Paths below are relative to bootstrap/out:

| Gate | Report | Groups | Commands | Summed child ms | Input records |
| --- | --- | ---: | ---: | ---: | ---: |
| Component | native-objects/8ecde2f7f8c14e389ad2b9dfd3ef4d9a/report.json | 126 | 255 | 863958 | 117 |
| Complete instructions | native-code-instructions/7d168a969e0f4a3582ab8310b3d04733/report.json | 2240 | 2352 | 60300 | 268 |
| Retained leaves | native-instructions/8f9b321a4b4741dfba8ab218d60ce95e/report.json | 128 | 160 | 6577 | 156 |
| Object unwind | native-unwind/03b3ae50f2d347a992799ae5bf6f0963/report.json | 288 | 576 | 19512 | 268 |
| Image function tables | native-image-unwind/f1f4f82b655b4bbbb7e62982f4ead257/report.json | 32 | 48 | 3460 | 140 |
| Retained extent bindings | native-extent-bindings/9bc69abe9ea945a79ee433f182ad2e16/report.json | 416 | 576 | 38957 | 433 |
| TLS/import/reference/generated/signed targets | native-fixups/fa118c9d682e4ebaadd45be7154e8816/report.json | 4064 | 4068 | 206733 | 1183 |

Both compiler stages pass 48,258,803 component assertions. The literal TLS
fixture has independent complete 232-byte state and index-range expectations,
40 metadata mutations, 21 index-descriptor mutations and 17 member-descriptor
mutations. It checks mapping, alignment, permissions, callback termination/code
locations, pairwise data isolation, exact template origin, index initialization
and first/last Err-record bytes. An empty callback array and larger alignment
are positive cases. Metadata is distinct from callback behavior qualification.

The focused metadata fixture observes 1,924 bytes and 487 events. Explicit
oracles fix the index check at zero bytes/one event, the eight-byte floor member
at eight bytes/two events and the 784-byte Err member at 784 bytes/99 events.
Both stages pass physical byte/event observation, exact and insufficient budgets,
every observed cancellation point, allocator independence, actual root refusal,
immutable input and prior Err-number checks, atomic old-result retention,
corrupted prepared-state/index outputs and forced Boolean controls.

Raw LLVM is identical: 2,051,421 bytes, SHA-256
52B52CB0304D6CC1FB1ECEDA098F78C444D34A5873AA2D1F5122EDC13AF2F0DC.
Current source identities:

| Source | Bytes | SHA-256 |
| --- | ---: | --- |
| NativeThreadStorage.bas | 13140 | CA9F09E7D9F90BCD84490A7A87A7D0CA3068F5362B2FA01FD98009BFAC57D1EB |
| NativeObjects.bas | 21141 | 7D56F1A9CC09B5624578FBBED3ED25C7294A02595CAA52631508CA3F6FB135ED |
| NativeImports.bas | 13948 | 927E435656E3C403F88F85B49BBF36F73413451E39F1438C0DAA285DFC6760A8 |
| NativeBindings.bas | 26453 | A636F0809B1D50EFB721507A86CCD68984FA67B1D9B23A5200870CDF5571E47D |

The retained TLS oracle derives ranges from named CRT anchors and frozen producer
extents independently of the TLS directory pointer values under test. It compares
all four complete ranges, alignment and status before checking references.
The frozen floor/Err extents determine the 800-byte template. It separately
checks the two named callback entries and their terminating null, and the zero
index initializer. These checks establish the observed identities, not their
complete CRT execution effects.

Both readers match 592 TLS-index references (1,184 observations) and 888 TLS
member references (1,776 observations). Shifted index positions, altered index
anchor addresses, nonzero member initializer bytes and altered retained member
addresses reject in every applicable object through both stages: 640 new
controls. Together with the retained 3,104 controls, all 3,744 target/encoding
negative controls reject. The matrix retains all 80 imports, 1,880 reference
loads, 3,128 generated references, 5,712 signed fields, 32 frozen-owner comparisons
and 288 object/image comparisons.

The complete instruction gate retains 36,192 instruction observations and 1,792
controls. Leaves retain 2,496 observations and 64 controls. Shared-reader gates
retain 720 object unwind observations, 2,352 image table observations and 720
bound extents, including 128 extent-mutation rejections.

The final verification-only audit confirms all 645 distinct input paths across
these seven reports and three retained pointer/directory diagnostics unchanged:
bootstrap/out/native-thread-storage-input-audit.json. The exact procedure imports
bootstrap/out/audit-native-thread-storage-inputs.mjs through the available Node
REPL and calls its exported auditReports with the repository root and these
seven absolute report paths. It compares every SHA-256/byte identity and rejects
conflicting records. Production does not monitor, reject or retry source changes.
PowerShell syntax and edited-file whitespace checks pass.

Full probes took 160731 and 155935 ms; summed component child time is 863958 ms.
Existing 240-second full-probe and 900-second enclosing test allowances remain
unchanged. These are test-completion measurements, not compiler-performance
qualification. No fresh full bootstrap, builder integration or final native
acceptance is claimed.

## Focused checks and continuation

The first-stage --thread-storage probe passed before the complete gate. The
focused platform image comparison passed eight signed fields, one generated
reference, one reference cell, five imports, one index read and one TLS member;
all four TLS corruptions rejected with 1506. Its independent serialization
comparison matched the complete expected TLS state. Commands/results are under
bootstrap/out/native-thread-storage-focused/0209418e2c4647b684e2d780123f6f8b.
The maintained gates above supply the qualification result.

NATIVE-IMAGE-POINTER-INVESTIGATION.md now classifies all 49 absolute pointer
fields per image, including the earlier 36 unclassified fields. Its retained
16-image diagnostic has 18 input identities and keeps unresolved CRT/function
entry and runtime-effect obligations explicit. Next implement bounded base-
relocation validation and bind the required pointer writes/values. Preserve the
TLS base/index register chain, global storage aliases, CRT callbacks/startup,
whole-function control/dataflow, stack/reserve, debug, builder ownership and
final acceptance requirements. The original native-executable goal stays active.
