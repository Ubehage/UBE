# Signed native instruction target evidence

TryReadNativeInstructionRelocationTarget composes the qualified original field
pairing with a resolved target, image instruction position and actual linked
field. It rejects signed displacement overflow, derived RVA/VA overflow,
negative or unrepresentable section offsets and mismatching linked bytes.
The complete contract is in NATIVE-INSTRUCTION-IMPLEMENTATION.md.

The 23 literal vectors cover all six relative relocation kinds, RIP addressing,
trailing immediates, positive and negative addends, signed 32-bit boundaries,
unsigned RVA and signed VA limits, and section-relative TLS members. The three
previously diagnosed wrapped fields still pass their modulo encoding comparison
and now reject as signed instruction targets. Successful paths assert exactly
four bytes/two inspection events, no payload allocation/copying, unchanged Err,
input immutability and output preservation; linked-byte mutations, both budget
boundaries and cancellation points, invalid caller state and root refusal are
included. A corrupted returned-target bridge must fail the independent result.

The retained image gate adds independently decoded instruction placement to its
existing independent COFF/PE target and site oracle. It compares effective target
positions from production symbol/constant binding and the new consumer, with
image-first, image-RVA, instruction-offset and result mutations. Existing scalar
fixup mutation controls remain in the same gate.

## Qualification - 2026-11-04

Commands from the repository root:

~~~powershell
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/objects/check.ps1 -DiagnosticOnly
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/objects/check-instructions.ps1 -ReaderReport bootstrap/out/native-objects/1b9f341a7ab04072a058f4a0d59414d4/report.json -BindingReport bootstrap/out/native-extent-bindings/1ee39e22ed974005bec0d08bcd718b3f/report.json -WholeCode
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/objects/check-instructions.ps1 -ReaderReport bootstrap/out/native-objects/1b9f341a7ab04072a058f4a0d59414d4/report.json -BindingReport bootstrap/out/native-extent-bindings/1ee39e22ed974005bec0d08bcd718b3f/report.json
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/objects/check-fixups.ps1 -ReaderReport bootstrap/out/native-objects/1b9f341a7ab04072a058f4a0d59414d4/report.json -BindingReport bootstrap/out/native-extent-bindings/1ee39e22ed974005bec0d08bcd718b3f/report.json -InstructionReport bootstrap/out/native-code-instructions/17a5c536fc7e40c099c05fac7a6ab716/report.json
~~~

All passed. Report paths below are relative to bootstrap/out:

| Gate | Report | Groups | Commands | Summed child ms | Input records |
| --- | --- | ---: | ---: | ---: | ---: |
| Component | native-objects/1b9f341a7ab04072a058f4a0d59414d4/report.json | 92 | 187 | 619167 | 105 |
| Complete instructions | native-code-instructions/17a5c536fc7e40c099c05fac7a6ab716/report.json | 2240 | 2352 | 51585 | 256 |
| Retained leaves | native-instructions/5dab04bb5b204b0cba6e21aee7668305/report.json | 128 | 160 | 4103 | 144 |
| Signed targets and fixups | native-fixups/6396d3a853e04b70a900bad12a101664/report.json | 1856 | 1858 | 83825 | 773 |

Both bootstrap stages pass 39,868,628 component assertions. Raw LLVM is identical:
1,832,887 bytes, SHA-256
4DE4236FFCAC2CB388A09007B3543B58FB476489D7F2DABFEC07291B9ED4D4EF.
NativeRelocations.bas is 16,079 bytes, SHA-256
068449F62A804C01E5B5317FED63C4A93B1967059033C88AC21B68B6F1A326D9.
NativeInstructions.bas is 18,168 bytes, SHA-256
2F5B8A6D6210B43D9F3B1A399DF250B2302A95518FDB7D256CD498A8A169AB92.

The complete instruction gate retains all 36,192 instructions and 5,712 relocation
fields, including all 1,792 negative controls. The leaf gate retains 2,496
instruction observations and 64 rejections. The signed-target matrix performs
288 object/image comparisons across the 144-object cohort (112 nonempty), with
11,424 field/target observations through both readers over 16 images. All 896
new target/placement controls and 672 retained encoding controls reject.
The test-owned image placement and independent target descriptors are explicit
oracle inputs; this gate does not claim production build-owner integration.

NATIVE-TARGET-OWNERSHIP-INVESTIGATION.md records the separate passing 5,712-reference
census over those images: frozen generated extents, reference-cell contents,
PE import/IAT association and TLS-index metadata. It is diagnostic input to the
next production checks, not completed operand/dataflow qualification.

The final SHA-256 audit confirms all 538 distinct input paths across these four
gates and the ownership diagnostic unchanged. See
bootstrap/out/native-signed-target-input-audit.json. PowerShell syntax, edited-file
whitespace and git diff checks pass. Child durations establish bounded test
completion, not compiler performance. Production caps and the existing 720-second
component-test deadline remain unchanged. The full bootstrap and final native
build were not rerun or claimed complete.

## Remaining scope

This establishes signed field-to-target correspondence only when the caller's
qualified instruction, target and placement associations hold. It does not
establish complete target storage, access permissions, function-entry ownership,
TLS base provenance, pointer/import propagation or whole-function safety.
NATIVE-TARGET-OWNERSHIP-INVESTIGATION.md records the concrete next obligations.
The full native-executable goal remains active and incomplete.
