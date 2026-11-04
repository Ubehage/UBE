# Native image relocation evidence

The scoped contract is NATIVE-IMAGE-RELOCATION-IMPLEMENTATION.md. The new
TryValidateNativeImageRelocations consumes a complete independently established
field/target RVA table, validates the bounded PE base-relocation stream, and
requires exact membership and preferred-base values. It publishes the directory
range only after the entire stream and expected table match.

NativeObjects extracts the existing bounded image-header reader without changing
the directory reader's byte/event costs. NativeBindings exposes its existing
scalar-expectation length binding. No new intrinsic, external dependency,
payload owner, production resource cap or language behavior is introduced.
The production manifest and existing bootstrap component gate include the module.

## Qualification - 2026-11-04

All eight gates below pass, followed by the unchanged-input identity audit.
This qualifies the bounded relocation/association goal, not the full
native-executable deliverable.

Commands executed from the repository root:

~~~powershell
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/objects/check.ps1 -DiagnosticOnly
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/objects/check-image-relocations.ps1 -ReaderReport bootstrap/out/native-objects/945307b38c3a43fb90821210110ac2ef/report.json -RetentionReport bootstrap/out/native-retention/876d3469520c48f981ea378503704593/report.json
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/objects/check-instructions.ps1 -ReaderReport bootstrap/out/native-objects/945307b38c3a43fb90821210110ac2ef/report.json -BindingReport bootstrap/out/native-extent-bindings/a7ef821e947647789217975145a7a058/report.json -WholeCode
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/objects/check-instructions.ps1 -ReaderReport bootstrap/out/native-objects/945307b38c3a43fb90821210110ac2ef/report.json -BindingReport bootstrap/out/native-extent-bindings/a7ef821e947647789217975145a7a058/report.json
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/objects/check-unwind.ps1 -ReaderReport bootstrap/out/native-objects/945307b38c3a43fb90821210110ac2ef/report.json -GraphReport bootstrap/out/native-graph/3ae0e5a87d014b82a61adaae0cc28595/report.json
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/objects/check-image-unwind.ps1 -ReaderReport bootstrap/out/native-objects/945307b38c3a43fb90821210110ac2ef/report.json -RetentionReport bootstrap/out/native-retention/876d3469520c48f981ea378503704593/report.json
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/objects/check-extent-bindings.ps1 -ReaderReport bootstrap/out/native-objects/945307b38c3a43fb90821210110ac2ef/report.json -GraphReport bootstrap/out/native-graph/3ae0e5a87d014b82a61adaae0cc28595/report.json -RetentionReport bootstrap/out/native-retention/876d3469520c48f981ea378503704593/report.json
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/objects/check-fixups.ps1 -ReaderReport bootstrap/out/native-objects/945307b38c3a43fb90821210110ac2ef/report.json -BindingReport bootstrap/out/native-extent-bindings/993405c3268a446da0588ad5bfa6fa6f/report.json -InstructionReport bootstrap/out/native-code-instructions/61f127d884c2481ea61e62ddeaab7873/report.json -ThreadStorage
~~~

Report paths are relative to bootstrap/out:

| Gate | Report | Groups | Commands | Summed child ms |
| --- | --- | ---: | ---: | ---: |
| Component | native-objects/945307b38c3a43fb90821210110ac2ef/report.json | 132 | 267 | 943668 |
| Image pointers | native-image-relocations/411c1c0619984a3daef98713c1d769ff/report.json | 34 | 36 | 74715 |
| Complete instructions | native-code-instructions/61f127d884c2481ea61e62ddeaab7873/report.json | 2240 | 2352 | 60529 |
| Retained leaves | native-instructions/654a0a2bf8f144c29a7e32a503f863bc/report.json | 128 | 160 | 6057 |
| Object unwind | native-unwind/67e0177380b444dc87314daf044744a7/report.json | 288 | 576 | 17664 |
| Image function tables | native-image-unwind/c95298af7feb493595f40573925bffa9/report.json | 32 | 48 | 3184 |
| Retained extents | native-extent-bindings/993405c3268a446da0588ad5bfa6fa6f/report.json | 416 | 576 | 37858 |
| TLS/import/reference/generated/signed targets | native-fixups/49d10259e92b4f74a772117b88dc8ff1/report.json | 4064 | 4068 | 206890 |

Both reader stages pass 50,356,397 component assertions and emit byte-identical
raw LLVM: 2,088,189 bytes, SHA-256
DD6347A0D2F2A9BFDD7943219D62E9E956C6F0B424C978AE166E3B388D2046D6.

| Source | Bytes | SHA-256 |
| --- | ---: | --- |
| NativeImageRelocations.bas | 5995 | C69D9A74C3D31CD6F66501DEF3BD2B1B97EC14D50B138EB48026AE48B91DA483 |
| NativeObjects.bas | 22056 | 5F1B8EAFF5FD7FEBEC5F0C38CC534128E2E4399A2B80DE40134EA5B9FB3AFE39 |
| NativeBindings.bas | 26521 | E5E1055693371FC2915B9D5A1437549A6DCCC6388B41F07B23B368A03FAFBD98 |

The literal fixture has a complete independently fixed 56-byte directory-range
oracle. It passes 33 malformed candidate/association cases, invalid caller
shapes, positive RVA-zero/padding/empty-block cases, physical byte/event
accounting, exact and insufficient budgets, every observed cancellation point,
allocation independence, actual root refusal, immutable inputs, preserved Err number
and atomic old-result retention. Corrupted output and forced Boolean controls
reject through both stages. The separate matrix also checks eight focused
range/permission/array-shape refusals with changed field expectations so an
earlier field mismatch cannot hide the relevant refusal.

The independently frozen literal cost is 1,198 bytes and 311 events, checked by
both matrix executables. The retained-image costs are 58,534 bytes / 14,759
events or 66,534 bytes / 16,759 events, according to their section inventory.
There is no payload allocation or copying in the consumer. It traverses the
relocation stream once, using the existing bounded section mapping and isolation
checks for each field; it does not repeatedly scan the full relocation table.

All 49 pointer fields in each of 16 images match through both readers: 1,568
field observations. Every field is independently omitted, redirected and given
an altered value; all 4,704 mutations reject. The oracle derives 48 field/target
relationships per image from named anchors, including explicit __ImageBase RVA
zero and the destructor cursor offset. The unnamed CRT constructor uses a frozen
artifact observation; its callable entry/extent and effects remain unqualified.
Relocation entries are read by the host oracle only to select mutation sites,
never to derive the expected pointer inventory or target values.

Sixty-four controlled numeric rebasing cases adjust the header ImageBase and
every expected absolute field by positive/negative deltas, re-read the modified
layout and preserve all field/target associations. This establishes the tested
numeric relation, not Windows loader execution or CRT behavior.

The measured component child time exceeds the prior 900-second enclosing
bootstrap allowance. bootstrap/build-v2.ps1 now permits 1,080 seconds for that
test. Its individual full probes took 203721 and 160334 ms, below the unchanged
240-second child allowance. These measurements are test-completion evidence,
not compiler performance qualification. Production caps are unchanged.

The retained target gate preserves all 592 TLS-index and 888 TLS-member
references through both readers, 640 TLS controls and the earlier 3,104
target/encoding controls. Complete instruction, leaf, unwind and extent gates
remain passing with the shared header extraction.

The final verification-only audit confirms all 652 distinct input paths across
the eight reports and three retained pointer/directory diagnostics unchanged.
The available Node REPL imported
bootstrap/out/audit-native-image-relocation-inputs.mjs and called its exported
auditReports with the repository root and the eight absolute report paths above.
It checks every recorded SHA-256 and byte length and rejects conflicting
identities. Its result is bootstrap/out/native-image-relocation-input-audit.json.
This introduces no Node build dependency or production source monitoring.

An independent read-only agent review found no blocking correctness, budget,
ownership or oracle issue in the scoped change. It reiterated the explicit
constructor-observation and numeric-rebasing limitations below; review is not a
replacement for the executed gates. No qualification process remains running.

Final checks: `rtk proxy powershell -NoProfile -File
bootstrap/out/check-image-relocation-syntax.ps1` passed PowerShell parser checks
for the two edited test scripts and bootstrap/build-v2.ps1. A direct trailing-
whitespace/final-newline scan passed for all ten new/edited component and test
files. `rtk proxy git diff --check` over the changed tracked workplans, compiler
status files, manifest and bootstrap script passed. No commit or push was made.

## Retained failed attempt

The first image-matrix harness compile failed because an outer main macro
collided with the reused probe's own runtime-main wrapper. Its exact report is
native-image-relocations/a4ce7e35fae34660a6b4053c4a2b6c33/report.json. The harness
now renames only the probe's actual main definition in its private generated
copy, leaving the existing runtime wrapper intact. The maintained rerun passes.
No production source change was needed for this harness correction.

## Remaining native obligations

This component consumes a complete caller-established expected pointer set.
It does not establish that set's semantic ownership or safe dereference merely
from numeric equality. Global data aliases/resident storage, TLS register
provenance, CRT callbacks/startup/API effects, unnamed constructor function
identity, whole-function dataflow/control flow and termination, complete stack
reserve/debug proof, native tool/build ownership, warnings/diagnostics and
publication, and final source-cohort/native acceptance remain unfinished.
No fresh full bootstrap, working native build command or full language support
is claimed. The established frontend/checker semantics remain unchanged.
