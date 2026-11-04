# Per-module native output

This implements the reviewed First checked native executable boundary. It uses
the existing declaration index, two graph walks, body consumer and single
reusable current-module writer. The owner's approved declaration/import work
allowance is 3*D+I; numeric resource caps are unchanged.

## Private import index

NativeGraph records distinct foreign target identities during its existing node
entry events. Reads, writes and exact address arguments can refer to foreign
module globals; ordinary calls can refer to foreign procedures. Intrinsics and
folded constants need no foreign LLVM procedure declaration. Pointer transport
still does not imply a runtime dereference or initialization requirement.

The per-module plan owns a D-byte Boolean mark array and a Long import list with
capacity min(D,V), adding D+4*min(D,V) payload. Both are reserved before allocation,
tracked separately on partial failure and released by existing graph disposal.
Their allocation zeroing is measured separately from declaration visits; no
source or prepared target is copied or mutated. Import lookup is constant-time
and list order is first encounter in the deterministic planning traversal. Every
node lookup belongs to its already-counted entry, including duplicate references.
The import list is emitted once with I actual target/formal visits. No additional
body walk, repeated whole-declaration scan, worker or public IR is introduced.

## Definitions and ABI

Emit typed foreign global/procedure declarations, then this source's members and
checked initializer. Procedure signatures share the same type/ByRef-owner emitter
for declarations and definitions. A native value remains the approved one-member
aggregate; each ordinary ByRef pointer is immediately followed by its i32 owner.
Imports name no incoming SSA values. Definitions retain their planned identities.

The module/member visit and existing procedure/entry/initializer visits are all
charged. Including preparation, each own declaration is visited at most three
times: modules at preparation/module entry/initializer definition; procedures at
preparation/member/definition; parameters at preparation/signature/entry storage.
Globals, locals, constants and unused type/intrinsic members need at most two.
Foreign target/formal visits use I. Fixed support and output bytes keep their
existing counters; compiler scratch never escapes its owner.

The module consumer borrows the checked catalog/module and prepared declaration,
graph and body state. It emits into the caller's already-open private writer,
without opening tools or files. The caller owns snapshot/write/release and all
cleanup after failure. A failed emission leaves disposable private output only.
Startup, shared data and metadata are separate selected output units; this work
does not change their ownership or claim the unfinished native builder is ready.

## Import-index component qualification — 2026-11-03

Exact command:

```powershell
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/emission/check.ps1 -DiagnosticOnly
```

Report: ../../bootstrap/out/native-emission/8e6f231391af488f9cf53e57f0901f76/report.json.
It passed 26 groups and 54 commands, with 8,437,497 assertions per stage.
The synthetic graph observer independently checks foreign procedures/globals,
duplicate reads and writes, omitted intrinsic/constant/local imports, invalid
target/scope failures, unchanged 42 graph work visits and zero growth copying.
The eight-node/503-declaration fixture now reserves 2,391 payload bytes, including
535 import-index bytes, with exact/below/above cap checks. Root-pressure partial
ownership and cleanup assertions include both new arrays. NativeGraphPlan is
136 bytes; the two array payloads are separately charged.

NativeGraph.bas: 30764 bytes, SHA-256
9F1304AC3E74775544C9B36750F5F824D34AA20E2CDFF98B5FD97898A01526D4.

This qualifies the import index component, not typed module output or the whole
native build. The completed checked-project and actual-work results follow.

The checked-project fixture also emits an isolated imports-only buffer to assert
I independently before exercising each complete module. Those extra diagnostic
visits are test work, not part of its whole-lowering resource claim. The separate
42-declaration fixture emits each actual module once per boundary trial and
checks the entire cumulative work against an independent node/edge/fact/argument
inventory, including preparation and all own/import declaration visits.

## Checked-module and actual-work qualification — 2026-11-03

Exact commands:

```powershell
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/graph/check.ps1 -DiagnosticOnly
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/resources/import-work/check-emission.ps1 -ReportPath bootstrap/out/native-graph/a04adb0a0941407f8d1e63c4c31930cb/report.json
rtk proxy git -c core.safecrlf=false diff --check
```

The graph report a04adb0a0941407f8d1e63c4c31930cb passed 154 groups and 342
commands in 720,874 ms: 971 graph assertions and 2,108,367 body assertions per
stage. Both raw LLVM images are 7,914,158 bytes with SHA-256
95982926A4EE16D5CAA9AF007887849EBA358DAF42B0A60361DEDEEA678A4012.
NativeBodies.bas is 70,077 bytes with SHA-256
5BB7D4B3A331EEFC5F8C6F7BAAC628B76754565CBB9E0D6866B789BC66E854AD.

Actual one-package and direct-library-reference checked projects now produce
three independent module outputs plus the schedule output. Each is compiled to
its own object before linking. O0/O2 native observers assert normal order,
already-completed dependencies, refusal/latch propagation, Main values and exact
Err/revision behavior. Separate-object access tests retain scalar/native calls,
ByRef ownership, unused forwarding and failure unwind. Jobs 1/2/4 produce identical
module bytes and cumulative work/identities. Existing combined-unit and adverse
controls remain in the same gate; generated combined bodies remain byte-identical
to the prior qualified outputs after signature extraction.

The actual-work report is
../../bootstrap/out/native-import-emission/b805c56cc1f8443badedd1b25f070db2/report.json.
It passed six groups and 56 commands in 15,133 ms against both qualified adapters.
The checked 42-declaration project has exactly 126 own visits plus 210 import
visits. Its independently inventoried body/edge/fact/argument work brings the
actual cumulative total to 2,925. At jobs 1 and 4, caps 2,925 and 2,926 succeed;
2,924 returns controlled resource failure 1502/resource 5. Every trial releases
scratch, declarations and output; checked graph/facts and prepared declarations
remain byte-for-byte unchanged. I <= V+A+1 is asserted. Eleven separately compiled
objects link at O0/O2, Main returns 21 across the twenty-formal call, and incoming
Err/revision are unchanged. The test deliberately supplies completed-module
state and controlled frame metadata; initialization execution is covered by the
three-module gate above.

The actual-work gate is registered immediately after native-graph in
bootstrap/build-v2.ps1, using that exact successful cohort's report and checking
its artifact/tool identities. Runner syntax and diff whitespace checks pass;
the complete refreshed source-built bootstrap has not been run. All three test
handles are terminal with exit 0. No numeric resource cap changed.

Per-module LLVM output/imports are qualified within this tested subset. Ordinary
platform process entry, real startup stack-floor query/frame footprints/reserve,
platform wait, warning delivery, tool/debug/publication integration and the full
updated source-built acceptance cohort remain unfinished. The next consumer is
ordinary process entry: establish startup safety, execute the qualified normal
initialization schedule, then admit and call selected Main with the specified
exit/error behavior.
