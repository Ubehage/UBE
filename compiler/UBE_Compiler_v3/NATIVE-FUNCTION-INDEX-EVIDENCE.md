# Native function address index evidence — 2026-11-03

The once-prepared address index and retained-anchor fence reader now pass through
both bootstrap stages and against all 144 retained objects and 16 linked images.
This supplies conservative fences for the pending complete leaf binding work;
it does not establish leaf extents or complete native-executable acceptance.
NATIVE-FUNCTION-INDEX-IMPLEMENTATION.md records the ownership and resource contract.

## Diagnostic and implementation

The independent COFF/PE symbol-table scan retained in
bootstrap/out/native-function-order-diagnostic.json found unordered function
symbols in all sixteen images, with an address alias in every image. The largest
selected image contains 64 function definitions. Production therefore orders
section/address keys once using existing UBECore ByteKeys and queries the next
strictly greater address. Aliases share a fence; labels without function type do
not split it. The initialized section end bounds the last function.

Preparation releases key/address scratch after converting sorted entries to raw
symbol indexes. It retains 4F payload and admits peak 20P + 8F through both
inspection storage and global native payload budgets. Fence lookup validates the
retained symbol, section, initialized file offset, flags and image addresses,
then publishes an expanded range. It allocates/copies no payload and uses binary
search. Next-symbol position is only a fence, never a claimed function extent.
NativeFunctionIndexes is registered in the production manifest and component gate.

## Commands

These commands were run from the repository root. Historical generation/link
artifacts are pinned inputs; DiagnosticOnly does not claim a new whole-source
bootstrap acceptance. Independent matrices were run concurrently.

```powershell
$reader='bootstrap/out/native-objects/b4addbfa91a54ca5bbbe9ca69e539a44/report.json'
$binding='bootstrap/out/native-extent-bindings/006f905ae83d421a80feaa066c1d5a73/report.json'
$graph='bootstrap/out/native-graph/3ae0e5a87d014b82a61adaae0cc28595/report.json'
$retention='bootstrap/out/native-retention/6adf39728481429ea8c9535278071297/report.json'
$frames='bootstrap/out/native-frames/157eecd5aacd410fade78655207ec826/report.json'
$support='bootstrap/out/explicit-link-inputs/318209f12b5b4f0282acf596c47e6386/report.json'
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/objects/check.ps1 -DiagnosticOnly
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

Each row names bootstrap/out/<gate>/<id>/report.json. All success fields are true.

| Gate | Report ID | Groups | Commands | Summed command ms |
| --- | --- | ---: | ---: | ---: |
| native-objects | b4addbfa91a54ca5bbbe9ca69e539a44 | 62 | 127 | 398867 |
| native-function-index | b553f504d80346ef8cc4d36fde3e67a3 | 832 | 832 | 26865 |
| native-leaves | 070cc74888414c128165a3ec5054112a | 256 | 288 | 10426 |
| native-instructions | cc00cfd20119464c90ba7ddddb633637 | 128 | 160 | 3797 |
| native-extent-bindings | 3a1a0ee9e61e42b9abb4d38652fd6dca | 416 | 576 | 38095 |
| native-unwind | 0d3989d52d6e4834973328aa95e40526 | 288 | 576 | 19120 |
| native-image-unwind | 7db9b08522fe4ad5b1d87b9ff3033c5f | 32 | 48 | 2663 |
| native-data-bindings | e34c37a1c15148a18db6f8894cd0d6d4 | 192 | 192 | 7421 |
| native-object-inputs | 2370fe88966f4ccfbe4c796a1272c6cc | 224 | 336 | 11546 |
| native-retention | 876d3469520c48f981ea378503704593 | 416 | 576 | 24708 |

All 587 distinct captured input paths across these ten reports passed a final
SHA-256 recheck. Timings are observations, not isolated performance benchmarks.
The component's 398,867 ms of child commands leaves inadequate overhead margin
under the prior 420-second whole-gate deadline. bootstrap/build-v2.ps1 now allows
600 seconds for native-objects. This changes only a test deadline; production
caps and declaration/body/argument bounds are unchanged. The eight-script
PowerShell parser check, including that build script and the new oracle, passes.

## Assertions and identities

Both component stages pass 23,081,511 assertions each. The new independent object
and image fixtures contain nine raw symbols, eight primary symbols, five selected
functions, two sections, unordered addresses, an alias and an auxiliary entry.
The exact order is raw indexes [3, 1, 4, 0, 5]. Undefined/absolute symbols and
nonfunction labels are excluded. Empty indexes also pass without payload.

For each fixture, retained payload is 20 bytes, peak payload 200, sort copying
20 bytes and physical allocations six. Exact and one-below byte/event/storage/
global-payload budgets pass; every allocation and every preparation/query
cancellation admission is refused independently with disposable partial owners
or unchanged scalar output. Twenty real remaining-root capacities per layout
exercise preparation refusal and cleanup. Full root pressure rejects fence
queries without changing their old result. Nonfresh owners reject unchanged.

The five-key queries read exactly 40 descriptor bytes: 19 events for three binary
comparisons plus a successor, or 15 for two comparisons and no successor.
Successful preparation preserves borrowed bytes and Err; successful queries
preserve Err and allocate/copy nothing. Ten altered anchor fields per layout
reject with the specified 1506/1509 code and preserve the old result. Corrupted
fence lengths and index-ready status fail their named oracle assertions.

The independent real-file oracle uses SDK COFF/PE offsets and exhaustive minimum-
successor searches, not production sorting/binary search. Its 320 comparisons
include 2,880 function-fence observations and empty indexes. Another 512 groups
reject shifted anchors (1506 at function zero) and incorrect expected lengths.
All preceding leaf/instruction, extent/range, data and retention gates pass.

NativeFunctionIndexes.bas: 14,183 bytes, SHA-256
5CFCE5A8391C92C25805DEF6C3DE025C38F9BFCF7C201C4CC296D2D1DE278B60.
Both stages emit identical 1,513,438-byte raw LLVM files, SHA-256
D0A44830C75724DD68BE00651E9747D37D6D47B3FDAF3BE006BAFDD17DFD92D1.
The pinned bootstrap cohort is df15817344774026bebebfd1e9ae8eaf; compiler SHA-256
846A9CD21EEF516E4D47CA1DECAE37B1BAF219530F930DC1107B0DABAB1917A7.
Reports retain all source/tool/artifact identities. The component and real-file
gates passed their first runs; no production correction or crash fix was required.

## Next action and limits

Use these qualified object/image fences with the qualified leaf traversal, bind
the resulting complete extents and maps to retained definitions, and reject
mismatched correspondence. Instruction/relocation equality remains a separate
required check. Full unwind/stack/reserve and startup/API/refusal qualification,
debug checks, production build ownership, current toolchain/bootstrap wiring,
publication and final source-cohort acceptance remain open. The full native-
executable goal remains active and incomplete.
