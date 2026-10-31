# UBE Compiler v3 progress

## Current objective

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
including all 16 current compiler/UBECore modules, with identical raw LLVM through
both source-built stages. The rebuilt local executable passed the same 41 process
oracles. New diagnostics recover without runtime allocation. The owner approved
correcting two ordinary-call fixtures from reserved `text` to `s`; no language
rule changed. Reserved `Width` declarations were narrowly renamed `ScalarWidth`.

Completed: focused native parser representation/traversal probes. Both accepted
source-built stages pass 3828 assertions; linked-child storage and explicit
stacks are selected for the first bounded consumer. A persistent-allocation
regression required a focused recoverable-GC/first-error runtime correction;
the fresh source gate passes all 501 grouped checks. Exact current identities,
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

The production manifest contains `Main.bas`, `SourceInput.bas`, `SourceFile.bas`,
`ScannerWords.bas`, `SourceScanner.bas`, `SourceEnvelope.bas`, `SyntaxTree.bas`,
`SyntaxExpressions.bas`, `SyntaxGrammar.bas` and `SourceSyntax.bas`, consuming actual
UBECore source references. Unicode/cursor helpers are ordinary UBE library code
over pinned official data. Tokens borrow original source spans; private pending
arrays publish failure-atomically. Root-pressure tests exposed and fixed a neutral
scalar result being mistaken for a source character. The real-root regression
now passes five lexical families and native envelopes through both stages.
The helper builds `bootstrap/out/v3/ube.exe`; it syntax-consumes the bounded native
MODULE grammar and defers other envelopes, then reports checking unavailable
with nonzero status.
It is not a public compiler release.
`../archived/` holds the previous v3/v4 trees, release previews and compiler
handoff documents. Exact pre-archive working-tree bytes are retained separately
from recorded relocation-only script/metadata changes.

The fresh UBECore remains in `../../std-lib/`. Its inventory is documentary
scope with open API/compatibility decisions. The VB6 bootstrap-port idea stays
deferred. No old compiler's phase model or verification claim is inherited.

## Evidence and limits

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

## Current foundation result

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
Current exact identities, commands, observations and limits are in
`../../std-lib/BYTE-BUFFER-EVIDENCE.md`. Initial failed storage probes remain
historical evidence. The full Library/native envelope, builtin String, UBE
CallNew scheduling and complete language remain unqualified. That record describes
the completed foundation before the current source-input goal.

## Next action

The bounded grammar consumer and current-source qualification are complete.
Agree the next bounded contract and independent cases before expanding compiler
or library scope; this checklist selects no successor implementation. Preserve
the maintained native/CLI commands and qualified local artifact documented in
`PARSER-NATIVE-EVIDENCE.md`. Conditional selection, semantic validation, literal
conversion, deferred grammar and code generation remain outside this slice.
Add library facilities only for a demonstrated need.
