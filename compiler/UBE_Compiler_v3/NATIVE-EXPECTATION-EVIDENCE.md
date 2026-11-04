# Expected linkage inventory component evidence - 2026-11-03

NativeExpectations.bas implements the pre-tool identity owner specified in
[NATIVE-EXPECTATION-IMPLEMENTATION.md](NATIVE-EXPECTATION-IMPLEMENTATION.md).
The component fixture checks bounded construction from an independently specified
ready lowering plan. The current full-compiler graph gate additionally qualifies
actual checked-project construction and emitted LLVM/object membership. Producer/CU
metadata and complete object-to-image retention remain unfinished.

## Checked-project integration follow-up

The checked-project integration exposed a missing optional source helper: actual
module LLVM contains `ube.error.if`. Family 23 now records it per source, with
capacity D + 3*M + 19. The nine-declaration oracle now requires 30 rows and
2,992 owned bytes. The focused command
`rtk proxy powershell -NoProfile -File bootstrap/out/check-expected-helper-regression.ps1`
recompiled the new oracle against retained old production LLVM and rejected it
at the expanded inventory assertion (controlled exit 1, no timeout). Its result
is `bootstrap/out/expected-helper-regression.json`.

The first corrected component report,
`bootstrap/out/native-objects/427bf1fc140745faaa259fbc4af4379e/report.json`,
passed first-stage positive checks and rejected the missing-count mutant. The
runner still matched the old count in its expected diagnostic; that test-only
match is corrected. The component rerun passes in
`bootstrap/out/native-objects/b2cb00eff2ea4ac39a9e66943c584479/report.json`: 34 groups,
71 commands, 132,698 ms and 6,296,786 assertions per stage. Both raw outputs are
1,184,555 bytes, SHA256
`002BDA0D94882859998A03069F3D0471509F4A4FF743AB22457A57EBB7D3C199`.
The expanded fixture checks 453 name bytes, 495 events, nine declaration visits
and 2,992 owned bytes. NativeExpectations.bas is 15,344 bytes, SHA256
`8F9B4D95A2FA349271DFA7472BC4F61821508EA2E8658C63A10A7F5B09E5E64A`.

The same check-bindings/check-generated commands below, using that new ReaderReport,
pass in `bootstrap/out/native-data-bindings/d8be72678f29479b88157bdffe620703/report.json`
(192 groups) and `bootstrap/out/native-object-inputs/f1b6be4c5d4d4bc29e7e17f474fd1047/report.json`
(224 groups). The actual checked-project graph gate now passes as recorded below.
The earlier checkpoint below retains its historical scope and identities.

## Actual checked-project integration

Command:

```powershell
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/graph/check.ps1 -DiagnosticOnly
```

PASS report: `bootstrap/out/native-graph/3ae0e5a87d014b82a61adaae0cc28595/report.json`.
The gate passes 350 groups and 798 commands (910,791 ms summed command time).
Both stages freshly compile the current complete compiler manifest, with all
current Core dependencies, using the retained qualified bootstrap tools. The
compilations take 500,159 and 290,985 ms. Raw LLVM is byte-identical: 8,388,787 bytes,
SHA256 `E99A82FA54A85D7D0433954EDCC43D7A184093C9DB241E65B8726039176ABFDE`.
Each stage passes 971 graph and 2,110,568 body assertions, including the retained
native behavior/owner/initializer/entry controls. All 190 captured input hashes
matched at that checkpoint. The later retention consumer changes NativeBindings
and NativeInventories; NATIVE-RETENTION-EVIDENCE.md records their separate current
qualification. DiagnosticOnly does not claim a refreshed whole bootstrap cohort.

The actual checker admits the three-source root layout and the direct Core
reference layout at jobs 1/2/4. Production expectation construction receives each
ready declaration plan and the actual selected Main. An independent C oracle
checks source/declaration identity, all 14 procedures, nine Long globals, three
initializers and each fixed/optional helper family. Locals, parameters, constants
and intrinsic declarations are excluded. The target array and preexisting writer
charges remain intact; disposal releases only the expectation owner's payload.
Both layouts and both bootstrap stages report:

| Quantity | Measured value |
| --- | ---: |
| Declaration rows visited | 38 |
| Frozen expected rows | 54 |
| Used name bytes | 647 |
| Added declaration work | 38 |
| Inspection events | 742 |
| Owned payload bytes | 5,808 |

Rows and used names are byte-identical for jobs 1/2/4. The emitted TSV tables also
match between bootstrap stages. The test-only PowerShell oracle requires every
actual LLVM definition to have one frozen row in its output unit; required source,
global, initializer and support definitions must be emitted, while optional inline
helpers may be absent. It excludes external declarations explicitly. Missing,
duplicate and wrong-owner expectation controls reject through both stages.

The test compiles all nine output units for both project layouts at O0/O2 with
Full/None options and no LTO: 72 objects per stage, 144 total. Test-only llvm-nm
checks required names exactly once and checks function/data symbol kinds. Optional
pre-object elimination remains allowed. Production does not use nm or parse LLVM
text. No object-to-image retention or complete backend-generated symbol ownership
is claimed here; reference-pointer auxiliaries and relocation targets remain
binding work. Full options alone do not prove UBE debug metadata. Frame output
uses controlled positive footprints and reserve 256, not derived stack bounds.

The graph C fixture also passes clang -std=c17 -Wall -Wextra -Werror -fsyntax-only.
`bootstrap/out/check-graph-expectation-syntax.ps1` passes both PowerShell parser
checks; git diff --check and explicit changed-file trailing-whitespace checks pass.

Next consume the frozen identities and checked inventories for surviving-definition
mapping and object-to-image instruction/fixup comparisons. Exact code extents,
producer/CU/debug records, complete recovery reserve and entry/stack safety,
native builder/publication and final current-source qualification remain required.

## Earlier component commands and results

```powershell
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/objects/check.ps1 -DiagnosticOnly
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/objects/check-bindings.ps1 -ReaderReport bootstrap/out/native-objects/d92c32e784ee4f51a3143d14e10912c8/report.json -FramesReport bootstrap/out/native-frames/157eecd5aacd410fade78655207ec826/report.json
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/objects/check-generated.ps1 -ReaderReport bootstrap/out/native-objects/d92c32e784ee4f51a3143d14e10912c8/report.json -FramesReport bootstrap/out/native-frames/157eecd5aacd410fade78655207ec826/report.json
rtk proxy powershell -NoProfile -File bootstrap/out/check-binding-scripts.ps1
```

PASS: component report
`bootstrap/out/native-objects/d92c32e784ee4f51a3143d14e10912c8/report.json`
contains 34 groups, 71 commands and 120,618 ms summed command time. Each bootstrap
stage passes 6,296,628 assertions, including retained root-registry exercises.
Raw LLVM outputs are identical: 1,183,029 bytes, SHA256
`B3342F178244979A7A18738794798CE491F7A21046F86E6C6973D37A70D32F06`.

The retained production integer-data gate passes 192 groups/commands in
`bootstrap/out/native-data-bindings/2b9b30cb4cee4c63b754f5f514b46cdb/report.json`
(6,210 ms). The generated-binary reader gate passes 224 groups/336 commands in
`bootstrap/out/native-object-inputs/2f7f3a32b42a43ff9cc90118c14847b8/report.json`.
These still consume historical qualified frame outputs; they do not regenerate
the current whole compiler. The four script syntax checks pass.

NativeExpectations.bas is 15,084 bytes with SHA256
`5FED369CFCA09D4ADB966BFF30CE33A8FD93B77F466EE766E1E9B3A2047DF70F`.
The component extracts the exact production declaration-target/owner records,
ReadNativeDeclarationTarget and TryVisitNativeIndex helper bodies; it does not
replace them with mock UBE types. The C test independently supplies a nine-row
lowering plan for two sources, two ordinary procedures, one global, a parameter,
a local, an intrinsic conversion and a constant. Complete-source frontend and
lowering integration are the next acceptance work, not a claim of this fixture.
DiagnosticOnly uses the retained qualified bootstrap tool cohort with current
component source. All final captured input identities still match.

## Independent expectations and measured work

The handwritten oracle specifies all 28 output rows: exact linkage bytes,
source/declaration IDs, output unit, family, object-presence requirement, storage
size, nominal type and representation. It checks separate source helpers,
canonical procedure/global names, mandatory Main, fixed platform/entry/data/error
support, and exclusion of locals, parameters, constants and intrinsic conversion
declarations. The maximum signed target identity produces the exact decimal name.
No expectation is read from the generated object or image.

The fixture observes exactly nine added native declaration-work visits, 429 name
bytes, 469 inspection events, zero examined candidate bytes, two allocations,
zero payload copying and 2,816 live/peak owned payload bytes in both storage
ledgers. Incoming Err and the borrowed target array remain unchanged. Missing-row
and omitted-work bridge controls are rejected through both stages. Existing
reader/inventory controls remain passing.

Exact/one-below parser payload, global payload, declaration work and inspection
event budgets are checked independently. Both allocation failure positions retain
accurately charged disposable partial ownership. Cancellation at every inspection
admission preserves incomplete status and correct counters; disposal works after
cancellation. Invalid Main selection, negative identity, invalid source/scope and
maximum identity boundaries have explicit expectations. Final process assertions
require no live allocations or roots.

## Retained diagnostic corrections

Report `d847124871414ab4a8996e62994bf7f6` rejected missing StringLength declarations
in the focused test entry. Adding the existing bootstrap StringLength/StringByteAt
intrinsic declarations corrected the fixture; no new primitive was introduced.
Report `3361f6cc9236444da18414568c065297` returned controlled failure 1509 after
five declaration visits and eight rows. A focused run using that exact compiled
body showed a parameter inheriting the previous procedure's family: bootstrap
loop-local records reuse storage. Explicitly assigning a neutral scalar row before
each declaration/support record fixes the defect. The independent row oracle
failed before that fix and now checks every field; no panic/crash occurred.

Report `28dabbcd5642456c932fc2081f1f2c75` passed the first-stage synthetic/oracle
checks but its expected-count adverse control timed out at ten seconds while
running unrelated earlier root-pressure cases. The maintained control now invokes
the expectation fixture directly with the same ten-second bound. It rejects the
intended corrupted row/work result; no timeout was treated as successful rejection.

## Resource decision and remaining work

This implements the approved pre-tool table with one additional D-row traversal.
Lowering itself retains 3*D+I; combined declaration/import work with this table is
4*D+I. The owner's authorization for necessary measured increases is recorded in
NATIVE-DECLARATION-WORK-REVIEW.md. Numeric caps, body and argument traversal bounds
are unchanged. The actual checked-project gate above measures the added D
contribution; complete builder resource acceptance remains pending. The earlier
lowering-only counterexample retains its historical scope.

The subsequent checked-project gate above completes construction and emitted
LLVM/object membership integration. Next consume the frozen rows for
retained-definition/instruction/fixup checks. Producer
markers, original path/CU associations, complete debug/stack/reserve analysis,
native builder/publication and final current-source qualification remain required.
