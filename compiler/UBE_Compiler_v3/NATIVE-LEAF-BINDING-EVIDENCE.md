# Retained leaf correspondence evidence — 2026-11-03

Complete object/image leaf extents and reachable instruction-boundary maps now
bind to their retained definitions through both bootstrap stages. The component
gate passes 66 groups; the actual binding matrix passes 192 groups. This completes
the pending leaf correspondence prerequisite, not instruction/relocation equality
or the full First checked native executable deliverable.

NATIVE-LEAF-BINDING-IMPLEMENTATION.md defines the borrowed-input, atomic-output,
work and failure contract. TryBindNativeLeafExtent is in NativeLeaves, already
registered in the production manifest. It checks both fences against their exact
retained anchors, validates successful leaf owners and compares complete extents,
instruction counts and every map byte. Result ranges expand to that common extent.
Different fence sizes/trailing padding are allowed. No resource cap changed.

## Commands and reports

Commands were run from the repository root. DiagnosticOnly pins the accepted
historical bootstrap tools; it does not claim a new whole-source bootstrap run.
Independent object generation, image and disassembly artifacts remain explicit
pinned inputs. Matrices ran concurrently, so times are not isolated benchmarks.

```powershell
$reader='bootstrap/out/native-objects/36d4127b2af843c089fe2c203963870b/report.json'
$binding='bootstrap/out/native-extent-bindings/3a1a0ee9e61e42b9abb4d38652fd6dca/report.json'
$leaf='bootstrap/out/native-leaves/070cc74888414c128165a3ec5054112a/report.json'
$graph='bootstrap/out/native-graph/3ae0e5a87d014b82a61adaae0cc28595/report.json'
$retention='bootstrap/out/native-retention/876d3469520c48f981ea378503704593/report.json'
$frames='bootstrap/out/native-frames/157eecd5aacd410fade78655207ec826/report.json'
$support='bootstrap/out/explicit-link-inputs/318209f12b5b4f0282acf596c47e6386/report.json'
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/objects/check.ps1 -DiagnosticOnly
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/objects/check-leaf-bindings.ps1 -ReaderReport $reader -BindingReport $binding -LeafReport $leaf
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/objects/check-function-index.ps1 -ReaderReport $reader -BindingReport $binding
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/objects/check-leaves.ps1 -ReaderReport $reader -BindingReport $binding
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/objects/check-instructions.ps1 -ReaderReport $reader -BindingReport $binding
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/objects/check-extent-bindings.ps1 -ReaderReport $reader -GraphReport $graph -RetentionReport $retention
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/objects/check-unwind.ps1 -ReaderReport $reader -GraphReport $graph
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/objects/check-image-unwind.ps1 -ReaderReport $reader -RetentionReport $retention
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/objects/check-bindings.ps1 -ReaderReport $reader -FramesReport $frames
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/objects/check-generated.ps1 -ReaderReport $reader -FramesReport $frames
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/objects/check-retention.ps1 -ReaderReport $reader -GraphReport $graph -SupportReport $support
```

Each row is bootstrap/out/<gate>/<id>/report.json; all success fields are true.

| Gate | Report ID | Groups | Commands | Summed command ms |
| --- | --- | ---: | ---: | ---: |
| native-objects | 36d4127b2af843c089fe2c203963870b | 66 | 135 | 351205 |
| native-leaf-bindings | 3d605297eaa045a699c29115b35ea952 | 192 | 192 | 10031 |
| native-function-index | 429b127e8918406db19a064cf17aa944 | 832 | 832 | 22762 |
| native-leaves | 2611f71991aa4a46a72a76a74d1c9fde | 256 | 288 | 8407 |
| native-instructions | 369e5778e5e94d67972a59a298ad58d0 | 128 | 160 | 3987 |
| native-extent-bindings | 1ee39e22ed974005bec0d08bcd718b3f | 416 | 576 | 34723 |
| native-unwind | 627184685c214cd0882f3009cafcab01 | 288 | 576 | 15985 |
| native-image-unwind | db3908d949f945508bab7d551ca2468e | 32 | 48 | 2541 |
| native-data-bindings | 27a1befb80784bd7a889268e7d3e0e1d | 192 | 192 | 7505 |
| native-object-inputs | 420e23d3df7d4fc9815b816285273ef4 | 224 | 336 | 11863 |
| native-retention | b2bf447b4cb24f8ba5d3cd7cf7c76ace | 416 | 576 | 23112 |

All 687 distinct input paths across the eleven reports passed a final SHA-256
recheck. The existing 600-second component deadline is unchanged. The nine-script
PowerShell parser check, including the new binding oracle, also passes.

## Focused and actual assertions

Both stages pass 25,178,741 component assertions each. The focused binder fixture
has a six-byte extent with unreachable interior bytes and different object/image
fence capacities. Success reads exactly 12 map bytes in 13 inspection events,
allocates/copies nothing, preserves Err and the borrowed byte buffer, and retains
the expected symbol, section, file/section offsets and image address fields.
Exact/one-below byte and event budgets, all thirteen cancellation admissions and
full root-pressure refusal preserve the old result on failure.

Twenty changed anchor fields, nine owner/fence/status disagreements, and four
malformed equal-map/count cases reject with the specified controlled codes.
A separate pair of valid leaves has equal six-byte extents and two instructions
each, but different maps; binding rejects it. Corrupted object and image result
lengths are rejected by the named oracle through both compiler stages.

The actual matrix composes retained-name binding, prepared object/image symbol
inventories and address indexes, qualified fences, both complete leaf walks and
the new binder. It compares extents and both maps with the independently derived
object disassembly oracle, requiring every selected function exactly once.
There are 64 object/image comparisons over 32 retained objects, with 112 bound
leaf observations, including the looping and multiple-return Err routines.

The independent PE symbol lookup locates the first selected image function for
each control. Replacing its first byte with RET leaves a decodable shorter leaf;
replacing its complete first instruction with NOPs leaves a decodable changed
instruction map. Independent disassembly confirms those first instructions are
fallthrough and 5, 6 or 10 bytes long. All 128 controls reject specifically at
leaf binding with 1506, not at decoding, name lookup or a generic process failure.
Candidate images are read as bytes, never executed by this gate.

## Identities and remaining scope

NativeLeaves.bas, including the binder: 12,199 bytes, SHA-256
00418B743B5338AAE67D711D5388787E5D0185660EA8B01B1299EDAC7E3277B2.
Both stages emit identical 1,536,385-byte raw LLVM files, SHA-256
BAC84D3F937444A13A7F46DC4796763958973E05C4C594315905F0EBCE4D14C1.
Bootstrap cohort df15817344774026bebebfd1e9ae8eaf; compiler SHA-256
846A9CD21EEF516E4D47CA1DECAE37B1BAF219530F930DC1107B0DABAB1917A7.
Reports retain complete source/tool/artifact identities. Both new gates passed
their first runs; no production correction or crash fix was required.

Next resolve object relocation targets against retained image definitions and
qualify instruction bytes/fixups. Equal extents and maps do not establish equal
opcodes, branch destinations, memory operands or values. Full unwind/stack/reserve,
startup/API/refusal and debug qualification, production build ownership, current
toolchain/bootstrap wiring, publication and final source-cohort acceptance remain
open. The full native-executable goal remains active and incomplete.
