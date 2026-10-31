# Bounded production parser evidence

Date: 2026-10-31. Status: **qualified for the contracted bounded consumer**.
The refreshed bootstrap passed all 501 assertions; the unrestricted native gate
passed 4049 grouped checks through both source-built stages. Strict production
CLI and published-artifact checks also passed against that exact cohort.

## Authority and implemented result

`PARSER-CONTRACT.md` defines this consumer; `PARSER-PROBE-EVIDENCE.md` records the
prior measured representation choice. `PARSER-IMPLEMENTATION.md` explains the
ownership, exact budget accounting, logical comparison and context decisions.
The frozen language specification and EBNF remain authoritative.

Four ordinary UBE modules implement the consumer:

- `SyntaxTree.bas`: private six-Long linked-child nodes, bounded shared state,
  original byte spans, direct pending construction and complete publication.
- `SyntaxExpressions.bas`: explicit precedence/postfix continuation frames.
- `SyntaxGrammar.bas`: declarations, procedures and bounded statement/control
  grammar with explicit control frames.
- `SourceSyntax.bas`: borrowed-source entry and pending-conditional admission.

The production manifest includes them and references the actual UBECore sources.
Each call owns its pending storage. Inputs are immutable borrowed views; the
caller keeps the source alive for returned spans. Exact trimming precedes a
single transactional result-array copy containing nodes, count, root and source
identity. No source payload is copied into builtin String, no probe command
stream enters production, and no source-controlled native recursion is used.
No library API, collection, scheduler or production runtime extension was needed
for this parser implementation.

## Commands and accepted bootstrap

Run from the repository root:

```powershell
rtk proxy powershell -NoProfile -File bootstrap/build-v2.ps1
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tools/check-parser.ps1 -RootJobs 2
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tools/check-parser-cli.ps1
rtk proxy powershell -NoProfile -File bootstrap/compile-v2.ps1 -Source compiler/UBE_Compiler_v3/UBE_Compiler_v3.UBE -Output bootstrap/out/v3/ube.exe
```

The first command passed all **501 grouped acceptance assertions**, comprising
136 core checks and all 13 child proofs. It built the seed, runtime and both v2
stages from current source, retained the byte-identical v2 LLVM fixed point,
and published the selection only after every child and final identity audit
passed. No restored or archived compiler executable is required.

Accepted run: `bootstrap/out/v2/e4cccaa2e5d54163866f2ca3853935d2/`.

| Artifact | SHA-256 |
| --- | --- |
| `manifest.json` (687284 bytes) | `A85116D74DD8DCD2908144F00FF477D325503CDFD307006A9EC4ACD2C1000A9B` |
| `ube-stage2-v2.exe` | `BC60B359F6FA14D78FFCF66A0DB2199CB3C6E003A896DAAE34D24EF932D7C806` |
| `ubec.exe` | `D7E4E34951DE34DDE4527274B4C9359E4B55239A84A3DF0A3FA2DE602D1ADAE3` |
| `bootstrap_runtime.o` | `128D32EA5590BC2BCFB58CD48E67BA62095D3734936E1ED172C6B0AE4EA82E5C` |
| `bootstrap_unicode_runtime.o` | `AB41E49C6E1375AC878F588FF88DC7DB43A7018CAD8F3F811DE811F7C245EDFD` |

The manifest pins 318 inputs, tool identities, 89 artifacts and the 13 child
reports. These include native values, ordinary records, managed substrate and
copies, UTF-8, ByteBuffer behavior/costs, references, entry admission, file bytes,
source input, exhaustive Unicode and scanner qualification. The scanner's exact
and observed native programs respectively executed 172005 and 2274484 assertions
per stage. Their reports remain linked by the accepted manifest.

## Independent native acceptance

The corrected unrestricted command passed with `success=true`,
`qualifiedParser=true`, `diagnosticOnly=false`, no partial-suite switches and
no remaining failure. Report:
`bootstrap/out/parser/c95c630d5c37418db8a63ab3427a4dc5/report.json`, SHA-256
`A362E6B2489C9E556F6D8ED0A832899457122725B5A33FB97DB24665689DBBE7`.
Its **4049 grouped checks** include exact and observed programs through both
stages, all 188 cases, eight domain cases, 34 budget cases, 17 admission controls,
private workers, persistent allocation faults, actual roots, measurements,
negative controls and final unchanged-input/baseline audits. All 2355 recorded
baseline identities remained unchanged. Both original native-test LLVM images
are 4252339 bytes, SHA-256
`15A7B56CFCD3089B23C3AD6AC05F31A0357F9416FB2CA2C298CAFA8E5A07747C`.

Each stage exercised 63 persistent allocator-failure boundaries across all four
actors. Both KIND and SPAN comparison controls rejected deliberate corruption;
each stage's four mutated measurement controls also failed as required. Every
native suite asserted its cleanup and complete source/old-output obligations.

| Real-root actor | Inclusive capacities per stage | Ranges per stage | Attempts per stage |
| --- | --- | --- | --- |
| Expression | 0..499 | 32 | 500 |
| Nested With statement | 0..1298 | 82 | 1299 |
| Complex native MODULE | 0..1698 | 107 | 1699 |
| Source-wrapper MODULE | 0..1707 | 107 | 1708 |

All **10412 capacities** across 656 ranges passed with real backed roots,
endpoint success, gap-free coverage, retained old/current inputs and cleanup.

### Retained failed harness run

The initial unrestricted native gate in
`bootstrap/out/parser/855f603758c649349134930321349ad5/` passed the first stage's
exact and observed suites, 51 cost rows and all real-root capacities for the four
actors (0..499, 0..1298, 0..1698 and 0..1707). It then stopped because PowerShell
split the negative-control Clang define into two arguments. No production parser
assertion failed. Its report correctly has `qualifiedParser=false`; neither it
nor earlier diagnostic-only captures substitutes for the successful complete rerun.
The correction parenthesizes that single define expression. A synthetic
before/after argument-vector assertion reproduces the split and proves the fix.
A second narrow harness correction enforces the originally documented
`64*(tokens+publishedNodes+1)` work bound instead of counting discarded validation
nodes in that term; all 51 captured first-stage rows pass the stricter comparison.
The preserved partial report has SHA-256
`DC97BCB8158C02F857EDEFC2D643B9C9592C761DB92708FC3EBC1316C95A2F7F`.
The corrected full run repeated both stages and all ranges without reusing the
partial root sweep.

The maintained gate consumes **188 independent cases**: the original 116 frozen
cases plus 72 focused controls (114 syntax, 52 rejection and 22 deferred outcomes).
These cover exact grouping, complete original
spans, first diagnostics, semantic obligations admitted by syntax and explicit
deferred families. The comparator validates the complete graph for bounds,
reachability, ordering, sharing and cycles before comparing the logical witness.
Only an explicitly opaque leaf Header omits its unspecified internal detail;
all actual nodes remain subject to graph validation. Expected trees are not
generated from production output. Deliberate KIND and SPAN errors must be rejected.

Seventeen source-admission controls distinguish pending conditionals from raw
lexical errors, inactive malformed quotes/attributes, ordinary date/file hashes,
comments, bracketed names and unsupported envelopes. Domain and resource suites
exercise fresh status, node/pending/depth limits and complete old-result retention.
Four private native workers each repeat three exact graph samples 12 times over
shared immutable inputs. These are tests of independent instances, not a UBE
compiler worker scheduler.

Persistent allocator denial covers every measured runtime malloc/calloc/realloc
boundary for expression, nested-With statement, complex module and source-wrapper
entries. The real-root gate fills the production 1048576-record registry with
backed roots and tests every available capacity from zero through each actor's
measured successful requirement. Each failure must retain the entire old wrapper,
node payload and source identity, the current and old sources and token snapshots;
Err7, root counts, live payload and cleanup have explicit assertions.

The sweep uses two concurrent test processes and inclusive ranges of at most 16
capacities. The final gate sorts their union and rejects omissions, duplicates
or overlaps; splitting processes reduces test duration without reducing coverage.
The existing runtime's absent-root cleanup scans the million-record registry.
Its pressure-test cost is separate from normal parser work; no runtime redesign
was introduced to speed the gate.

## Work, copying and budgets

The predefined 51 cost samples cover increasing flat expressions, wide calls and
module lines through 16384 elements; mixed precedence; 255/256/257 groups, prefixes,
right powers and If/While/With nesting; and large opaque initializers, optional
defaults and array bounds. Parser-only observations exclude source construction,
scanning, admission and C oracle work.

Actual runtime and generated-code observers count token-record reads, node writes,
reads/links/attachments, frame pushes, workspace growth, allocations, requested
zero initialization, payload copies and stored root counts. A real 17-byte copy
control must produce a nonzero copy observation; four deliberately corrupted
measurement reports must fail their checks.

Required bounds, fixed before final qualification, are zero source payload copies,
token reads at most `64*(T+1)`, grammar/state actions at most `64*(T+N+1)`, geometric
workspace copies, pending-node growth at most `2*24*M+8*24`, exact trim `24*N`,
and complete publication `24*N+12`. Here M is the maximum simultaneously live
pending-node count, including discarded opaque validation detail, and N is the
published node count. Combined output copying is at most
`2*24*M+2*24*N+64+8*24`. Pure expression construction has M=N and writes each node
once. Spelling/Unicode comparisons and byte acquisitions are reported separately.
Requested zero bytes do not claim physical writes; process memory includes the
test harness and retained source/old-output fixtures.

All **102 observed rows** (51 per stage) passed these bounds, including the
stronger published-N work assertion. Representative 16384-element results are
identical through both stages:

| Input | Tokens | Published N | Maximum live M | Token reads | Actions | Node growth copies | Trim | Publication |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Flat expression | 32769 | 32767 | 32767 | 32769 | 180220 | 786240 | 786408 | 786420 |
| Wide call | 32772 | 16386 | 16386 | 32772 | 163851 | 786240 | 393264 | 393276 |
| Module lines | 65563 | 32776 | 32776 | 65563 | 278571 | 1572672 | 786624 | 786636 |
| Opaque initializer | 32795 | 3 | 32770 | 32795 | 180252 | 1572672 | 72 | 84 |
| Optional default | 32806 | 9 | 32774 | 32806 | 180277 | 1572672 | 216 | 228 |

Copy columns are actual bytes. Every row reports zero source-payload copies.
The large initializer requests 3148792 allocation/zero bytes across 20 allocations;
the flat expression requests 3148456 across 19. A source module with 16384 lines
uses 16404 allocations because independent expression workspace is prepared for
each statement; the report measures those instances rather than hiding them in
one maximum. Name/Unicode comparison-call counts, byte acquisitions, workspace,
root storage and retained payload remain separate report fields.

## Production CLI and crash regression

The unrestricted CLI command passed: `qualified=true`, `diagnosticOnly=false`,
**82 exact process cases**, **54 diagnostic controls** and **217 assertions**.
It syntax-consumes all 16 current compiler/UBECore source modules as well as the
22 independent CLI fixtures and usage/missing-file controls through both stages.
Exact exit/stdout/stderr checks preserve source, scanner, envelope, deferred,
syntax and still-unavailable semantic-check dispositions. BOM/CRLF/Deseret cases
pin original byte positions separately from scalar coordinates.

Report: `bootstrap/out/parser-cli/940e28be7373427faf501085c9296cf1/report.json`.
SHA-256: `3F7F08BE3D54B929F56FFD124AB07A603A5EF0FEE81786702DB6ECEEED8C47B3`.
Both raw production LLVM images are 4371074 bytes, SHA-256
`9D488DC09770DD705C565FD15643625D1CC54D3FCEB89FB3273E354300C3ABBF`.
Accepted-input preaudit and final source/tool/fixture/artifact audits passed.
Native executable byte identity is not claimed; PE metadata may differ.

The maintained compile helper successfully refreshed `bootstrap/out/v3/ube.exe`.
Its compile record is
`bootstrap/out/v2/compilations/48ff0830bfcf444583b85382d99b65dc/compile.json`,
SHA-256 `908C54AECF3CF02B87CA84338F98DD0F41ECBCB6922FF92A2EE32DA9CE102121`.
Its `program.ll` equals both qualified production LLVM images. The published
executable is 681984 bytes, SHA-256
`BCF34714F41B5227DB1B5A035597E4345E4F6F96E25B58768BA74C0750AFAA4E`.
`rtk proxy powershell -NoProfile -File bootstrap/out/check-published-parser.ps1`
then ran the same 41 independent exact process oracles against that executable
(22 fixtures, 16 real modules, three usage/missing cases), with accepted input,
tool, fixture and executable identity audits before and after. All passed.
Capture: `bootstrap/out/parser-published/dea8398a8c95451ba5b32413506cfab0/report.json`,
SHA-256 `2601C83D65CC7E0F5331B2840D7F0CE976A83FF0725F35471D2F6BB32279E3B4`.
The maintained CLI gate reproduces the process oracles; this additional generated
runner records the specific local artifact handoff.

A focused synthetic test exposed a crash in the initially integrated diagnostic
formatter: String conversion/concatenation while reporting storage or syntax
failure exited 70 after the first denied runtime allocation. Checked-in historical
captures in `tests/parser/cli/diagnostic-oom/` pin that pre-fix behavior for failure
kinds 5 and 101. The correction prints an immutable header followed by numeric
line, column and byte values, with a rootless static storage-failure fallback.
It does not change general String or allocator behavior.

Each stage's maintained regression invokes the intact actual UBE helper/fallback
bodies and full runtime through checked native wrappers. Eleven failure kinds,
the unknown-kind default and invalid-position fallback run both normally and
under persistent allocation denial; a separate full-registry case forces actual
root admission failure. All 27 controls per stage passed exact output, unchanged
inputs/Err, fresh failure status and cleanup assertions, with **zero runtime
malloc/calloc/realloc attempts**. This does not claim zero CRT or OS allocations.

Child report SHA-256 values:
`93D045BEE9BE167157097DAADA1D796932C476761EEE886A715B169C19567F83` and
`5CAC1E9FDF9CB5D6629077D3AE26CC46C24D5950CF256A1146984D5A0129554A`.

## Focused compatibility corrections and limits

The owner explicitly approved replacing reserved `text` with `s` in the two
ordinary-call fixtures `Mid$(s,2)` and `Len(s)`. Their identities, logical shapes,
rule references and intent are unchanged. `Text` remains reserved. Existing
compiler/cursor identifiers named reserved `Width` were narrowly renamed
`ScalarWidth`; no scanner rule or public calling layout changed. The earlier
source-input CLI Unicode fixture now uses a structurally valid typed procedure
while preserving its path/BOM/CRLF/scalar-position obligations.

This is the contracted first native MODULE grammar consumer and diagnostic
fragment entries, not the complete frozen language. Date candidates retain
syntax/spans without calendar conversion; ambiguous suffix/operator roles and
other contracted deferred families remain deferred. Conditional preflight only
detects pending selection; it does not select branches or validate inactive text.
Successful syntax still reports UBE1012, checking unavailable, with nonzero exit.
Binding, types, literal conversion, semantic checking, code generation, general
builtin String and full Library packaging remain outside this qualification.

Archive verification also passed: 367 original/archived files, 13 permitted
relocations, nine preview hashes, 28 prior-library files, seven manifests with
148 resolved inputs and 21 script checks. This is structural evidence only.
Every procedure in the four new modules passed the leading-comment audit, and
tracked changes passed `rtk proxy git -c core.safecrlf=false diff --check`.

The final read-only handoff procedure
`rtk proxy powershell -NoProfile -File bootstrap/out/audit-parser-completion.ps1`
passed 2041 assertions. It checked unrestricted qualification flags, exact suite
counts, all 102 final-N work bounds, every root range, both diagnostic regressions,
production LLVM identity and current source/tool/artifact/report identities.
Its capture is `bootstrap/out/parser-completion-audit.json`.

No successor implementation item is selected by this consumer. Continue from
the fresh roadmap and agree the next bounded contract before expanding scope.
