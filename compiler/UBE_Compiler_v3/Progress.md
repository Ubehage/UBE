# UBE Compiler v3 progress

## Qualified bounded semantic checker - 2026-11-02

First semantic checking is complete for its approved scalar/native MODULE
subset. The production manifest includes the checker, diagnostics, existing
check path and shared source-worker controller. Maintained tests consume the
actual production closure, real UBECore reference and independent expectations.
Accepted source-built cohort: `88d1906a667645fa87f885c3a117e52f`; manifest SHA-256
`9C4BFED73CF3CF4C42A768B68B61A6C0F318D0E038EC64B66D30BDFEC75BFEB9`.

[SEMANTIC-EVIDENCE.md](SEMANTIC-EVIDENCE.md) records the final bootstrap 894,
whole/catalog/expression/formatter/controller/CLI/resource/cost/sharing gates,
independent definitions and retained parser/source/project/local/lifetime/
concurrency proofs. The first concurrency attempt's 180-second emission timeout
is preserved separately; the unchanged quieter rerun passes both stages.

Supported successful checks exit 0 with empty output and publish no executable.
The full compiler and actual Core source remain deferred by the subset. Full
grammar/native execution and semantic performance are separate future claims.

The next existing deliverable is First checked native executable. Review its
bounded program set, lowering/backend, ABI/runtime-error and tool-handoff
contracts before implementation. No new executor or public phase API is implied.

## Historical implementation and foundation checkpoints

The sections below preserve their dated source cohorts and then-current
capabilities/actions. Current status is above and in Active next action below;
earlier OUT candidates and unavailable-check messages are not current claims.

### Earlier foundation qualification

Implementation continuation: four measured ordinary library modules are now
registered by the actual UBECore source reference: SignedIntegers, ByteKeys,
StorageCapacity and Utf8Encoding. Their maintained integrated gates and the
arena/four-UBE-worker foundation gate are registered in the source bootstrap.
That foundation source build passed 894 acceptance assertions, selecting
`bootstrap/out/v2/3d4622079d9d476d9aad890dfa8593e8/manifest.json` (SHA-256
`70B1F55EF276E2DAA12EB2939775E2FFA7AB7B68A0DCDC59476D16FEF55D1392`).
Command: `rtk proxy powershell -NoProfile -File bootstrap/build-v2.ps1`.
A subsequent `Get-VerifiedBootstrapSelection` audit passed against current
source/tool/artifact identities. The first attempt exposed the bootstrap's
Public-only reference restriction. A focused fix admits Private procedures
only within their original library module, retaining global duplicate rejection
and all other existing reference restrictions. Source-reference qualification
now includes private ordinary/intrinsic success and executable/peer-module denial.

The integrated proof reports are `bootstrap/out/signed-integers/
3ea27b94e3714a739f305b026b6200e9/report.json` (18 maintained assertions),
`bootstrap/out/byte-keys/e5b92a8f100a4ff3be60dafaf5665821/report.json` (20),
`bootstrap/out/scalar-storage/827996ac2e04453c9c78c27285fa3b60/report.json` (18),
and `bootstrap/out/semantic-foundations/fa9782ee12734ab7abee833ac22e1434/
report.json` (35). These include independent native values, executed work,
real-backed root/allocation denial, corruption controls and unchanged input
identities through both selected stages. They qualify the selected library/
arena/sharing components, not a semantic checker.

At this earlier foundation checkpoint, private candidates under
`bootstrap/out/semantic-implementation/` covered the model, declarations/names,
expressions/calls, constants, statements and coordination. Those copied reports
remain candidate evidence. The later implementation and independent complete
oracles are now maintained under src/ and tests/semantic/native/; production
qualification is recorded in the current status and final semantic evidence.

The first dependency is the retained parser detail in SYNTAX-DETAILS.md.
SyntaxNode/SyntaxResult layouts remain unchanged. Existing grammar paths now
retain declarators, passing/default/type information, rank/bounds, modifiers,
option/attribute parts, suffixes and written procedure/Exit kinds. New internal
child roles use the same owned arena; no source reparser or source payload copy.
The 12 independently authored full-detail cases are
`tests/parser/native/declaration-details.json`. Old fixtures retain their original
logical comparison; the complete physical graph is validated before projection.

The retained parser detail is now qualified for source cohort04c. It is not a
semantic checker.
The focused stage-one diagnostic executes all 200 frozen/supplemental cases
(1,865 native assertions), including all 12 complete physical-detail trees.
The final diagnostic report is
`bootstrap/out/declaration-fixtures/1a8c24b3a77a47c1acc5536027cd14d1/report.json`.
Four deliberately corrupted detail expectations were rejected. The separately
observed 51 cost rows pass 1,131 native assertions and 710 maintained measurement
assertions, including four measurement corruption controls; see
`bootstrap/out/declaration-fixtures/85d6c224e35a4123bc6d1ee0c3d076a7/`.
These diagnostic runs alone do not qualify the parser.

The complete current-source command `rtk proxy powershell -NoProfile -File
bootstrap/build-v2.ps1` passed and selected source cohort
`bootstrap/out/v2/04c889304e52467bbf597ac84269317e/manifest.json` (SHA-256
`2E9F51AD844CAE40CDD046EC85346604DE5F57B8F02C6CE306B11039135ECADC`).
It retains the fixed point and all 785 predefined bootstrap assertions.
The strict command `rtk proxy powershell -NoProfile -File
compiler/UBE_Compiler_v3/tools/check-parser.ps1` passed 1,879 maintained checks at
`bootstrap/out/parser/eee096abee4d4e85bd22a7fbd9399ec2/report.json`.
It covers all 200 cases, exact details, both stages, actual faults and exhaustive
real-backed root capacities, worker sharing, cost bounds and comparator controls.
Existing CLI/lifetime/concurrency gates still need reruns for the final checker.

All 20 updated syntax inventory entries pass 829 source-witness assertions in
`bootstrap/out/declaration-inventory-current.json`; this is source evidence only.
`SEMANTIC-PROBES.md` fixes the subsequent native storage/lookup/numeric probe
obligations. Focused numeric probes found a bootstrap prerequisite gap: both
stages reject general LongLong arithmetic at emission, and signed-minimum
negation wraps with stale Err. Reproductions are
`bootstrap/out/numeric-prerequisite/57f92f43e69c4e41a33003240d5ac3ee/report.json`
and `bootstrap/out/wide-negation/c09b7437b31c4a4b946b1b9e063b6dca/report.json`.
The focused repair contract is v2 `tests/wide-integers/CONTRACT.md`. Checked
machine helpers and the existing emitter path now cover the six signed-64
operations. Its focused gate passes eight maintained assertions, including 79
independent native cases/158 value-and-Err assertions per stage, identical raw
LLVM and a deliberately wrong expected-value control. Report:
`bootstrap/out/wide-integers/da45734c3cc744f1b21ed7d6abd26e9a/report.json`.
The full command `rtk proxy powershell -NoProfile -File bootstrap/build-v2.ps1`
passed all 793 acceptance assertions and selected source cohort
`bootstrap/out/v2/281e3cb01f86415793da82acd8d13c2c/manifest.json`.
It retains every previous 785 assertion plus the eight focused wide-integer
assertions. All earlier reports remain bounded to their exact preserved cohort;
final parser/CLI/lifetime/concurrency gates must cover the eventual checker.

Sorted/bounded-hash test candidates are drafted below `bootstrap/out/` only.
`run-key-index-functional.ps1` passes 73,041,611 functional assertions per stage
at `bootstrap/out/key-index-functional/208d329faa6e4d9da2efe5833a9b8315/report.json`.
This covers all preset sizes 0/1/8/64/1024/16384, increasing/reversed/duplicate/
common-prefix/empty-byte keys, complete stable equal-key groups, range queries,
controlled collision work, unchanged input and final zero retained allocation.
It is a diagnostic candidate comparison, not a selected representation: actual
copy/allocation/root observations subsequently pass in
`bootstrap/out/key-index-observed/f93ba211053641cf85453f410145a9b8/report.json`:
73,041,873 native assertions per stage, plus 4,204 host measurement assertions
and five deliberately corrupted counter/copy/allocation/memory controls in its
`measurement-checks.json`. Actual publication copies are exactly one logical
payload; query allocations/copies and key-byte copies are zero. Source-audited
physical bounds are now preset in SEMANTIC-PROBES.md for the later maintained
acceptance run; these earlier diagnostic rows are not retroactive acceptance.

Actual allocation-denial sweeps with an unrelated old complete index and two
distinct input owners pass 1,392 assertions per stage at
`bootstrap/out/key-index-observed/1fbd0d1a7c984b519d26b9629a6a7ca6/report.json`.
Every observed allocation site fails safely, preserves the old graph/owners,
cleans temporary storage and recovers. Domain probes pass 129 assertions/stage
(`eb5b70d3f0d043268e7a8b2f4aa56d75`); the real 17-byte-copy observer control
passes 23/stage (`3b5638ea5c274149b2e39d791adf8184`). These IDs are under the
same `bootstrap/out/key-index-observed/` directory. The final root fixture adds
constructor and query actors: measured additional roots are 32/40/6/7. All 16
gap-free ranges across both stages, from zero through exact-plus-one capacity,
pass under actual one-million-record pressure at
`bootstrap/out/key-root-ranges/4ec66266602845a59a179e1beb532bbc/report.json`.

The ordinary-UBE signed integer/ASCII decimal candidate passes independent
results, old-output/Err preservation, signed minima, bitwise operators and
0/1/8/64/1024/16384 digit scaling through both stages. The observed run at
`bootstrap/out/signed-integer/012a408b55124308a703f9f888c4d8fb/report.json`
passes 2,101,133 native assertions/stage and wrong-expected-value controls.
It reuses the 79 maintained boundary cases, adds 44 operator cases, 169 ordered
comparison pairs and 43 decimal spans (including embedded zero), tests old Err
7/77, and proves zero allocation/copy and preset actual machine-operation bounds.
Decimal entry needs one additional actual root; zero/exact/above capacities
preserve the old scalar output on denial. The entire scalar cohort also runs
successfully while the root registry is completely full. Draft numeric bodies
are `bootstrap/out/signed-integer-candidate.bas`; no UBECore API is adopted yet.

Arena/name probes, complete maintained packaging and UBE-driven immutable sharing
remain before representation/API selection. The first lookup attempt
used an incorrect harness assertion that required an already-empty collection
to reclaim something; the corrected gate checks the required zero remaining
allocation instead. No production collector change was justified or made.

Exact initial source/parser-test/tool backup: 90 byte-compared files under
`bootstrap/out/semantic-baseline/549405a6379c411eaedfda49e1932ce9/`, with
`files.json` and the initial accepted selection. The earlier 2c0 cohort remains
the pre-change reference. Probe drafts have begun; production semantic storage,
generic UBECore numeric facilities and the checker are still unimplemented.
Keep their whole approved scope intact.

## Owner literal and initializer clarification - 2026-11-01

The owner accepted the basic checking scope and made clear that foundation-first
development is already given. Review ordinary behavior using VB6 unless it
conflicts with an established UBE definition; ask only actual behavior questions.

Unsuffixed literals must fit their selected integer types, widening beyond a
narrower destination context when necessary. `Dim x As Integer = 40000 - 10000`
has the same declaration/assignment behavior as two separate lines: x exists
with neutral storage before its initializer, the calculation uses a wider
integer, and 30000 converts to Integer. Storage remains after recoverable
runtime initializer failure. The specification, contract, conversion table,
public manual and independent cases record this clarification.

The additional four cases distinguish initializer/split assignment, typed wider
literals, self-reference to already declared storage and storage retention after
runtime failure. Current commands/results are in SEMANTIC-EVIDENCE.md. They are
expected semantic observations; current native tests qualify source admission
only. The owner subsequently confirmed rejection of provable faults, including
known final overflow in ordinary assignments, and required literal-only integer
arithmetic to reduce to a typed constant during compilation. Runtime-dependent
faults retain the existing Err rules. The updated evidence records definition
checks and frontend admission separately from unimplemented semantic behavior.

## Semantic contract prepared for review - 2026-11-01

The owner requested completion of the next-step preparation goal. The concrete
proposal is `SEMANTIC-CONTRACT.md`; `SEMANTIC-SYNTAX-INVENTORY.md` documents what
the current parser retains and what it discards. Independent targeted expected
facts, exact witnesses, source evidence and future native obligations are under
`tests/semantic/`. `SEMANTIC-EVIDENCE.md` records exact commands, outcomes,
identities, review checklist and limitations. No production source was changed.

The owner confirmed contextual unsuffixed decimal integer typing, including
destination propagation through arithmetic; otherwise use Long then LongLong.
The normative specification/conversion table and specified public manual now
record that rule. The proposal enumerates the first integer contexts and the
remaining deferred boundaries rather than inheriting bootstrap behavior.

Review this contract before implementation. The immediate technical dependency
is extending the existing parser's declaration detail publication, preserving
all previous syntax projections and failure/budget gates. Semantic representation
and lookup probes follow that qualification; no new parser, executor or phase
architecture is selected. The actual semantic checker/backend remains absent.

## Consolidated bootstrap runtime - 2026-11-01

The owner requested that bootstrap-native support be kept in the bootstrap
folder. The former root `runtime/` files now live in `bootstrap/runtime/`:
`bootstrap_runtime.c`, `bootstrap_unicode_runtime.cpp` and `value_storage.h`.
The former UBECore C adapters now live in `bootstrap/runtime/windows/`:
`file_primitives.c` and `thread_primitives.c`. The old directories are gone;
UBECore's production source tree contains UBE. Future UBE platform libraries
remain library work; this move changes no public API or language behavior.

Build/test paths, native includes, parent input inventory and current guidance
are updated. All 24 relocated v3 UBE files retain their original bytes. A focused
review passes 96 checks, including syntax of 32 edited PowerShell scripts and
byte-identical before/current preprocessed C runtime. The historical before-fix
regression mode keeps its pinned snapshot's original path layout.

Current source cohort: `2c0fb05a3c4b4912861db33043acdb40`, manifest SHA-256
`2D6B6082C7647DE7D380BEB35C1FAFB057A312F6056C0A9D552CC7E540772D51`.
`rtk proxy powershell -NoProfile -File bootstrap/build-v2.ps1`: PASS, 785 source
acceptance assertions. Subsequent strict maintained gates all pass:

- `compiler/UBE_Compiler_v3/tools/check-parser-cli.ps1`: 104 exact process cases
  plus all diagnostic controls; both stages' production LLVM is identical to
  the qualified pre-runtime-relocation CLI.
- `compiler/UBE_Compiler_v3/tools/check-local-cli.ps1 -CliReport <source CLI report>`:
  all 52 exact process oracles with the qualified stage-two executable.
- `compiler/UBE_Compiler_v3/tools/check-project-cli.ps1`: all 1202 assertions.
- `compiler/UBE_Compiler_v3/tools/check-borrowed-lifetimes.ps1`: all 56 native
  runs and its negative unowned-watch control.

These commands use `rtk proxy powershell -NoProfile -File`. Complete command
records, logs, report identities, exact path-edit backups and preprocessing
comparisons are in
`bootstrap/out/runtime-relocation/9ab2b6bb253e4e17b0c042b88d2db589/`.
The report paths are:

- `bootstrap/out/parser-cli/8223b27728b84529adda41b9a0f95a45/report.json`
- `bootstrap/out/local-cli/6b912f000fbf4ae5a1d3ec9483ee6a73/report.json`
- `bootstrap/out/project-cli/16e952bc59c0419bb1273537692876e7/report.json`
- `bootstrap/out/borrowed-lifetimes/da0f3f17d9604a868f9e868b2965379f/report.json`

Earlier source-layout and frontend/performance records below retain their own
cohorts and original paths. No performance measurement was rerun for these
filesystem corrections. The accepted initial parallel results and next proposed
semantic-checking contract remain unchanged. No push is authorized.

## Qualified source-folder layout - 2026-11-01

The owner requested filesystem separation of code from plans and definitions.
All 24 production modules/classes now live under `src/`; the project file stays
at the v3 root with the same source order and `src/` entries. Plans, contracts,
evidence and contributor guidance retain their locations. Tests/tools remain
separate. Every moved source file is byte-identical; active tool and CLI-oracle
paths are updated. No production names or behavior changed.

Fresh qualification:

- `rtk proxy powershell -NoProfile -File bootstrap/build-v2.ps1`: PASS, all 785
  source acceptance assertions. Current cohort `47d728ea15684fdd8639e444709df30b`;
  manifest SHA-256 `2AFF9EA62482FDED74F21A64AC81A6885A2230F67678409A199151D948C6AF57`.
- `check-parser-cli.ps1`: PASS, 104 exact source CLI processes and all diagnostic
  controls. Both stages' production LLVM is byte-identical to the accepted
  pre-relocation CLI, as well as to each other.
- `check-local-cli.ps1 -CliReport <new source CLI report>`: PASS, all 52 process
  oracles using the qualified stage-two executable.
- `check-project-cli.ps1`: PASS, all 1202 project CLI assertions.
- Focused relocation review: PASS, 122 checks of source hashes, exact path-only
  reference edits, manifest entries and syntax of all 36 PowerShell scripts.
- `rtk proxy git -c core.safecrlf=false diff --check`: PASS.

Commands above use `rtk proxy powershell -NoProfile -File` and the maintained
scripts under `compiler/UBE_Compiler_v3/tools/`. Complete relocation identities,
before-edit copies, command records and reports are retained under
`bootstrap/out/v3-source-relocation/49d3aecd4aa44286a1fecc4130338eb5/`.
Earlier a732 full frontend/performance qualification below remains the original
accepted record. Performance was not remeasured for this byte-preserving move;
no new speedup result is claimed. The next proposed semantic contract is unchanged.

## Completed project/frontend objective

The owner-requested bounded project input and qualified parallel frontend is
complete under the revised initial-performance criterion. Cohort
`a732173e4f3d450cb7a6feaa519af1d3` passes785 source assertions and all seven
strict retained gates. The project/jobs path uses the existing compiler-owned
`TryParseSources` budget, immutable owners/private outputs, deterministic spans
and failures, complete publication, cancellation/drain and old-output retention.
UBECore retains generic facilities without compiler source policy or an executor.

The current project consumer proof covers35 cases, four independent contexts and
375 observed allocator failures. The optional physical case-sensitive36th case
is historical, not part of this current qualification. Parser1769 checks retain
all188 cases and every capacity0..58/200/206/207 through both stages (1350
attempts). Source CLI104 exact processes and58 diagnostic controls, local52,
project CLI1202, lifetime56 and concurrency4200 assertions per stage pass.

Both complete uninstrumented sessions retain252 trials and pass all serial/small
guards. Real-corpus two/four-worker speedups are1.207x/1.304x and1.211x/1.335x;
balanced gains are1.279x/1.396x and1.288x/1.423x. All parallel trial ranges are
faster than serial, and four workers improve over two. The original1.5x/2x
targets remain missed; the owner explicitly accepted close initial results.
The frozen harness/reports and both baselines remain unchanged. See
[current acceptance policy](PERFORMANCE-ACCEPTANCE.md) and
[performance evidence](FRONTEND-PERFORMANCE-EVIDENCE.md) for the decision,
archive, exact identities, distributions, resource costs and remaining limits.

Applied changes are the conservative unused-argument-slot correction, the
approved address-owned root registry with collection gating/fallback, and the
existing coordinator's1ms wait. No spelling cache, scalar-read fusion, private
procedure aggregation, second executor or public ABI change was adopted.
The32-byte root ABI/global1,048,576 capacity and real failure coverage remain.

Full grammar, semantic validation and native code generation remain unfinished.
Successful syntax checks return the explicit semantic-unavailable diagnostic
and create no output artifact. Later rows remain proposed until their bounded
contracts/dependencies and owner review are ready. No further push was authorized.

## Earlier foundation and parser checkpoints

Completed: implement and independently qualify the bounded production grammar
consumer in `PARSER-CONTRACT.md`. Private linked-child storage, explicit expression
and control continuations, borrowed input, atomic publication and source admission
are integrated into the production manifest/CLI. `PARSER-IMPLEMENTATION.md` records
their boundary; `PARSER-NATIVE-EVIDENCE.md` records exact commands and identities.
The refreshed bootstrap passes 501 checks; the unrestricted native gate passes
4049 grouped checks through both stages, including all 188 syntax/reject/deferred
cases, 10412 actual root capacities, persistent allocator denial, complete old
result/source retention, cleanup, private workers and 102 measured cost rows.
Both raw native-test LLVM images are byte-identical. A failed harness run remains
historical; the corrected complete rerun repeats every stage and root capacity.

The strict CLI gate passed 82 exact process cases and 54 diagnostic controls,
including all 16 then-existing compiler/UBECore modules, with identical raw LLVM through
both source-built stages. The rebuilt local executable passed the same 41 process
oracles. New diagnostics recover without runtime allocation. The owner approved
correcting two ordinary-call fixtures from reserved `text` to `s`; no language
rule changed. Reserved `Width` declarations were narrowly renamed `ScalarWidth`.

Completed: focused native parser representation/traversal probes. Both accepted
source-built stages pass 3828 assertions; linked-child storage and explicit
stacks are selected for the first bounded consumer. A persistent-allocation
regression required a focused recoverable-GC/first-error runtime correction;
that fresh source gate passed all 501 grouped checks. Its exact identities,
measurements, tradeoffs and next production action are in
`PARSER-PROBE-EVIDENCE.md`. This is historical prerequisite evidence; current
production implementation and qualification are recorded above.

Completed: define the first grammar consumer before choosing parser representation
or implementing it. `PARSER-CONTRACT.md` and 116 manually authored cases pass
11969 new consistency assertions and 16 negative controls. Syntax grouping,
original spans, diagnostics, later semantic obligations and deferred families
remain distinct. `PARSER-EVIDENCE.md` records exact inputs/report hashes, review
corrections, limits and the then-next focused native probes. It describes the
definition before production implementation.

That earlier definition gate separately audited all 2308 recorded accepted identities
unchanged, preserving the existing 501-check native qualification and all 13 child
proofs. It did not rerun native behavior. Exact scanner commands, accepted hashes,
measurements and supported limits remain in `SCANNER-EVIDENCE.md`; the earlier
470-check result remains historical in `SOURCE-INPUT-EVIDENCE.md`.

## Earlier source/header state

The production manifest adds `SourceOwner.cls`, `SourceWork.cls`,
`SourceCancellation.cls` and `SourceParsing.bas` to the existing source,
scanner, bounded parser and CLI modules. Compiler-owned source/work objects
retain original bytes, tokens and private syntax. They consume actual UBECore
source references and its generic fresh-status Threads APIs.

The local `bootstrap/out/v3/ube.exe` is byte-identical to the qualified
stage-two CLI artifact and passes all 41 exact process oracles. It accepts one
`--check` source, syntax-consumes the bounded native MODULE grammar and defers
other envelopes, then reports semantic checking unavailable with nonzero
status. This is not a public release or project/jobs CLI support.

`../archived/` holds the previous v3/v4 trees, release previews and compiler
handoff documents. Exact pre-archive working-tree bytes are retained separately
from recorded relocation-only script/metadata changes.

The fresh UBECore remains in `../../std-lib/`. Its inventory is documentary
scope with open API/compatibility decisions. The VB6 bootstrap-port idea stays
deferred. No old compiler's phase model or verification claim is inherited.

## Earlier setup and foundation evidence

The archive/setup gate checks original and relocated file hashes, allowed text
replacements, manifests, preview hashes and PowerShell syntax. The inventory
gate checks named coverage and document structure. These gates do not compile
the new compiler, establish bootstrap fitness or prove runtime behavior.

`rtk proxy powershell -NoProfile -File compiler/archived/verify.ps1` passed
367 original/archived file checks, 13 recorded relocation-only changes,
nine preview hashes, 28 library archive files, six manifests/132 inputs and
21 script syntax/root checks. `std-lib/tools/check-inventory.ps1` passed its
175 reference names and 73 historical hooks. Those checks remain structural.

The owner explicitly requested and started the first foundation goal on
2026-10-30. `../../std-lib/FOUNDATION.md` now defines the primitive/type ledger,
independent target obligations and a finite native-type proposal requiring
review before syntax or production implementation changes.

`rtk proxy powershell -NoProfile -File std-lib/tools/check-foundation.ps1`
built the current small seed/runtime and ran 33 checks against that seed and
two restored v2 artifacts. All 18 bounded-subset checks passed; six target
probes passed and nine failed. Byte is unsupported in all three tools; v2
Integer storage is i32; seed ByVal records are unsupported; bootstrap String
construction rejects zero. Neither route is qualified for the intended native
datatype/byte-text library yet. Restored executables match their backup manifest
but current v2/C runtime sources do not match its input hashes. Full procedure,
exact identities and limitations: `../../std-lib/FOUNDATION-EVIDENCE.md`.

The owner's subsequent usable-v2 goal is complete for the explicitly bounded
bootstrap contract. `bootstrap/build-v2.ps1` builds the current seed/runtime
and both v2 stages without backup executables, checks the LLVM fixed point and
passes 130 assertions. Byte/Integer storage, conversions, scalar record copies,
compact arrays, rejection and crash regressions are covered. Unsupported deep
value copies diagnose; long expressions now receive a depth-limit error. Use
`../UBE_Compiler_v2/FOUNDATION-VERIFICATION.md` for the current identities,
commands and limits. The initial failed-probe report remains historical evidence.

## Earlier native-value and byte/text checkpoints

Completed: the owner delegated syntax/ABI decisions with VB6 conventions
preferred where compatible. `../../std-lib/NATIVE-TYPE-PROPOSAL.md` now records
the adopted opaque scalar mechanism. Source-built v2 implements Byte/Integer/
Long-backed nominal values, synthesized zero/copy, explicit Pack/Unpack binding
and equality. Bindings must originate in the type's declaring source module.
That earlier native-value gate passed 204 assertions: 130 core,
66 native-value and eight ordinary-record checks. Test-only layout/entry
adapters preserve all production UBE bodies and type definitions. Exact
identities, commands, regressions and limits are in
`../../std-lib/tests/native-type/NATIVE-EVIDENCE.md`.

The subsequent owner-approved managed extension now supports ordinary array/
record value copies, precise roots, results, borrowing and failure-atomic storage.
The ordinary UBE decoder and ByteBuffer bodies pass the combined maintained
source gate: 296 assertions, including self-compilation fixed point, managed
failure/cleanup and library functional/cost/concurrency gates. Independent
allocator/copy instrumentation covers ten input sizes through both stages;
four native workers share immutable input with private mutable instances.
Exact identities, commands, observations and limits for that checkpoint are in
`../../std-lib/BYTE-BUFFER-EVIDENCE.md`. Initial failed storage probes remain
historical evidence. At that checkpoint, the full Library/native envelope, builtin String, UBE
CallNew scheduling and complete language were unqualified. That record preserves
the foundation before later source-input and concurrency work.

## Active next action

Prepare the existing First checked native executable deliverable's bounded
contract review: included/deferred programs, lowering from the checked result,
target ABI/native values, runtime errors, LLVM validation and tool/cancellation/
publication failures preserving an old artifact. Author independent native and
failure expectations before implementation. Reuse qualified source owners,
generic library facilities, private results and the shared worker budget.
This does not reopen semantic rules or introduce a new compiler generation,
phase interface, executor, commit or push.