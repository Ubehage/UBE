# Generated native target ownership evidence

TryValidateNativeGeneratedTarget relates a qualified named relocation target and
signed effective position to its frozen generated definition and retained image
range. Direct transfers require the exact generated entry; data/address accesses
must fit frozen storage with compatible permissions and ordinary/TLS domain.
The contract is in NATIVE-TARGET-OWNERSHIP-IMPLEMENTATION.md.

The component fixture has 26 independent role/extent cases, 34 malformed or
mismatched descriptor cases, explicit one-past-end controls, one-event/zero-byte
budget and cancellation checks, immutable inputs, Err preservation, allocator
independence, root refusal and forced Boolean-result controls.

The retained image gate binds producer objects/frozen rows once per image and
reader. A test-only transport retains those qualified records; every frozen row
and full image range is independently compared before use. The consumer then
combines current instruction decoding, named/constant binding, signed linked
targets and generated-owner access checks. Wrong destination, symbol identity,
owner address and operand width are negative controls. The separate reference
cell/import/TLS/CRT classes remain explicit unfinished work.

## Qualification - 2026-11-04

Commands from the repository root:

~~~powershell
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/objects/check.ps1 -DiagnosticOnly
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/objects/check-instructions.ps1 -ReaderReport bootstrap/out/native-objects/c27cd1499b03447ba4d728af35d5364d/report.json -BindingReport bootstrap/out/native-extent-bindings/1ee39e22ed974005bec0d08bcd718b3f/report.json -WholeCode
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/objects/check-instructions.ps1 -ReaderReport bootstrap/out/native-objects/c27cd1499b03447ba4d728af35d5364d/report.json -BindingReport bootstrap/out/native-extent-bindings/1ee39e22ed974005bec0d08bcd718b3f/report.json
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/objects/check-fixups.ps1 -ReaderReport bootstrap/out/native-objects/c27cd1499b03447ba4d728af35d5364d/report.json -BindingReport bootstrap/out/native-extent-bindings/1ee39e22ed974005bec0d08bcd718b3f/report.json -InstructionReport bootstrap/out/native-code-instructions/34a0e7e6a8014b39878168aff93cecae/report.json -GeneratedTargets
~~~

All passed. Report paths below are relative to bootstrap/out:

| Gate | Report | Groups | Commands | Summed child ms | Input records |
| --- | --- | ---: | ---: | ---: | ---: |
| Component | native-objects/c27cd1499b03447ba4d728af35d5364d/report.json | 96 | 195 | 666538 | 107 |
| Complete instructions | native-code-instructions/34a0e7e6a8014b39878168aff93cecae/report.json | 2240 | 2352 | 52492 | 258 |
| Retained leaves | native-instructions/8bfb9584b23941b786417d6b15abd91b/report.json | 128 | 160 | 4122 | 146 |
| Generated targets, signed targets and fixups | native-fixups/eaaf678cd8144ab4a9f42e0e2ed67a4f/report.json | 2784 | 2788 | 129922 | 1115 |

Both bootstrap stages pass 41,965,983 component assertions. Raw LLVM is identical:
1,862,200 bytes, SHA-256
28B98DFDCB0C218EADD1CE48E187F25F7E1B7A654CEB488A470B17A61C12CE6B.
NativeBindings.bas is 21,722 bytes, SHA-256
9205B9741A7DB41BB9407F387794F5841443A31781A5C4C1DB93B7B2F0BDB0C5.
NativeRelocations.bas is 16,071 bytes, SHA-256
1BC71155D17901B673F613F8CEA0FF90F628F643458788C7E7273637CA7660A7.
Its existing range predicate is now shared; its behavior is unchanged.

The complete instruction gate retains all 36,192 instructions and 5,712 relocation
fields, including 1,792 negative controls. The leaf gate retains 2,496 instruction
observations and 64 rejections. The generated-target matrix binds all nine producer
units for each image and independently compares 42 retained definitions per image:
32 reader/image comparisons, or 1,344 definition observations over 16 images.

Both readers pass all 3,128 generated references: 1,512 function-entry references,
728 ordinary data accesses and 888 TLS member accesses. This gives 6,256 generated
observations within the existing 11,424 signed-target/field observations and 288
object/image comparisons. All 896 new generated-owner controls, 896 retained signed
target/placement controls and 672 retained encoding controls reject (2,464 total).
The matrix keeps reference cells, IAT, TLS-index, anonymous constants and explicit
CRT targets outside this generated-owner consumer. The earlier signed-target checks
continue to cover their field correspondence without claiming their full meaning.

The final SHA-256 audit confirms all 572 distinct input paths across these four
gates unchanged: bootstrap/out/native-generated-target-input-audit.json. The
PowerShell syntax check, ten edited source/test/contract whitespace checks and
git diff --check pass. These are verification-only source consistency checks;
production does not monitor or reject source changes. Child durations establish
bounded test completion, not compiler performance. Production resource caps and
the existing 720-second component-test deadline remain unchanged. The complete
bootstrap and final native build were not rerun or claimed complete.

## Diagnostic history and limits

A focused first-stage --generated-targets run passed. The separate diagnostic in
bootstrap/out/native-generated-target-focused/9a64036eb8814c748f0d29315af68ab6
bound 42 frozen definitions, independently compared all their ranges and checked
130 generated targets within one 261-field object/image pair. The completed
maintained gates above supersede those focused runs for qualification.

The initial component run 908239d64bb44f869cef672e4fd6d6c7 was deliberately stopped
after identifying a forced-result test-order issue: a budget refusal would be
observed before the harness's expected candidate mismatch. The test now includes
an explicit one-past-owner rejection before the budget checks. The stopped run
is not qualification evidence; no artifacts from it are used by the new gates.

This consumer does not establish global alias exclusion, full function extents,
call/tail ABI, TLS base provenance, indirect callees, pointer/register propagation,
complete control flow or native build/publication acceptance. The original goal
remains active and incomplete.
