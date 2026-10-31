# Compiler development handoff

## Current work

The owner-requested bounded compiler-concurrency objective is complete.
Compiler-owned `TryParseSources` uses existing source/scanner/parser bodies
with budgets 1, 2 and 4, shared immutable source owners, private results and
deterministic complete publication. UBECore supplies generic Threads APIs;
source policy, task decomposition and canonical diagnostics stay in the
compiler. Field-only reference classes and bounded scalar/reference `CallNew`
captures are qualified bootstrap prerequisites, not complete class/threading
support.

The current bootstrap passes 592 grouped assertions; concurrency passes 5652
native assertions through both stages. Retained parser and strict CLI gates
pass 4049 and 217 checks; all 41 local process oracles pass. Exact current
commands, source/tool/artifact identities, costs and limits are in
[CONCURRENCY-EVIDENCE.md](UBE_Compiler_v3/CONCURRENCY-EVIDENCE.md).

Instrumented four-worker execution was slower; collector contention is explicit
follow-up work, without a speedup claim. Full grammar, semantics, code generation
and project/jobs CLI integration remain unfinished. The
[development plan](../project-docs/Development-Plan.md) proposes bounded project/
frontend input next; that row and every later row remain proposed and need their
own contract and owner review. Detailed handoff is in
`UBE_Compiler_v3/Progress.md` and `../std-lib/ROADMAP.md`.

## Earlier foundation and parser checkpoints

The previous v3/v4 source, tests, instructions and plans are under `archived/`.
Their previews and old compiler-wide handoffs are archived too. The archive
location is `compiler/archived/`; no separate boot directory remains.

Fresh v3 now has its first source-ingestion consumer and production manifest.
It consumes actual UBECore source references and preserves exact byte snapshots
with strict UTF-8/newline validation and separate scalar positions.
The shared foundation contract is in
`../std-lib/FOUNDATION.md`. The owner-requested source-built v2 tool passed
501 grouped acceptance assertions at that checkpoint, including its LLVM fixed point, native byte/scalar
programs and focused failure regressions; see
`UBE_Compiler_v2/FOUNDATION-VERIFICATION.md`. Use `bootstrap/build-v2.ps1`, not
the historical full archived-compiler build. The adopted opaque native scalar
mechanism is proved in `../std-lib/tests/native-type/NATIVE-EVIDENCE.md`.
The owner approved managed storage and permits extending v2 as necessary for
bootstrap. Managed copies/roots/results and the ordinary UBE ByteBuffer/decoder
now pass native behavior, failure, cleanup, cost and concurrent-instance checks.
Commands, identities, scanner/Unicode/failure/cost results for that checkpoint are
in `UBE_Compiler_v3/SCANNER-EVIDENCE.md`. The scanner and envelope reader pass
102 original hand-authored vectors, 12 focused regressions and 174 word roles
through both source-built stages, including real root/allocator failures,
private-worker cleanup and measured copy budgets. Unicode data and ordinary
lookup/cursor bodies pass exhaustive independent tests. The executable now parses
the bounded native MODULE grammar and defers other envelopes; successful syntax
still returns semantic checking unavailable with nonzero status. Code generation
remains later work. The first grammar consumer's definition was completed with
116 hand-authored cases and 16 negative controls pass 11969 new consistency
assertions. A separate identity audit preserves all 501 native checks without
rerunning or republishing them. `UBE_Compiler_v3/PARSER-EVIDENCE.md` records the
scope and exact results. The subsequent probes now pass 3828 assertions through
both accepted stages and select linked-child storage with explicit stacks.
`UBE_Compiler_v3/PARSER-PROBE-EVIDENCE.md` records the measured tradeoffs,
recoverable-memory bootstrap prerequisite and fresh 501-check qualification.
The production grammar consumer is now implemented and independently qualified:
4049 grouped native checks through both source-built stages, all 188 cases,
10412 real-root capacities, 102 measured cost rows, persistent allocator faults,
cleanup and private workers pass. The strict CLI gate passes 82 cases and
54 diagnostic controls; the rebuilt local executable passes 41 exact process
oracles. Both raw LLVM pairs are identical and the refreshed bootstrap passes
all 501 checks. That checkpoint is in `UBE_Compiler_v3/PARSER-NATIVE-EVIDENCE.md`.
That parser checkpoint preceded the subsequent owner-requested concurrency
objective, now completed above. Later deliverables in the development plan
remain proposed; current qualification is in `CONCURRENCY-EVIDENCE.md`.

Historical handoff and test logs remain in
`archived/compiler-history/Progress.md`. Current structural verification is
recorded with the archive and library workplans; it does not establish runtime
correctness or bootstrap fitness.
