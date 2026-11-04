# Selected native instruction-reader evidence - 2026-11-03

NativeInstructions implements bounded scalar AMD64 instruction inspection for the
existing code/stack validation work. NATIVE-INSTRUCTION-IMPLEMENTATION.md records
its supported profile, scalar descriptor, ownership and failure contract. Each
accepted instruction is at most 15 bytes; every input byte is read once through
the shared inspection ledger, with no payload allocation or copying. This does
not yet establish complete function extents or stack safety.

## Diagnosis and implementation scope

The focused command
`rtk proxy powershell -NoProfile -File bootstrap/out/check-native-leaf-inventory.ps1`
retains exact tool/object identities and four disassembly commands in
bootstrap/out/native-leaf-inventory/1e982df3f2374736a3f61ae6033648cc/report.json.
Seven distinct name/optimization pairs lack runtime-function records. They include
the O0 Err observer, optimized ordinary/initializer leaves and four optimized Err
routines. The general Err setter has three returns and forward/backward branches;
the clear routine loops. A first-RET boundary rule would omit reachable code.

The reader reports length, flow, written GPRs, memory addressing and displacement/
immediate fields. It recognizes the selected scalar forms and rejects unsupported
prefixes/opcodes/groups with 1506. Truncated inputs cannot consume bytes outside
the caller's supplied range or the architectural instruction limit. Normal RET
is distinguished from fallthrough; its terminal RSP pop is excluded from the
written-register mask as specified by the contract. Calls and stack instructions
remain distinguishable for the future control-flow/stack consumer.

## Commands and current reports

```powershell
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/objects/check.ps1 -DiagnosticOnly
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/objects/check-instructions.ps1 -ReaderReport bootstrap/out/native-objects/5e4110e8ec7f4227be2a9bec7ced912e/report.json -BindingReport bootstrap/out/native-extent-bindings/ce0baffb7fb4484f94f1f154d1f3c8d1/report.json
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/objects/check-extent-bindings.ps1 -ReaderReport bootstrap/out/native-objects/5e4110e8ec7f4227be2a9bec7ced912e/report.json -GraphReport bootstrap/out/native-graph/3ae0e5a87d014b82a61adaae0cc28595/report.json -RetentionReport bootstrap/out/native-retention/62289a8863ae4dd8989b70f70ea69788/report.json
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/objects/check-unwind.ps1 -ReaderReport bootstrap/out/native-objects/5e4110e8ec7f4227be2a9bec7ced912e/report.json -GraphReport bootstrap/out/native-graph/3ae0e5a87d014b82a61adaae0cc28595/report.json
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/objects/check-image-unwind.ps1 -ReaderReport bootstrap/out/native-objects/5e4110e8ec7f4227be2a9bec7ced912e/report.json -RetentionReport bootstrap/out/native-retention/62289a8863ae4dd8989b70f70ea69788/report.json
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/objects/check-bindings.ps1 -ReaderReport bootstrap/out/native-objects/5e4110e8ec7f4227be2a9bec7ced912e/report.json -FramesReport bootstrap/out/native-frames/157eecd5aacd410fade78655207ec826/report.json
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/objects/check-generated.ps1 -ReaderReport bootstrap/out/native-objects/5e4110e8ec7f4227be2a9bec7ced912e/report.json -FramesReport bootstrap/out/native-frames/157eecd5aacd410fade78655207ec826/report.json
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/objects/check-retention.ps1 -ReaderReport bootstrap/out/native-objects/5e4110e8ec7f4227be2a9bec7ced912e/report.json -GraphReport bootstrap/out/native-graph/3ae0e5a87d014b82a61adaae0cc28595/report.json -SupportReport bootstrap/out/explicit-link-inputs/318209f12b5b4f0282acf596c47e6386/report.json
rtk proxy powershell -NoProfile -File bootstrap/out/check-unwind-script-syntax.ps1
rtk proxy git diff --check
```

| Gate | Report under bootstrap/out | Groups | Commands | Summed command ms | Matched input hashes |
| --- | --- | ---: | ---: | ---: | ---: |
| Component | native-objects/5e4110e8ec7f4227be2a9bec7ced912e/report.json | 54 | 111 | 284661 | 75 |
| Selected instructions | native-instructions/cfc6ca1588134886aef54fe5fdbfe443/report.json | 128 | 160 | 3646 | 114 |
| Extent binding | native-extent-bindings/073f91491c7047e484834bafed0e32cb/report.json | 416 | 576 | 37837 | 391 |
| Object ranges | native-unwind/c5d87ec19f334bd0a835b671a1bd4303/report.json | 288 | 576 | 19346 | 226 |
| Image ranges | native-image-unwind/2d67897ed8c449fc99d0c904924183d3/report.json | 32 | 48 | 2644 | 98 |
| Integer data | native-data-bindings/756c13a3e59f43f683e4c1a4bb43182c/report.json | 192 | 192 | 9647 | 145 |
| Generated readers | native-object-inputs/a633c0c7d93846a3a790891873cf9d79/report.json | 224 | 336 | 14493 | 194 |
| Linked retention | native-retention/f608924c3a844ea9a788d6687c316d6b/report.json | 416 | 576 | 27293 | 253 |

All captured hashes match at this checkpoint. The component passes 16,785,841
assertions per bootstrap stage. Both raw outputs are identical: 1,391,393 bytes,
SHA256 3720DC54CF9BB649083420DB6DDF788145F7FE94AC0DB9948136D5C9B75041C7.
NativeInstructions.bas is 17,801 bytes, SHA256
D9810337E1791EE873B0D68CE3A25A0A7AD3D15C30E50C6D3667C53D29C23826.
Six PowerShell parser checks, tracked-file diff checking and explicit untracked-
file trailing-whitespace checks pass.

## Independent coverage

Fifty-two hand-specified encoding vectors check every descriptor field, including
high-byte versus REX low-byte register aliases, extended GPR/SIB fields, GS TLS,
RIP addressing, signed displacement endpoints, 16/32/64-bit immediates, direct and
indirect flow, stack-register writes and the 15-byte compiler NOP form. Every
truncation of each positive encoding rejects. Twenty-four unsupported/malformed
encodings, invalid API bounds, exact/one-below byte/event budgets, cancellation
at every measured event and full root pressure preserve prior outputs on failure.
Physical-byte/event hooks confirm exact charges and no payload allocation/copying;
success preserves Err and the input snapshot. Altered returned lengths and GPR
write masks fail their intended assertions through both stages.

The actual matrix selects all 32 retained objects with observed no-unwind functions
from the preceding qualified binding report, across both generators, root/reference
layouts, O0/O2 and Full/None where such functions occur. LLVM supplies independent
instruction bytes, lengths, flow and signed branch targets; its bytes must match
the input object and instruction sequences must have no gaps or undecoded lines.
Both readers match 2,496 instruction observations in 64 positive comparisons,
including alignment NOPs displayed after functions. GPR writes in these selected
leaf instructions remain volatile. A changed first opcode in each object produces
64 controlled 1506 rejections. These facts do not establish reachability, complete
leaf boundaries, memory safety or a whole-function stack proof.

## Focused corrections and limits

The first component attempt, native-objects/83fa7e0ade964efd9583861ab6f7acf3,
compiled the production reader but the C fixture's generic cases name collided
with an existing included test function. Renaming it to instruction_vectors fixed
the test. A focused recompile against the exact retained production LLVM then
exposed a test expectation that incorrectly classified RET as fallthrough. Full
field output showed the reader's terminal flow was correct; correcting the oracle
required no production change. The focused command was
`rtk proxy powershell -NoProfile -File bootstrap/out/check-instruction-diagnostic.ps1`;
its passing result is bootstrap/out/instruction-diagnostic.json (exit 0, 7,568 ms).

The first actual matrix, native-instructions/d69f0c40b96d4f3cb1dfb91f68f3d78f,
rejected the Windows C: path header as an undecoded hexadecimal instruction line.
Restricting that rejection to disassembly sections retains strict unknown/gap
checks and fixes the test-only locator. No decoder change was needed.

The existing reader gate now uses a 420-second whole-bootstrap deadline: its
measured child commands alone consume 284.661 seconds, leaving inadequate margin
under 300 seconds. This is a test deadline adjustment; production numeric caps
and declaration/body/argument traversal bounds are unchanged. The instruction
module is in the production manifest and component gate. The actual matrix remains
an explicit maintained command pending current link/toolchain proof integration;
the entire bootstrap was not rerun here.

Next implement bounded control-flow traversal that checks branch targets against
instruction boundaries and establishes complete leaf extents. Then qualify object/
image instruction and relocation equality, full unwind/stack/reserve and debug
validation, build ownership, held-file identity and publication. The original
First checked native executable goal remains active and incomplete.

## Complete retained-code instruction comparison - 2026-11-03

The preceding full-code diagnostic rejected 224 instruction observations (112
locations through each reader), all canonical CC/INT3 immediately after calls
to ube.stack.abort (96 locations) or __imp_ExitProcess (16). The decoder now
recognizes unprefixed CC as a one-byte trap, flow=7. It does not authorize trap
execution or classify these bytes as padding. Prefixes on CC and the alternate
CD 03 encoding remain outside the selected profile. Reachable CC still rejects
in the leaf consumer, including a conditional branch to a trap.

The maintained check-instructions.ps1 now has a WholeCode test mode. It selects
all 144 object identities from the retained extent-binding matrix, accounts for
32 empty units, and checks all 112 nonempty executable sections. Independent
LLVM disassembly bytes must match the object exactly and cover every code byte
without gaps, including between function labels and through section end. Unknown
mnemonics/flow forms reject in the oracle. Both production readers must match
each instruction length, flow and signed relative displacement. Default leaf
mode retains its additional volatile-GPR assertion. WholeCode makes no such
leaf-only restriction and does not claim operand or stack safety.

Commands (repository root):

~~~powershell
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/objects/check.ps1 -DiagnosticOnly
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/objects/check-instructions.ps1 -ReaderReport bootstrap/out/native-objects/4f86734b35444fa984485dd64992d465/report.json -BindingReport bootstrap/out/native-extent-bindings/1ee39e22ed974005bec0d08bcd718b3f/report.json -WholeCode
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/objects/check-instructions.ps1 -ReaderReport bootstrap/out/native-objects/4f86734b35444fa984485dd64992d465/report.json -BindingReport bootstrap/out/native-extent-bindings/1ee39e22ed974005bec0d08bcd718b3f/report.json
~~~

All exited 0. Reports under bootstrap/out:

| Gate | Report | Groups | Commands | Summed child ms | Input records |
| --- | --- | ---: | ---: | ---: | ---: |
| Component | native-objects/4f86734b35444fa984485dd64992d465/report.json | 82 | 167 | 558526 | 99 |
| Complete code | native-code-instructions/472014f5cb8c401dbd37dcb403875328/report.json | 896 | 1008 | 23716 | 250 |
| Retained leaves | native-instructions/8a8f8fd46a074322a63c6d3df1c957dc/report.json | 128 | 160 | 4110 | 138 |

The component passes 33,573,240 assertions per bootstrap stage. Its 53 independent
encoding vectors include every INT3 descriptor field, exact/insufficient byte
and event budgets, cancellation, Err/input preservation and no allocation/copy.
Thirty-two unsupported encodings include prefixed CC variants and CD 03. Two
added reachable-trap leaf refusals pass alongside the existing leaf controls.
Both raw LLVM outputs are identical: 1,702,769 bytes, SHA-256
A0572584F84CB0A0D68C6DB020AFC08EA80813D7B15BA4E7D6229660C23C9D14.
NativeInstructions.bas: 17,986 bytes, SHA-256
E5A36D30A67DE67A426FA12511D4D7DAADA89E765FE9F68CFA7F4CECEBCCE6D6.

The complete-code gate passes 224 positive comparisons: 72,384 instruction
observations covering the 146,088-byte corpus through both readers. All 672
negative controls reject: unsupported first opcode, changed independent flow,
and changed independent signed displacement, each for every code object and
reader. The retained leaf gate preserves all 2,496 instruction observations and
64 unsupported-opcode rejections. A final SHA-256 audit confirms all 249 distinct
captured input paths unchanged. These child durations are evidence of bounded
test completion, not compiler performance measurements. The enclosing full
bootstrap was not rerun; its deadline and all production resource caps remain
unchanged.

The separate branch diagnostic checks 5,224 unrelocated jumps against independent
instruction starts and COFF function fences with no mismatches. Sixteen relocated
tail jumps target ube.f35 or ube.program.run and remain distinct cross-function
obligations. Artifacts: bootstrap/out/diagnose-native-branches.mjs,
bootstrap/out/native-branch-boundary-diagnostic.json and
bootstrap/out/native-relocated-branch-diagnostic.json. These are diagnostic
inputs to implementation, not production control-flow qualification.

Next implement the production contribution coverage/anchor-consistency and
complete-image ownership checks specified in NATIVE-CODE-OWNERSHIP-IMPLEMENTATION.md,
then whole-function control flow, effective operands/targets and termination
closure. Full unwind/call-site/prologue/stack-reserve, pointer/import/TLS, debug,
tool/build/diagnostic/publication integration and fresh complete-cohort gates
remain required. The original native-executable goal is active and incomplete.

## Indirect target-register preservation - 2026-11-03

The whole-function investigation found 16 register-indirect calls in the retained
code: eight through r13 in ube.stack.initialize and eight through rsi in
ube.module.wait. The previous decoder reported indirect flow but omitted the
selected register. NativeInstruction now carries TargetRegister: 0..15 for
register-indirect calls/jumps, -1 otherwise. This consumes the former alignment
gap; the record remains 72 bytes and RelativeOffset/MemoryDisplacement remain at
56/64. Calls/jumps through memory retain their existing memory descriptor and
TargetRegister=-1. No instruction admission or language behavior changed.

Four new hand-authored vectors cover r13/rsi calls, an r11 jump and a RIP-relative
memory call; the original rax call/jump vectors now assert target identity too.
All 57 positive vectors compare every descriptor field, including TargetRegister,
with the existing truncation, exact-budget, cancellation, immutable-input, Err,
allocation/copy and root-refusal checks. The altered target-register descriptor
control fails through both stages. The complete-code oracle now independently
parses register operands from LLVM and compares the target field at every row;
changed target-register expectations join its existing flow/displacement controls.

~~~powershell
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/objects/check.ps1 -DiagnosticOnly
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/objects/check-instructions.ps1 -ReaderReport bootstrap/out/native-objects/efb15c0840b84e4281880b1a2f05eb2e/report.json -BindingReport bootstrap/out/native-extent-bindings/1ee39e22ed974005bec0d08bcd718b3f/report.json -WholeCode
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/objects/check-instructions.ps1 -ReaderReport bootstrap/out/native-objects/efb15c0840b84e4281880b1a2f05eb2e/report.json -BindingReport bootstrap/out/native-extent-bindings/1ee39e22ed974005bec0d08bcd718b3f/report.json
~~~

All passed. Reports under bootstrap/out:

| Gate | Report | Groups | Commands | Summed child ms | Input records |
| --- | --- | ---: | ---: | ---: | ---: |
| Component | native-objects/efb15c0840b84e4281880b1a2f05eb2e/report.json | 88 | 179 | 659126 | 103 |
| Complete code | native-code-instructions/e5146e0fa3714fdc90c85a56e24a5061/report.json | 1120 | 1232 | 29752 | 254 |
| Retained leaves | native-instructions/e1ca36408f464ebab9a04a849e1ca700/report.json | 128 | 160 | 4420 | 142 |

Both bootstrap stages pass 35,672,957 component assertions and produce identical
raw LLVM: 1,797,343 bytes, SHA-256
BBA6C15EF50650A837EB00D231445C34F6BFFA17EF507C0E393FAE86F0123E41.
NativeInstructions.bas is 18,176 bytes, SHA-256
85E04488FDB5F42B88F61813B6666F7D7605F3099B78E3EE40E37E3606FC7BC3.
The complete-code gate retains all 72,384 instruction observations over the
146,088-byte corpus, including 32 register-call observations through both readers.
All 896 complete-code negative controls and 64 retained-leaf controls reject.
The final audit confirms 253 distinct captured input paths unchanged; identities
are retained in bootstrap/out/native-instruction-target-input-audit.json.
PowerShell syntax and edited-file whitespace/diff checks pass. Production caps
and the existing 720-second enclosing component-test deadline are unchanged.
The full bootstrap and final native build were not rerun or claimed complete.

NATIVE-CONTROL-FLOW-INVESTIGATION.md records the diagnostic that led to the fix:
5,712 relocation fields, 416 function extents, 288 between-function NOPs,
16 tail jumps and explicit remaining pointer-table/TLS/import/API obligations.
The initial commentary inference that eight remaining trap paths were register
calls was corrected by the actual abort disassembly: those paths are the O0
TerminateProcess success branch. The 16 register calls are separate VirtualQuery
and Sleep paths. No production check relies on the discarded inference.

Next pair instruction relocation fields with complete instruction ends and
resolve effective target offsets. Complete whole-function branch/call/tail/trap
validation with qualified pointer-table/import/TLS and API behavior, followed by
full unwind/stack/reserve, debug, tool/build/diagnostic/publication and fresh
complete-source acceptance. The original goal remains active and incomplete.

## Subsequent relocation-field qualification

NATIVE-INSTRUCTION-RELOCATION-EVIDENCE.md records the passing 90-group component,
2,240-group complete-code and 128-group retained-leaf refresh. Every instruction
comparison remains passing; all 5,712 code relocations now also match independent
field/effective-offset oracles. Signed linked-address correspondence, target
ownership and whole-function safety remain required.
