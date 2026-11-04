# Code contribution ownership evidence

The production anchor, section-coverage and complete-image ownership consumers
now pass the maintained two-stage component and retained-artifact gates. This
qualifies those consumers on the tested immutable inputs; the native build
owner and complete executable acceptance remain unfinished.

## Implementation

NativeCode now supplies ValidNativeCodeContribution,
TryValidateNativeCodeAnchor and TryValidateNativeCodeCoverage. They validate
scalar range shapes, all anchor placement coordinates/characteristics, and
exact coverage of every nonempty executable object section. Coverage consumes
a section-indexed borrowed map and rejects missing or spurious entries.

NativeCodeIndexes supplies NativeOwnedCode, NativeCodeIndex,
TryPrepareNativeCodeIndex and TryDisposeNativeCodeIndex. Preparation rejects
duplicate (UnitKind, SourceId, object section) owners and overlapping positive
image file or RVA intervals. Adjacent intervals are admitted. All records must
have one consistent image base. The caller still owns their association with
the same immutable image and frozen expected definitions.

Three sorts reuse the existing budgeted UBECore byte-key implementation. The
existing inventory budget adapters are shared without changing their mapping.
For C contributions, index workspace peaks at 25C bytes, ready storage is 4C,
and Core copies 12C bytes of index positions across the three orders. Borrowed
contribution records are unchanged and are not copied into retained payload.
The per-output map and borrowed input records remain charged to their caller;
these index figures do not include those owners or whole-build storage.

## Commands and reports

Run from the repository root:

~~~powershell
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/objects/check.ps1 -DiagnosticOnly
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/objects/check-code.ps1 -ReaderReport bootstrap/out/native-objects/4e22acebba4d44dcae5b06b3a297ec1c/report.json -BindingReport bootstrap/out/native-extent-bindings/1ee39e22ed974005bec0d08bcd718b3f/report.json
rtk proxy powershell -NoProfile -File bootstrap/out/check-ownership-script-syntax.ps1
rtk proxy git diff --check
~~~

All passed. Reports under bootstrap/out:

| Gate | Report | Groups | Commands | Summed child ms | Input records |
| --- | --- | ---: | ---: | ---: | ---: |
| Component | native-objects/4e22acebba4d44dcae5b06b3a297ec1c/report.json | 86 | 175 | 619376 | 103 |
| Retained code and ownership | native-code/c10b0f11185f4f0a8cd2d3670346edff/report.json | 2208 | 2210 | 105861 | 546 |

The component passes 35,672,878 assertions per bootstrap stage. Both raw LLVM
outputs are byte-identical: 1,796,310 bytes, SHA-256
8E3987DC23745CAA427F4AA1A28E526966E49AD3DB159C3F6A707C2933EB1940.

| Production source | Bytes | SHA-256 |
| --- | ---: | --- |
| src/NativeCode.bas | 15918 | 58655A7FE787FBAFB30D65FCE06FB92DEFB27FD54617EDE3557023A927C2E2D8 |
| src/NativeCodeIndexes.bas | 11767 | 0596662EC68D6679D453D4469F5C23965D04BF36E964EBAAC0F53CDAF703C368 |
| src/NativeInventories.bas | 16559 | A1CC1441FEDEB33F59D431CDE1C51322EFD85E8CCA956F4B214E3BB89318077E |

The final independent SHA-256 audit confirms all 417 distinct captured input
paths unchanged; bootstrap/out/native-code-ownership-input-audit.json retains
the identities. Tracked diff checking and explicit edited-file whitespace checks
pass. The PowerShell parser checks cover the two maintained gate scripts and
the bootstrap wrapper.

## Independent coverage

Synthetic indexes cover 0, 1, 6 and 257 contributions, arbitrary order, high
unsigned RVAs, signed file/address endpoints, exact adjacency, support/source
identities, duplicate owner keys, file and RVA overlap, malformed range and
owner shapes, invalid source counts and inconsistent image bases. Every measured
allocation refusal and cancellation admission is exercised on the mixed-order
fixture, with exact/one-below byte, event, inspection-storage and global-payload
budgets. Partial states remain accounted and dispose completely. Full root
pressure, prior ready-state retention, immutable inputs and Err preservation
pass. Altered published index status and count fail their intended assertions
through both stages.

Per-output tests cover first/last-byte anchors, changed coordinates and flags,
missing/spurious/wrong-section coverage, map length, non-executable sections,
exact budgets and every measured cancellation admission. These scalar helpers
allocate and copy no payload. Earlier instruction, leaf, binding, relocation,
constant and complete-byte component cases remain in the same passing probe.

The retained matrix contains 144 units in 16 images. Each image has nine units,
seven nonempty code contributions and source identities 0, 1 and 2. Both readers
pass 288 unit comparisons, observing 224 contributions and 292,176 content bytes
(the unique corpus is 112 contributions / 146,088 bytes). Frozen expected rows
supply owner identities. Production helpers now enforce anchor consistency and
section coverage before an independent section/range oracle is compared.

Thirty-two complete-image ownership comparisons match independent RVA order;
each seven-contribution index peaks at 175 bytes. They admit 7,296 events in
aggregate. All 1,888 negative controls reject: the preceding 1,120 content/fixup/
addend/anchor/field-overlap mutations, 672 new anchor/map refusals and 96 new
duplicate-owner/file-overlap/RVA-overlap refusals. Positive unit ledgers total
9,373,840 inspected bytes and 3,463,120 events, including the test driver's
section reads for its independent range comparisons. These totals are not a
whole-build resource or performance claim.

## Retained correction and limits

The first component attempt compiled UBE successfully but strict C compilation
rejected three missing record-pointer casts and one signed/unsigned comparison
in the new test fixture. Its report is
native-objects/6677fe1232f848009d6499b0b1b611a6/report.json. Correcting the C fixture
required no production change. The focused unchanged-LLVM ownership run passed
at code-ownership-diagnostic/a085d44b2b3c4f67aa7d98bf60a13f07/report.json. A focused
actual-object driver run passed at
owned-code-files-diagnostic/3bb41e45d773404f98d880d148f94a45/report.json. The complete
maintained rerun above supersedes those diagnostics.

The component's measured child commands require 619.376 seconds, exceeding the
previous 600-second enclosing full-bootstrap deadline. bootstrap/build-v2.ps1
now allows 720 seconds for this test only. Production resource caps and existing
declaration/body/argument bounds are unchanged. The full bootstrap was not
rerun here; current complete-cohort qualification remains required.

Next establish whole-function control flow and effective operand/target safety,
including the 16 observed relocated tail jumps and termination closure around
INT3 traps. Pointer-cell/import/TLS meaning, full unwind/call-site/prologue and
recovery-reserve derivation, startup/API/refusal closure, debug validation,
native build/tool/diagnostic/publication integration and fresh complete source
acceptance remain required. The original goal is active and incomplete.
