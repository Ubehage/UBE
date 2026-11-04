# Generated storage ownership evidence

Scope: NATIVE-STORAGE-OWNERSHIP-IMPLEMENTATION.md. All nine qualification gates and the unchanged-input audit pass. The bounded
generated-storage goal is complete; the full native executable deliverable
remains unfinished.

## Narrow diagnosis

The pre-change diagnostic is retained at
`bootstrap/out/native-storage-gap-contract-review/report.json` (SHA256
BAE929CD4B4EA99658DA7D5C9CEFC2D10685953D564B499712D9341ECA462F38).
Command:

~~~powershell
rtk proxy powershell -NoProfile -ExecutionPolicy Bypass -File bootstrap/out/native-storage-gap-contract-review/run.ps1
~~~

Both earlier qualified adapters accepted a matched discardable target/owner
descriptor, and independently accepted two distinct owners with the same
positive 16-byte extent. This reproduced component-consumer gaps; it did not
demonstrate acceptance by an integrated executable validator.

The independent pre-change census in `bootstrap/out/storage-alias-review.json`
captured and rechecked 284 input identities, covering all sixteen images,
four complete frozen TSV tables, 144 per-unit binary tables and 112 relevant
producer objects. Every image had sixteen disjoint, resident generated owners.
The only permitted container overlap was the two generated TLS members inside
the 800-byte TLS template. Empty CRT markers and multiple labels of one extent
did not establish additional positive owners.

## Implementation and focused proof

NativeStorageOwnership borrows the complete frozen expected table, aligned
retained definitions, a complete RVA order and independently bounded protected
storage views. It adds no allocating index, sorting algorithm, public option or
numeric cap. Exact section geometry, shared initialized-prefix/full-virtual
isolation, existing permissions and nondiscardability establish residency.
Disjoint positive intervals plus exact order count establish generated-owner
coverage without a bitmap. Existing TLS readers supply container/member rules.

NativeBindings shares its isolation loop with the zero-fill-capable storage
entry point and rejects discardable generated data. Existing fully initialized
callers retain their admission rule and byte/event accounting. Existing length
and family helpers are exposed instead of reimplemented. The new retained-array
length declaration uses the already adopted Array.Length primitive.

Focused command:

~~~powershell
rtk proxy powershell -NoProfile -ExecutionPolicy Bypass -File bootstrap/out/native-storage-literal-review/run.ps1
~~~

It passed `--storage-ownership` and `--generated-targets` through the current
stage0 adapter. The independent literal oracle asserts exactly 3996 bytes and
934 events, with a derivation in the contract. Cases include every generated
storage family, ordinary/partial/full zero-fill, TLS containment, adjacency,
optional absence, full order coverage, protected overlaps, malformed ranges,
resource limits, all cancellation admissions, unchanged inputs/Err, refusal of
allocation and actual root exhaustion. The matched discardable target regression
separately rejects with 1506 and one zero-byte event.

The first focused run stopped at a test-fixture resize: a synthetic record array
without a copy hook was resized with Keep=true. The fixture now uses Keep=false
and an explicit test-side copy. No production change was needed for that failure.
The failed report remains at
`bootstrap/out/native-objects/9432590827c541849647da8bde8b4e3a/report.json`.

## Completed qualification - 2026-11-04

All nine gates passed, followed by the verification-only identity audit.
The following commands were executed from the repository root (variables below
abbreviate their exact path arguments):

~~~powershell
$gate = 'compiler/UBE_Compiler_v3/tests/native-executable/objects'
$reader = 'bootstrap/out/native-objects/06e4f4e7c34b4568845043c72be21dba/report.json'
$retention = 'bootstrap/out/native-retention/876d3469520c48f981ea378503704593/report.json'
$graph = 'bootstrap/out/native-graph/3ae0e5a87d014b82a61adaae0cc28595/report.json'
$priorBindings = 'bootstrap/out/native-extent-bindings/993405c3268a446da0588ad5bfa6fa6f/report.json'
$bindings = 'bootstrap/out/native-extent-bindings/4f91c79815074e3982112a3d1417286d/report.json'
$instructions = 'bootstrap/out/native-code-instructions/5f9ea9a2e9be456190b74b1b3d08066e/report.json'
rtk proxy powershell -NoProfile -ExecutionPolicy Bypass -File "$gate/check.ps1" -DiagnosticOnly
rtk proxy powershell -NoProfile -File "$gate/check-storage-ownership.ps1" -ReaderReport $reader -RetentionReport $retention
rtk proxy powershell -NoProfile -File "$gate/check-extent-bindings.ps1" -ReaderReport $reader -GraphReport $graph -RetentionReport $retention
rtk proxy powershell -NoProfile -File "$gate/check-instructions.ps1" -ReaderReport $reader -BindingReport $priorBindings -WholeCode
rtk proxy powershell -NoProfile -ExecutionPolicy Bypass -File "$gate/check-instructions.ps1" -ReaderReport $reader -BindingReport $priorBindings
rtk proxy powershell -NoProfile -ExecutionPolicy Bypass -File "$gate/check-unwind.ps1" -ReaderReport $reader -GraphReport $graph
rtk proxy powershell -NoProfile -ExecutionPolicy Bypass -File "$gate/check-image-unwind.ps1" -ReaderReport $reader -RetentionReport $retention
rtk proxy powershell -NoProfile -ExecutionPolicy Bypass -File "$gate/check-image-relocations.ps1" -ReaderReport $reader -RetentionReport $retention
rtk proxy powershell -NoProfile -File "$gate/check-fixups.ps1" -ReaderReport $reader -BindingReport $bindings -InstructionReport $instructions -ThreadStorage
~~~

Reports are relative to bootstrap/out:

| Gate | Report | Groups | Commands | Summed child ms |
| --- | --- | ---: | ---: | ---: |
| Component | native-objects/06e4f4e7c34b4568845043c72be21dba/report.json | 136 | 275 | 945009 |
| Generated storage | native-storage-ownership/fcb4f6068aed49f1bd3cbf71f7755dd4/report.json | 32 | 34 | 37785 |
| Retained extents | native-extent-bindings/4f91c79815074e3982112a3d1417286d/report.json | 416 | 576 | 39595 |
| Complete instructions | native-code-instructions/5f9ea9a2e9be456190b74b1b3d08066e/report.json | 2240 | 2352 | 66831 |
| Retained leaves | native-instructions/e21324af9f704e309e8e374df57c3f2d/report.json | 128 | 160 | 6806 |
| Object unwind | native-unwind/17e3851c1d3d4f56bfddeea1dbf017df/report.json | 288 | 576 | 20543 |
| Image function tables | native-image-unwind/a0239e779312450397f6932f3bc1416e/report.json | 32 | 48 | 2568 |
| Image pointers | native-image-relocations/bee64f4b3c2f4e8f8f68fcd201bc6ca7/report.json | 34 | 36 | 76622 |
| TLS/import/reference/generated/signed targets | native-fixups/692df3b3df584022aace350d81cc247d/report.json | 4064 | 4068 | 208179 |

Both readers pass 52,456,374 component assertions and emit identical raw LLVM:
2,147,149 bytes, SHA256
BE8F72D2610177969569CEB76DA6424AD88378792B7708C557D11ACE99B46668.
The 945,009 ms component child work fits the existing 1,080-second enclosing
allowance. Production caps and test allowances are unchanged in this step.

| Changed production source | Bytes | SHA256 |
| --- | ---: | --- |
| NativeStorageOwnership.bas | 8751 | 16CD807211CA4B8A7F1BB852F999D0E076EFA4BD64971901BE1B12E78F31E04C |
| NativeBindings.bas | 27557 | CDAC611316F1989037037CB553E1D0C42BEA1B120A3C25AC3E513EC223AF3580 |
| NativeExpectations.bas | 15336 | 504E039E434585A553871413179E8043FC729439E486C9653D939F58D7EA4B64 |
| NativeInventories.bas | 16551 | 031E5071C049F74733556CDDF137C93053BB8641D7FFB3A79341DBB601A2367A |

The retained storage gate independently binds every frozen row to its producer
object and image, then compares exact storage geometry to its separate PE census.
All 32 image/reader groups use the complete 54-row table and sixteen storage
owners. Each rejects 220 controls: 7,040 rejected candidates overall. Each call
compares physical byte/event observers, confirms zero allocation/copy, unchanged
borrowed arrays/layout/table and preserved Err.

| Image profile | Protected views | Measured bytes | Measured events |
| --- | ---: | ---: | ---: |
| O0 Full/None | 194 | 18,036 | 4,907 |
| O2 Full | 189 | 20,356 | 5,477 |
| O2 None | 189 | 18,036 | 4,897 |

Protected views include reference cells, complete bounded import views, image
exception/relocation directories, seven previously qualified CRT pointer cells,
and all 76 O0 / 71 O2 referenced unwind records. Each image has two bounded
36-byte __C_specific_handler records including one scope entry. The oracle JSON
records their exact geometry; these bounded extents do not prove unwind semantics.
TLS metadata and template/member rules are independently read inside the consumer.

The image relocation regression retains 1,568 pointer-field comparisons and
4,704 rejected mutations, plus both 1198-byte/311-event literal suites. The
other retained gates preserve their predefined instruction, extent, target and
unwind assertions on the new readers.

The audit procedure is bootstrap/out/audit-native-storage-inputs.mjs, executed
through Node REPL as auditModule.audit(root, reportPaths), where reportPaths is
exactly the nine report paths in the table above. It requires passing reports,
rejects conflicting identities, and rechecks byte length plus SHA256 for every
recorded input, all report documents, the three existing pointer/directory
observations, and the audit procedure itself. Its output
bootstrap/out/native-storage-input-audit.json records success and 666 distinct
unchanged paths. This is verification-only source/artifact auditing, not compiler
source monitoring or retry behavior.

## Remaining parent-deliverable boundaries

Protected completeness and producer association are explicit caller obligations;
the consumer does not infer them from arbitrary candidate symbols or a supplied
subset. Independent positive CRT pointer cells and metadata can be protected,
but arbitrary CRT object widths cannot be inferred from the next symbol address.
Runtime CRT/API writes, register/control/dataflow, stack/debug proof and actual
builder/publication integration remain separate parent-deliverable obligations.
Ordinary global initial values are not established by this geometry/ownership
consumer; it reuses neutral-content checks for TLS members only. Bounding and
protecting unwind records does not prove their complete instruction semantics.
No full current-source bootstrap or end-to-end executable build is claimed.
