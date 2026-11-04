# Native instruction relocation evidence

## Contract and implemented scope

The existing First checked native executable work now includes the scalar
TryReadNativeInstructionRelocationOffset operation in NativeRelocations.bas.
Its ownership, failure, work and qualification contract is recorded in
NATIVE-INSTRUCTION-IMPLEMENTATION.md. It pairs a qualified COFF relocation with
an exact decoded displacement/immediate field and returns a signed target-relative
addend. REL32 correction uses the complete instruction end, including any trailing
immediate; SECREL remains a section-relative member addend.

This does not establish linked signed-address correspondence, target extent,
function entry, pointer/import/TLS provenance, whole-function control flow or
final executable acceptance. The original goal remains active and incomplete.

## Independent tests

instruction-relocations.c supplies 13 literal byte/addend vectors and 63
kind combinations, including all six relative relocation kinds, direct and
conditional transfers, RIP-relative imports/constants, trailing byte/dword
immediates, TLS members and signed 32-bit endpoints. Exact one-event/zero-byte
admission, exhausted budgets, cancellation, immutable descriptors and bytes,
Err persistence, allocator independence, root refusal and 17 additional malformed
shape/operand cases are asserted. A corrupted returned-offset bridge must fail.

The complete-code gate independently reads COFF relocation entries and signed
original fields, associates them with LLVM instruction boundaries, and compares
the production offset for every code relocation. Altered sites, kinds, original
addends and expected offsets must reject through both readers. Existing complete
instruction and leaf checks remain in the gate.

## Qualification - 2026-11-03

Commands from the repository root:

~~~powershell
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/objects/check.ps1 -DiagnosticOnly
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/objects/check-instructions.ps1 -ReaderReport bootstrap/out/native-objects/cc7e1c28420e4154827555baf1850308/report.json -BindingReport bootstrap/out/native-extent-bindings/1ee39e22ed974005bec0d08bcd718b3f/report.json -WholeCode
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/objects/check-instructions.ps1 -ReaderReport bootstrap/out/native-objects/cc7e1c28420e4154827555baf1850308/report.json -BindingReport bootstrap/out/native-extent-bindings/1ee39e22ed974005bec0d08bcd718b3f/report.json
~~~

All passed. Report paths below are relative to bootstrap/out:

| Gate | Report | Groups | Commands | Summed child ms | Input records |
| --- | --- | ---: | ---: | ---: | ---: |
| Component | native-objects/cc7e1c28420e4154827555baf1850308/report.json | 90 | 183 | 637336 | 104 |
| Complete code | native-code-instructions/92bf72bfae034e46a65364d042255a3e/report.json | 2240 | 2352 | 57840 | 255 |
| Retained leaves | native-instructions/a5f0e52304704dabab2a23b13a025238/report.json | 128 | 160 | 4320 | 143 |

Both bootstrap stages pass 37,771,052 component assertions and produce identical
raw LLVM: 1,818,844 bytes, SHA-256
DCFE70B3D05CA1A124236C64EF9F3BCC644F8CF8E6A704B30B8ED8875CAC2E1C.
NativeRelocations.bas is 12,839 bytes, SHA-256
666B78D764C7CC0F2F28DE82CFA22D02E84866DD03CE16D7B0ECDEA829AAF9F5.

The complete-code gate covers 112 nonempty objects, 32 empty objects, all 36,192
instructions and 146,088 unique bytes. Every one of the 5,712 relocations pairs
successfully through both readers (11,424 field observations): 4,824 REL32 and
888 SECREL. The 896 new relocation mutation controls and 896 retained instruction
controls all reject. The leaf gate retains its 2,496 instruction observations
and 64 rejections. These counts establish the stated corpus and scalar contract,
not target safety or final native executable acceptance.

The separate six-case signed-target diagnostic passes through both stages;
NATIVE-CONTROL-FLOW-INVESTIGATION.md records its command, report, initial fixture
compile failure and corrected passing result. Three explicit counterexamples
show that modulo field equality plus original effective offsets can still
address a different signed linked target. Those are required next regression cases.

A final SHA-256 audit across these three gates and the signed-target diagnostic
confirms all 262 distinct captured input paths unchanged. Identities are in
bootstrap/out/native-instruction-relocation-input-audit.json. PowerShell parsing,
edited-file whitespace and git diff checks pass. These child durations establish
test completion only, not compiler performance. The existing 720-second enclosing
component-test deadline and all production caps remain unchanged. The full
bootstrap and final native build were not rerun or claimed complete.

Next qualify signed linked-address correspondence and target extents/ownership,
then whole-function branch/call/tail/trap closure with pointer-table/import/TLS
meaning. Full unwind/stack/derived reserve, debug, native tool/build/diagnostic/
publication ownership and fresh complete-source acceptance remain required.

## Subsequent signed-target qualification

NATIVE-INSTRUCTION-TARGET-EVIDENCE.md records the passing signed linked-target
consumer and refreshed 92-component/2,240-instruction/128-leaf/1,856-target gates.
The three diagnosed modulo-address counterexamples now reject. Target ownership,
complete extents and whole-function safety remain required.
