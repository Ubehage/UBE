# Compiler development handoff

## Current work

Fresh UBECore and UBE Compiler v3 foundations, following the owner's approval
on 2026-10-30. Detailed state is in `UBE_Compiler_v3/Progress.md` and
`../std-lib/ROADMAP.md`.

The previous v3/v4 source, tests, instructions and plans are under `archived/`.
Their previews and old compiler-wide handoffs are archived too. The archive
location is `compiler/archived/`; no separate boot directory remains.

Fresh v3 now has its first source-ingestion consumer and production manifest.
It consumes actual UBECore source references and preserves exact byte snapshots
with strict UTF-8/newline validation and separate scalar positions.
The shared foundation contract is in
`../std-lib/FOUNDATION.md`. The owner-requested source-built v2 tool now passes
501 grouped acceptance assertions, including its LLVM fixed point, native byte/scalar
programs and focused failure regressions; see
`UBE_Compiler_v2/FOUNDATION-VERIFICATION.md`. Use `bootstrap/build-v2.ps1`, not
the historical full archived-compiler build. The adopted opaque native scalar
mechanism is proved in `../std-lib/tests/native-type/NATIVE-EVIDENCE.md`.
The owner approved managed storage and permits extending v2 as necessary for
bootstrap. Managed copies/roots/results and the ordinary UBE ByteBuffer/decoder
now pass native behavior, failure, cleanup, cost and concurrent-instance checks.
Current commands, identities, scanner/Unicode/failure/cost results and limits are
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
all 501 checks. Current evidence is `UBE_Compiler_v3/PARSER-NATIVE-EVIDENCE.md`.
No successor implementation item is selected; agree the next bounded contract
before further compiler or library expansion.

Historical handoff and test logs remain in
`archived/compiler-history/Progress.md`. Current structural verification is
recorded with the archive and library workplans; it does not establish runtime
correctness or bootstrap fitness.
