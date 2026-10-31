# UBE Compiler v3 progress

## Current objective

The owner-requested bounded compiler-concurrency objective is complete.
`CONCURRENCY-CONTRACT.md`, `CONCURRENCY-BOOTSTRAP.md` and
`CONCURRENCY-CONSUMER.md` define the accepted scope. Compiler-owned
`TryParseSources` runs existing source/scanner/parser bodies through actual UBE
workers with budgets 1, 2 and 4, immutable source owners, private results,
canonical diagnostics and complete publication. Failure/cancellation retains
earlier output and drains admitted workers. UBECore owns generic thread/storage
APIs, not this source policy or an executor.

The current bootstrap passes 592 grouped assertions; concurrency passes 5652
native assertions through both stages. Retained parser and strict CLI gates pass
4049 and 217 checks; all 41 local process oracles pass. Exact current tool/source/
artifact identities, commands, costs and limits are in
[CONCURRENCY-EVIDENCE.md](CONCURRENCY-EVIDENCE.md).

Instrumented four-worker execution was slower than one-worker execution;
measured collector contention remains focused follow-up work. The proposed next
deliverable is bounded `.UBE`/direct-UBECore input and parallel frontend
integration. That row and all later rows need their own contract and owner
review before implementation. Full grammar, semantics, code generation and
project/jobs CLI integration remain unfinished.

The owner subsequently approved an explicit
[parallel performance gate](../../project-docs/Development-Plan.md#parallel-performance-acceptance).
Its initial targets are 1.5x speedup with two workers and 2x with four, measured
without instrumentation on both representative real and larger balanced corpora.
Single-worker/small-input regression guards and all correctness/resource gates
also apply. This requirement is unfinished and must pass before substantial
semantic/backend growth. The next performance work must freeze its baseline and
measurement procedure and diagnose contention narrowly; no optimization goal or
architectural change has been started by this planning approval.

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

## Current state

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

## Proposed next action

Review a bounded normal `.UBE`/direct-UBECore source-input contract and its
parallel frontend integration under
[`Development-Plan.md`](../../project-docs/Development-Plan.md). Preserve the
qualified worker path, original value semantics, names and layer boundaries.
Investigate measured collector contention with focused evidence. This row and
every later deliverable remain proposed; the completed goal does not authorize
successor implementation, semantic/backend growth or a general executor.
