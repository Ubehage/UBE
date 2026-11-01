# UBE Compiler v3 progress

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

## Current objective

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

The completed project/frontend deliverable has its exact source/test/measurement
record in PROJECT-INPUT-EVIDENCE.md and FRONTEND-PERFORMANCE-EVIDENCE.md. Preserve
its qualified ownership, library boundary, names, determinism and one worker budget.

The next proposed development-plan row is **First semantic checking**. Before
implementation, inventory the declaration details retained by syntax and define
the bounded scope/lookup/type/diagnostic contract with independent cases, exact
spans, failure publication and deterministic private body work. Do not guess
missing declaration information from node kinds or create another source parser.
Reusable text/numeric operations belong in UBECore; language policy stays here.
No semantic/backend code or new phase architecture is authorized by this handoff.
