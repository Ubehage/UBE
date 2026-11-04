# Declared native function-range evidence - 2026-11-03

The subsequent retained extent-binding checkpoint and current reader identity are
recorded in [NATIVE-EXTENT-BINDING-EVIDENCE.md](NATIVE-EXTENT-BINDING-EVIDENCE.md).
The reader-only checkpoints below remain historical evidence.

## Current linked-image checkpoint

The reader now also obtains PE32+ runtime-function records from exception
data-directory entry 3. It resolves each span against the admitted at-most-96
sections and rejects ambiguous/intersecting, out-of-range or uninitialized spans.
The function table and range APIs publish fixed scalar descriptors atomically;
no payload allocation or copying is introduced. NATIVE-UNWIND-IMPLEMENTATION.md
records the image-side ownership, traversal and failure contract.

The fresh two-stage component gate passes 46 groups and 12,590,008 assertions
per stage in 194,281 ms summed command time. Its report is
native-objects/357b5e44bfb64347a039aa40dcc16473/report.json. Both raw LLVM outputs
are identical: 1,290,713 bytes, SHA256
8FDAFDE1A4BC8515780044688F5D8963430D1E7CADC72274E703E1A999F74233.
NativeUnwind.bas is 13,017 bytes, SHA256
BA4DC45BFC78E278C840A8FA648AA9EC740EB0D94527A676BA186DFF04CD4DEB.
Other production sources retain their identities in the earlier table below.

The independent synthetic PE has three sections and two known records. Table
preparation costs exactly 136 bytes/35 events; first and second range reads cost
252/65 and 260/67. Physical-read and event hooks independently match these values.
Exact/one-below budgets, every event cancellation, full root-registry refusal,
invalid indices/owner length, absent directories and 25 malformed directory/range/
permission/order/overlap cases pass, preserving prior outputs on failure. Err and
input bytes remain unchanged and allocation/copy counters remain zero. Corrupted
table counts and returned code lengths fail their intended independent assertions.
No implementation or oracle correction was needed for the image extension.

Actual image comparisons consume 16 retained explicitly linked images from both
generating stages, root/reference layouts, O0/O2 and Full/None. Test-only LLVM
unwind records supply independent absolute start/end/unwind addresses. Both reader
stages agree on all 32 comparisons, comprising 2,352 range observations (71 or 76
records per image). These include linked support functions as well as UBE output;
they do not imply that support functions satisfy the UBE stack contract.

```powershell
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/objects/check.ps1 -DiagnosticOnly
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/objects/check-image-unwind.ps1 -ReaderReport bootstrap/out/native-objects/357b5e44bfb64347a039aa40dcc16473/report.json -RetentionReport bootstrap/out/native-retention/0f8a20b82afc4e3d833834aa513f2d00/report.json
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/objects/check-unwind.ps1 -ReaderReport bootstrap/out/native-objects/357b5e44bfb64347a039aa40dcc16473/report.json -GraphReport bootstrap/out/native-graph/3ae0e5a87d014b82a61adaae0cc28595/report.json
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/objects/check-bindings.ps1 -ReaderReport bootstrap/out/native-objects/357b5e44bfb64347a039aa40dcc16473/report.json -FramesReport bootstrap/out/native-frames/157eecd5aacd410fade78655207ec826/report.json
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/objects/check-generated.ps1 -ReaderReport bootstrap/out/native-objects/357b5e44bfb64347a039aa40dcc16473/report.json -FramesReport bootstrap/out/native-frames/157eecd5aacd410fade78655207ec826/report.json
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/objects/check-retention.ps1 -ReaderReport bootstrap/out/native-objects/357b5e44bfb64347a039aa40dcc16473/report.json -GraphReport bootstrap/out/native-graph/3ae0e5a87d014b82a61adaae0cc28595/report.json -SupportReport bootstrap/out/explicit-link-inputs/318209f12b5b4f0282acf596c47e6386/report.json
rtk proxy powershell -NoProfile -File bootstrap/out/check-unwind-script-syntax.ps1
rtk proxy git diff --check
```

| Current gate | Report under bootstrap/out | Groups | Commands | Summed command ms | Matched input hashes |
| --- | --- | ---: | ---: | ---: | ---: |
| Component | native-objects/357b5e44bfb64347a039aa40dcc16473/report.json | 46 | 95 | 194281 | 71 |
| Image ranges | native-image-unwind/7b1036ebed23488b81cc3b961eec79bd/report.json | 32 | 48 | 2171 | 94 |
| Object ranges | native-unwind/b9e24a6dbaab42969f5baee15869ce07/report.json | 288 | 576 | 14305 | 222 |
| Integer data | native-data-bindings/427a826b92f2492cb68d3696c810c373/report.json | 192 | 192 | 7098 | 141 |
| Generated readers | native-object-inputs/fb3b5d6ffe09474bbf7127381324c49c/report.json | 224 | 336 | 11105 | 190 |
| Linked retention | native-retention/e46ecc7337af46ff90e59aa4e18537e7/report.json | 416 | 576 | 24092 | 249 |

All four PowerShell parser checks pass. Tracked-file diff checking and explicit
trailing-whitespace checks of the touched untracked source/test/evidence files pass.
The object-range gate is registered in the bootstrap; the image-range gate remains
an explicit maintained command, alongside the retention gate whose current
explicit-toolchain evidence still needs integration into the whole bootstrap.
No historical report path is hardcoded into production or the bootstrap sequence.

Next bind object and image ranges to the same frozen retained definitions, establish
leaf extents, and compare instructions/fixups. Reading a declared range is not
proof of that range's instructions or unwind operations. Complete stack/reserve,
producer/debug validation, held-file identity, native builder/publication and final
whole-source acceptance remain open. The First checked native executable goal
remains active and incomplete.

## Earlier object-only checkpoint

The following records the preceding object-only source identity and evidence.
The current linked-image checkpoint above supersedes its reader hashes and next
action while retaining its independent object-range cases.


NativeUnwind now reads the selected AMD64 COFF runtime-function records into
bounded code extents and unwind-header locations. Its ownership and failure
contract is NATIVE-UNWIND-IMPLEMENTATION.md. Shared code/read-only-data permission
predicates are reused by the earlier binding consumer without changing its scope.

## Commands and results

All commands below were run from the repository root. Reports are under
bootstrap/out; DiagnosticOnly uses the pinned existing bootstrap tools and does
not qualify a rebuilt whole compiler.

```powershell
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/objects/check.ps1 -DiagnosticOnly
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/objects/check-unwind.ps1 -ReaderReport bootstrap/out/native-objects/3c9eb59c864a473baae1d4793084646e/report.json -GraphReport bootstrap/out/native-graph/3ae0e5a87d014b82a61adaae0cc28595/report.json
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/objects/check-bindings.ps1 -ReaderReport bootstrap/out/native-objects/3c9eb59c864a473baae1d4793084646e/report.json -FramesReport bootstrap/out/native-frames/157eecd5aacd410fade78655207ec826/report.json
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/objects/check-generated.ps1 -ReaderReport bootstrap/out/native-objects/3c9eb59c864a473baae1d4793084646e/report.json -FramesReport bootstrap/out/native-frames/157eecd5aacd410fade78655207ec826/report.json
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/objects/check-retention.ps1 -ReaderReport bootstrap/out/native-objects/3c9eb59c864a473baae1d4793084646e/report.json -GraphReport bootstrap/out/native-graph/3ae0e5a87d014b82a61adaae0cc28595/report.json -SupportReport bootstrap/out/explicit-link-inputs/318209f12b5b4f0282acf596c47e6386/report.json
rtk proxy powershell -NoProfile -File bootstrap/out/check-unwind-script-syntax.ps1
```

| Gate | Report | Groups | Commands | Summed command ms |
| --- | --- | ---: | ---: | ---: |
| Component | native-objects/3c9eb59c864a473baae1d4793084646e/report.json | 42 | 87 | 171250 |
| Generated object ranges | native-unwind/ed76a4870fc34c65bee3966ebfed268a/report.json | 288 | 576 | 13250 |
| Retained integer data | native-data-bindings/1675a66c22ef4803a4d4cf645af78187/report.json | 192 | 192 | 6835 |
| Retained generated readers | native-object-inputs/0737acece48b45a39a338a80a0ff3cd9/report.json | 224 | 336 | 10834 |
| Retained linked definitions | native-retention/0f8a20b82afc4e3d833834aa513f2d00/report.json | 416 | 576 | 23254 |

The component passes 10,492,527 assertions per bootstrap stage. Both raw outputs
are identical: 1,245,194 bytes, SHA256
B074A716567CA04C19AEACDCEA671FF119C04F5CC7878AF5550CCEEEE1E4B3B7.
All captured hashes were checked at this checkpoint: 71 component, 222 object-range,
141 integer-data, 190 generated-reader and 249 linked-retention inputs matched.

| Production source | Bytes | SHA256 |
| --- | ---: | --- |
| NativeUnwind.bas | 5283 | 57A52939CBFB9ADED8B75F0B702D14EFF634DDAAC069C3740D3B939BEFDA2808 |
| NativeObjects.bas | 15032 | F0AB3311986AFA7EEFDC15284088723E196417DAB274F74EAC34EA367012182E |
| NativeBindings.bas | 11557 | 2CCF04FC885E70C5308A1DB8CE0783A64F1063E7D0317219D7DB45BDA7B2EF91 |

## Independent coverage

The two synthetic records independently specify code offsets 8/32 and lengths 16,
and unwind offsets 0/4 in separate initialized sections. Each successful read costs
exactly 162 inspected bytes and 46 events, observed independently at physical-read
and event hooks. Exact and one-below budgets, every cancellation admission, invalid
indices, 26 malformed record/relocation/permission/extent variants and full root
pressure preserve prior results on failure. Err and input bytes remain unchanged;
no payload is allocated or copied. Mutating either returned length or unwind offset
is rejected by its intended assertion through both stages.

The real-object gate checks 144 retained generated objects across both generating
stages, root/reference layouts, nine output units, O0/O2 and Full/None. Test-only
LLVM symbol and unwind records independently resolve section/offset tuples. Both
production reader stages match all 288 object comparisons, containing 720 declared
range observations. Empty tables contribute no invented function range. Optimized
leaf functions without runtime-function records remain a separate instruction-analysis
obligation. The graph's controlled frame/reserve values do not become proven stack
bounds through these comparisons.

The first component attempt, native-objects/f48e3f9047864476b66268eeaad892a2,
failed an incorrect test expectation of 174 bytes. The focused diagnostic
bootstrap/out/check-unwind-diagnostic.ps1, run against its retained production LLVM,
showed the correct 162 physical/charged bytes and 46 events; the test had counted
COFF relocation records as 14 bytes instead of 10. Correcting that oracle required
no production change. The initial and corrected diagnostic results are retained
in bootstrap/out/unwind-initial-cost-diagnostic.json and unwind-diagnostic.json.

## Remaining acceptance work

The bootstrap sequence now registers native-unwind after native-objects and passes
its current reader/graph reports explicitly. The reader deadline increases from
180 to 300 seconds because the measured component alone consumes 171.250 seconds
of child-command time, leaving too little room for script overhead and normal
variation. This changes a test deadline, not a production resource cap. The three
PowerShell parser checks pass; the complete bootstrap has not been rerun here.

Image-side exception ranges, object/image range binding, leaf extents, full unwind
operations, instruction/fixup equality, reserve derivation, producer/debug checks,
held-file identity and builder/publication remain required. This evidence establishes
declared object extents only and does not complete First checked native executable.
