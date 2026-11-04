# Native leaf traversal evidence — 2026-11-03

The bounded reachable-instruction leaf consumer passes its two-stage component
and independent object gates. This completes the control-flow prerequisite under
First checked native executable; the whole deliverable remains incomplete.
NATIVE-LEAF-IMPLEMENTATION.md defines ownership, publication, resources and failure.
NativeLeaves is registered in the production manifest and existing native-objects
bootstrap gate. No production numeric cap changed.

## Commands and retained results

Run from the repository root in PowerShell. Reports below live at
bootstrap/out/<gate>/<id>/report.json. All report success fields are true.

```powershell
$reader='bootstrap/out/native-objects/263041b1db2c4323b953ae3e88693479/report.json'
$binding='bootstrap/out/native-extent-bindings/073f91491c7047e484834bafed0e32cb/report.json'
$graph='bootstrap/out/native-graph/3ae0e5a87d014b82a61adaae0cc28595/report.json'
$retention='bootstrap/out/native-retention/f608924c3a844ea9a788d6687c316d6b/report.json'
$frames='bootstrap/out/native-frames/157eecd5aacd410fade78655207ec826/report.json'
$support='bootstrap/out/explicit-link-inputs/318209f12b5b4f0282acf596c47e6386/report.json'
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/objects/check.ps1 -DiagnosticOnly
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/objects/check-leaves.ps1 -ReaderReport $reader -BindingReport $binding
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/objects/check-instructions.ps1 -ReaderReport $reader -BindingReport $binding
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/objects/check-extent-bindings.ps1 -ReaderReport $reader -GraphReport $graph -RetentionReport $retention
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/objects/check-unwind.ps1 -ReaderReport $reader -GraphReport $graph
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/objects/check-image-unwind.ps1 -ReaderReport $reader -RetentionReport $retention
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/objects/check-bindings.ps1 -ReaderReport $reader -FramesReport $frames
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/objects/check-generated.ps1 -ReaderReport $reader -FramesReport $frames
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/objects/check-retention.ps1 -ReaderReport $reader -GraphReport $graph -SupportReport $support
```

| Gate | Report ID | Groups | Commands | Summed command ms |
| --- | --- | ---: | ---: | ---: |
| native-objects | 263041b1db2c4323b953ae3e88693479 | 58 | 119 | 284858 |
| native-leaves | 6b33714d1df54262840898da4a17af65 | 256 | 288 | 8695 |
| native-instructions | 2349ae8a79344335aff2258f70c281a1 | 128 | 160 | 5100 |
| native-extent-bindings | 006f905ae83d421a80feaa066c1d5a73 | 416 | 576 | 34493 |
| native-unwind | a39a64d1150044aea91dce52a8ff2261 | 288 | 576 | 15755 |
| native-image-unwind | e90cc408ae8d48c2b537dde4afc49881 | 32 | 48 | 2486 |
| native-data-bindings | 004d477827894fd3a641d17269c6c59e | 192 | 192 | 7372 |
| native-object-inputs | 8f02fa3ffdb14f908a675dcb65daca63 | 224 | 336 | 11314 |
| native-retention | 6adf39728481429ea8c9535278071297 | 416 | 576 | 23379 |

Timing totals are observations, not isolated performance benchmarks. Independent
matrices ran concurrently. Each gate rechecks captured inputs; a final SHA-256
recheck of all 566 distinct input paths across these nine reports also passed.
DiagnosticOnly pins historical bootstrap tools without claiming current whole-
source bootstrap qualification. Object-generation and linked-image inputs remain
explicit retained artifacts, not a fresh current-source generation claim.

## Assertions

Both component stages pass 18,885,185 assertions each. Ten manual leaf vectors
check exact reachable maps, extents, instruction counts, byte/events and payload.
They cover multiple returns, merged branches, backward/self loops, unreachable
unsupported bytes, embedded RET bytes in operands and a 15-byte instruction.
Twenty-eight malformed/disallowed vectors reject escaping branches, continuation
targets in either discovery order, calls, indirect transfers, traps, nonvolatile
GPR writes, stack changes and truncation. Six invalid ranges reject unchanged.

Exact and one-below byte, event, inspection storage and global payload budgets
pass. Each of the two array allocations is refused independently; actual retry
attempts are bounded and retained payload matches owned arrays before disposal.
Cancellation at each of the 143 positive-vector admission events leaves an
unqualified disposable owner. Twenty real remaining-root capacities (0..19) test
entry/nested refusal and disposal under continuing pressure. Successful cases
assert input/Err preservation and zero copying. Nonfresh owners reject unchanged.

A 4,096-instruction straight-line case reads 4,096 bytes in 12,290 events. A
1,024-branch graph with 1,025 pending paths checks 2,049 instructions and 3,073
bytes in 8,197 events. Both use two allocations, exactly 5N payload and no copies.
Corrupted extent and success-status outputs are rejected at the specified oracle
assertion through both stages. Earlier binary/object/inventory/extent/instruction
assertions and their negative controls remain in the same passing component run.

The actual leaf gate uses pinned LLVM disassembly, checks its raw bytes against
each COFF file, and computes an independent fixed-point closure over the complete
instruction rows. It compares every boundary-map byte, complete reachable extent
and instruction count against production. This passes 64 object comparisons over
32 retained objects: 112 function observations and 2,416 reachable instructions.
Another 192 groups reject unsupported opcodes, branches into their own operands
and stack-changing instructions with 1506 at the first selected function.

For the optimized Err object, ube_err_set has extent 294 within fence 304 and 69
reachable instructions; ube_err_set_stack_exhausted has 273/288 and 41;
ube_err_number has 26/32 and 5; ube_err_clear has 117/117 and 23. The first-return
or next-symbol shortcuts would not establish these extents. Trailing padding is
excluded; unreachable interior bytes remain explicitly marked zero.

## Identities and diagnostics

NativeLeaves.bas: 7,537 bytes,
SHA-256 0245E6259FED4E76BC3F3A67A022A20CEC3D01186888668DDB98CE88E8E13721.
The unchanged NativeInstructions.bas has SHA-256
D9810337E1791EE873B0D68CE3A25A0A7AD3D15C30E50C6D3667C53D29C23826.
Both component stages emit identical 1,433,643-byte raw LLVM files, SHA-256
10579D0FDFC6EA05E126F9F5A79611BBEC9E123A5C41CFBFA9C8226F64FCC4C3.

Bootstrap cohort df15817344774026bebebfd1e9ae8eaf; stage-two compiler SHA-256
846A9CD21EEF516E4D47CA1DECAE37B1BAF219530F930DC1107B0DABAB1917A7;
manifest A8573742189253D557AD7527084E44C6A7E0ED56A937215DAF5EC8A083129445.
Pinned Clang SHA-256 F3425B2BFF01BC401C84AF6E5E180629182FAFC2EB35CF971A3E50C9CF13F263.
Reports retain complete source, tool, generated oracle and executable identities.

The initial component report 9ef26f112c394943bcdf8784e43f0980 failed the new
allocation-count oracle: each array takes one allocation, not two. Focused
allocation failure diagnostics also exposed GC-related allocation attempts; the
oracle now bounds those attempts and checks exact retained ownership. The first
focused root loop exceeded its 30-second diagnostic deadline by repeatedly
creating a million-root pressure setup. Reusing that setup across capacities
removed redundant test work; the final focused run (bootstrap/out/
leaf-diagnostic.json) passed in 6,494 ms. The contract's conservative event formula
was corrected before the accepted run to 3 + 2B + 2K.

Report 0081c372f38344ea8a3db979695b4f57 passed the first component stage but rejected
the leaf-length test control at an unintended failure-atomicity assertion. A
mutant writing length 1 did not alter the first RET-only result. Writing zero
makes the control fail immediately at the specified extent oracle. Production
code did not change after its initial implementation; these were test/contract
corrections, not production crash fixes.

## Remaining scope

The fence is caller supplied. The production build owner still must bind it to
admitted sections and retained definitions and qualify object/image leaf extent
correspondence. This walk establishes reachable boundaries and permitted GPR
writes, not memory safety, relocation/fixup identity, full unwind/stack/reserve
proof, startup/API/refusal closure, debug data, publication or native executable
acceptance. Next bind leaf candidates to retained object/image definitions and
qualify instruction and relocation correspondence. The full goal remains active.
