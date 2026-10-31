# Native scanner oracles

The active roadmap item is implementation of `SCANNER-CONTRACT.md`. The native
gate compiles intact production modules with their real UBECore source Reference
through both selected source-built v2 stages. Test-only LLVM adapters pin exact
callee signatures and record layouts before adding C entry points. The resulting
raw production LLVM must be byte-identical. Production source hashes are checked
before and after the proof.

`oracles.ps1` translates the existing 62 hand-authored token partitions and 40
envelope outcomes to static C constants. `regressions.json` adds focused Rem,
qualified-attribute/logical-line and source-identity cases without changing the
original fixtures.
It does not recognize token boundaries.
Coordinates are independent prefix recounts over UTF-16 scalar pairs with strict
UTF-8 encoding, initial-BOM exclusion, CRLF scalar accounting and one-based
line/column values. Every byte split passes through actual SourceInput before
the native scanner/envelope calls. All 174 word roles are independently tested
after `x.` so Rem cannot consume the rest of a statement. Contextual words remain
Identifiers; reserved words remain Keywords even after member punctuation.

Token comparisons cover every kind and original start/end coordinate, including
trivia, BOM, zero bytes and synthetic terminal records. Invalid token vectors
compare their first hand-authored diagnostic and preserve the old token array.
Envelope results compare format, native kind, identity presence and exact quoted
identity view; diagnostic comparisons cover both complete positions. All
metadata witness bytes remain available in the immutable source. No cooked
String identity, Date conversion, parser acceptance or branch evaluation is
claimed by these checks.

The budgets below are fixed by the existing contract before collecting results:

| Measurement | Acceptance |
|---|---|
| Source payload copied while scanning | zero bytes |
| Executed FeedUtf8Byte calls | at most twice source byte count |
| Capacity | starts at 8, doubles; T<=C<2T beyond 8 |
| Growth payload copying | strictly below 2 * 36 * T |
| Exact publication copying | at most 2 * 36 * T |
| Combined growth/publication copying | strictly below 4 * 36 * T |

The 36-byte stride is checked against emitted production LLVM and the native C
layout. Runtime payload-copy hooks count executed leaf-copy operations, including
Byte payload copies and typed-array growth/publication. A signature-checked
wrapper around the ordinary `CopyScannerToken` procedure counts each executed
record publication copy separately; no count is synthesized from T. Rootless
field initialization and padding are excluded from payload-copy counts. Record
growth wrappers observe successful capacity requests. The `TryScannerByte` wrapper
counts only successful byte reads; Feed calls separately count actual cursor
reads. These are executed counters, not quantities inferred from source length.

Samples cover 0, 2, 31, 4096 and 16384 source bytes, with long bare names, quoted
text, comments and dense punctuation. Reports include actual allocator requests,
requested calloc initialization, managed roots/workspace, retained source and
sampled process peak working set. Requested zero bytes do not measure physical
CPU writes. Native four-worker tests join before checking collection and zero
residual roots/payloads. Each worker owns output and its Err state, while source
documents are shared immutably.

The observed executable registers the actual runtime root limit once using C
root holders, then frees one slot per attempt to sweep 0..200 remaining slots.
There is no synthetic root-count inflation and no repeated million-root setup.
Every scanner/envelope false result on its qualified valid input must report
fresh storage failure and preserve the complete previous output. A success must
match the independent result, preserve stale Err and leave the root count at
the pre-call baseline. The original scanner misdiagnosed ASCII `a=1` as an
unexpected character with 53 slots remaining; this focused regression retains
that failing boundary and the surrounding range. The same fixture also sweeps
the existing continuation, exponent/real, BOM/Unicode and doubled-quote vectors,
covering byte lookahead, match/nonmatch and numeric-end failure propagation.

The default command strictly checks the accepted source cohort and selected
artifacts. `-DiagnosticOnly` is an explicit development procedure for investigating
current source with selected exact tools while their accepted source cohort is
stale; its report always records `qualified: false`, even when checks pass. It
must never be used as release or roadmap-completion evidence.
