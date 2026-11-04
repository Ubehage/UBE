# Native relocation value evidence

The scalar relocation encoding consumer is qualified through focused two-stage
tests and retained generated object/image pairs. Production contribution/site
placement and complete instruction correspondence remain unfinished. This does
not complete the First checked native executable goal.

## Commands and results

Run from the repository root:

~~~powershell
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/objects/check.ps1 -DiagnosticOnly
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/objects/check-fixups.ps1 -ReaderReport bootstrap/out/native-objects/fa6477ba667442f3839e1dc11727fdd8/report.json -BindingReport bootstrap/out/native-extent-bindings/1ee39e22ed974005bec0d08bcd718b3f/report.json
~~~

Both qualification commands passed on their first execution. Before these,
invoking check.ps1 without DiagnosticOnly refused at bootstrap-source admission:
bootstrap/build-v2.ps1 differs from the historical full-bootstrap source record.
No component result came from that refused invocation. DiagnosticOnly uses the
existing pinned bootstrap artifacts and checks their identities; it does not
establish a fresh complete bootstrap of the current checkout.

| Gate | Report under bootstrap/out | Groups | Commands | Summed child milliseconds |
| --- | --- | ---: | ---: | ---: |
| Component readers | native-objects/fa6477ba667442f3839e1dc11727fdd8/report.json | 78 | 159 | 526156 |
| Relocation values | native-fixups/b64b5212edb5486c99965b549ca20470/report.json | 960 | 962 | 46910 |

The component suite passed 31,473,972 assertions per stage, retaining all earlier
reader, inventory, binding, unwind, instruction, leaf, function-index and target
tests. Twenty-seven literal vectors cover every nonzero admitted kind, 2/4/8-byte
fields, carries, modular wrap, high-bit addends, both displacement directions,
large RVAs, the signed VA boundary, section ordinals and a zero-filled target.
Each linked field byte is separately corrupted and rejected. Exact/one-below
byte and event budgets, cancellation at every admission, no allocation/copy,
ordinary successful Err preservation, immutable inputs, 25 invalid descriptor/
span/target cases and real root exhaustion pass. ABSOLUTE separately proves its
zero-byte admission, unused-input behavior, budget/cancellation and shape refusal.
Forcing either Boolean result is detected through both stages (four controls).

The retained matrix covers all 144 object/image associations from the prior
extent-binding report, including 32 objects with no code relocations. Both
readers make 288 positive unit comparisons (64 empty) and 11,424 field
observations: 5,712 REL32/SECREL fields per reader. Production named-target
resolution and complete anonymous constant binding supply the actual target
ranges. A test-owned cache resolves each distinct raw target once per object;
this does not introduce a production cache or certify whole-build accounting.

The independent SDK-offset oracle checks the target descriptors and derives
code section placement from corresponding named function anchors. Every anchor
must agree on one base, inside one initialized executable image section. No
linked relocation operand participates in this placement. Anonymous target
locations come from independently matching the complete known 31-byte constant.
The test transport contains section/relocation indices, field file offset,
site RVA and expected target range; it is not a production interface.

For each of the 112 objects with fields, separately changing a linked byte,
an object addend or a relative site RVA must fail specifically in relocation
value comparison with 1506. Both readers reject all 672 controls. Candidate
images and mutated images are read as data and are never executed by this gate.

## Identities and limits

NativeRelocations.bas is 8,039 bytes, SHA-256
407E98F6316263B348ED43CDAEBEC32878FC30930FF8FE34E2809BAFF9E6FADA.
Both raw component LLVM files are 1,626,623 bytes, SHA-256
1A22A7D0FC21B77ABCC8173C5B85D4445C6F24A987C50952E31BC26E669AD91C.
The unchanged bootstrap selection is df15817344774026bebebfd1e9ae8eaf.

Reports capture 95 component input records and 394 retained-matrix input records,
including tools, sources, adapters and retained candidates. A final SHA-256 audit
of their 265 distinct captured paths found no changes. git diff --check passed
with existing LF-to-CRLF notices. The new gate also passed PowerShell parser
checking before execution. No running test handles remain.

The scalar consumer allocates/copies no payload. A successful width-W field
uses exactly 2W bytes and 2W+1 shared inspection events. Existing numeric caps,
declaration/body/argument bounds and the 600-second enclosing component deadline
remain unchanged. The contract is NATIVE-FIXUP-IMPLEMENTATION.md; raw values are
encoding comparisons, not proof of safe effective addresses after truncation.

Next qualify production code/contribution placement against frozen retained
definitions, distinct-contribution ownership/alias policy, relocation overlap
and complete changed/unchanged-byte coverage, then instruction operands and
effective targets. Pointer-cell/import/TLS meaning, full unwind/call-site/
prologue/stack reserve and startup/API/refusal closure, debug validation,
tool/build ownership, diagnostic delivery, publication and fresh complete
source-cohort acceptance remain required. Earlier all-byte diagnostic results
remain guidance and are not promoted to production acceptance by this gate.

## Subsequent signed instruction targets

NATIVE-INSTRUCTION-TARGET-EVIDENCE.md records the expanded check-fixups.ps1 gate
with its optional independent instruction report. Both readers match 5,712 signed
targets and all 1,568 target/encoding controls reject. Scalar modulo encoding
comparison remains unchanged; the additional consumer proves signed correspondence
under explicit instruction/target/placement preconditions. Ownership and full
access/control-flow safety remain required.
