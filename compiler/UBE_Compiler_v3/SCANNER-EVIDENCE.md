# Scanner implementation and acceptance evidence

The exact scanner snapshot below is preserved history. The later parser-probe
prerequisite corrected recoverable tracing/first-error storage and requalified
all 501 grouped checks. Current runtime/tool/output identities are in
[PARSER-PROBE-EVIDENCE.md](PARSER-PROBE-EVIDENCE.md); the scanner source and its
recognition limits remain as described here.

The active item implements `SCANNER-CONTRACT.md` in ordinary UBE using actual
UBECore source references. The full current-source gate passed **501 acceptance
checks**, including all retained foundation suites, strict Unicode qualification
and the native scanner proof through both source-built v2 stages. This completes
the scanner item within the raw-recognition limits below.

## Current qualified cohort

The accepted run is `bootstrap/out/v2/4eb76c64ed774a1a9fb38b38155b71ef/`.
It pins 273 source/test/contract inputs, including all five raw Unicode data and
provenance files, and 13 child proof reports. The full command completed in
575727 ms on this machine; that observation is not a throughput promise.

| Identity | SHA-256 |
|---|---|
| Final manifest | `5A1C0A9D2A9DA40AAAA1FC45B0AF259003AFC362572B26AC207884C607EF0726` |
| Immutable source manifest | `DB5DFA468B3F043580ABA90FA28AA28019DDC8062B3104F59473B85E3C85EF8F` |
| Selected v2 stage two | `25392B89D16B8BF80E25F53D10EA0F3407C4AECC81BEF6114FB740B5F9D43A60` |
| Runtime | `F354F653A3819161B616FDCA3B342C4CD37C68708DFE924704836116FE98C4E2` |
| Clang | `F3425B2BFF01BC401C84AF6E5E180629182FAFC2EB35CF971A3E50C9CF13F263` |
| Scanner proof report | `C3FE2FE7CF976421F4CB22A5056C8D446D0B1895C50893C5A9B773E3CB70BCF7` |
| Both raw scanner-proof LLVM files | `EC8A6C3579F8281991AB6D64EDE4FDF1D3371A94EEA806EB644025EA067515C4` |
| Both complete production LLVM files | `36209DA4B5EFC56D206C71EB604CF2003E82DC9B621BB23760F83D48F2704688` |

Scanner report: `bootstrap/out/scanner/b73f0a453eaa41fcbfd1d93a4b932550/report.json`,
with `success: true`, `qualified: true`, `diagnosticOnly: false`.
Unicode report: `bootstrap/out/unicode/12201ca30b0d49f6b763e7fa8fb87d85/report.json`;
its source/data/native details are in `../../std-lib/UNICODE-EVIDENCE.md`.
Production CLI/source-input report:
`bootstrap/out/source-input/8171044a40a6490c8874d3f0f6b3a175/report.json`, SHA-256
`E1AA14084FCB6B985864BEFEF2FB56B8B2B6CE52631B2211929AE7444AF0FF94`.

The 501 grouped checks comprise 136 core, 66 native-value, eight ordinary-record,
eight managed-substrate, 52 managed-value, eight UTF-8, 13 buffer, five buffer-cost,
91 source-reference, six entry-admission, four file-byte, 87 source-input/CLI,
eight Unicode and nine scanner checks. Each scanner stage executed 172005 native
assertions with the accepted runtime and 2274484 with the observed runtime.
These assertion counts include root-fixture setup and are not distinct programs.
Four deliberately corrupted native comparator controls rejected as required.

`rtk proxy powershell -NoProfile -File bootstrap/out/audit-scanner-implementation.ps1`
passed post-run checks of 2307 unique source/tool/report/artifact identities,
child-cohort equality, all final assertions, aggregate counts and the five pinned
Unicode inputs. The audit does not rerun native behavior. The earlier 470-check
cohort remains preserved as historical evidence rather than the current selection.

The maintained helper rebuilt `bootstrap/out/v3/ube.exe` (270336 bytes), SHA-256
`6C14B20AF2E67DF6856A616A1386ED080E3BB17774D4E09E96CA88AC02718C78`:

```powershell
rtk proxy powershell -NoProfile -File bootstrap/compile-v2.ps1 -Source compiler/UBE_Compiler_v3/UBE_Compiler_v3.UBE -Output bootstrap/out/v3/ube.exe
rtk proxy powershell -NoProfile -File bootstrap/tests/v2_usage_tests.ps1
rtk proxy powershell -NoProfile -File bootstrap/out/check-scanner-publication.ps1
```

Helper tests passed exact Byte-array execution, controlled rejection preserving
the old executable, successful replacement and changed-header identity rejection.
Report: `bootstrap/out/v2-usage/d50cced74c2e4bd9b4f4e2907a93de97/report.json`.
Publication checks passed the accepted compiler/output identities, byte-identical
qualified production LLVM and four predefined exact CLI stdout/exit/stderr
oracles. Result: `bootstrap/out/scanner-publication.json`. The helper emission
timeout is now a bounded 300 seconds for the generated lookup sources; this is
a bootstrap build bound, not a production flag or performance promise.

The current definition-only consistency command also passed 2286 assertions:
`rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tools/check-scanner-contract.ps1`.
Report: `bootstrap/out/scanner-contract/eef0d7c7e4af4141b467750bf839ca90/report.json`.
It remains separate from native behavioral qualification.

Final structural checks also passed:

- `rtk proxy powershell -NoProfile -File compiler/archived/verify.ps1`:
  367 original/archive file checks, 13 recorded relocation-only changes,
  nine preview hashes, 28 previous-library files, seven manifests/144 inputs
  and 21 historical script syntax/root checks. No archive payload changed.
- `rtk proxy powershell -NoProfile -File bootstrap/out/audit-source-handoff.ps1`:
  28 PowerShell scripts, 16 JSON files, 53 Markdown files and 147 local link
  targets; manifest containment/targets, protected instruction preservation
  and tracked `git diff --check` passed. These are structural checks, not
  additional native scanner assertions.

## Implemented boundary

`SourceScanner.bas` produces source-view token records with complete original
byte/scalar/line/column spans. It retains trivia, BOM, comments, continuations,
quoted zeroes and synthetic terminal records. Word roles come from the offline
generated `ScannerWords.bas`; Unicode Letter membership and simple C/S folding
come from ordinary UBECore functions with independently checked Unicode 18 data.
The nonreserved declaration renames are `SourcePosition.LineNumber`, the source
reader's `State` parameters/local and ByteBuffer's `KeepValues` parameter.
Their positional types, layout and existing runtime behavior are preserved.

`TryScanSource` borrows an immutable qualified SourceDocument, takes a context
and explicit record limit, and publishes an exact token array only on success.
One caller owns each mutable result. The caller retains the document for the
lifetime of its spans. A private pending array starts at eight records and
doubles; a private exact array is prepared before final failure-atomic copying.
Each token occupies 36 bytes. Fresh Boolean helper status is separate from
scalar values and existing Err. No shared cursor, worker pool or new intrinsic
implements the scanner.

`SourceEnvelope.bas` enforces native version/kind/identity metadata, recognizes
qualified attributes including spaced/bracketed targets, and preserves the
original quoted identity span. The 20-byte envelope record stores a view, not a
cooked String. Duplicate/reserved metadata and invalid native identities return
bounded diagnostics with complete original positions. Version comparison does
not overflow on arbitrarily long decimal input within the source-byte limit.

Legacy success means **family recognition and available metadata views**. It
does not establish VERSION/Object phrase validity, matched designer blocks,
legacy identity/duplicate/mixed-mode policy, or designer-root/extension agreement.
Designer payload remains in the immutable original source. No external component
is activated and no manifest reference is invented.

The production `--check` path reads/qualifies bytes, reads the envelope and scans
the core tokens of native MODULE sources. It chooses the earliest envelope or
lexical diagnostic, with lexical priority at equal positions. Other native kinds
and legacy sources receive envelope recognition only. After successful intake
it still returns UBE1012, checking unavailable, with exit 1. This executable
does not report a valid program or emit one.

Date contexts preserve candidate spelling only. Directive evidence covers raw
tokens and retained logical-line boundaries; no selected-branch evaluation,
inactive-text recovery or directive semantic acceptance is qualified. Full
parsing, literal conversion/calendar checks, binding and code generation remain
later work. Rem retains the primary specification's statement-start rule,
including after Then/Else; `_ Rem` after an expression/header is not broadened
into a comment under the EBNF's less-specific optional-comment wording.

## Independent native acceptance procedure

The maintained full command is:

```powershell
rtk proxy powershell -NoProfile -File bootstrap/build-v2.ps1
```

It rebuilds the seed/runtime and both v2 stages, checks raw LLVM fixed point,
retains the earlier foundation gates and adds strict Unicode and scanner proofs
before changing the accepted selection. Standalone scanner reproduction uses
`rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tools/check-scanner.ps1`.
The scanner script's explicit `-DiagnosticOnly` option never qualifies a build.

The native gate compiles unchanged production modules and the actual UBECore
Reference through both source-built stages. Signature/layout-checked LLVM ABI
adapters supply C entry points and executed observation hooks; original raw
production LLVM must be byte-identical. Tests compare all 62 original token
vectors, 40 original envelope vectors and 174 word roles. Five focused Rem and
seven metadata/identity regressions supplement those unchanged original fixtures.
Every byte split of the original token and envelope inputs passes through the
actual source reader. `tests/scanner/native/ORACLES.md` defines the independent
expectations and measured budgets.

Acceptance includes invalid contexts/limits, seeded Err, actual allocation
failure through growth/preparation/publication, complete old-output retention,
bounded record exhaustion, four joined native workers with private results and
shared immutable documents, and zero residual roots/live payload after cleanup.
Deliberately corrupted token-kind and byte-position controls must fail comparison.
Native C workers qualify these ordinary components, not a UBE scheduler.

## Focused root-pressure regression

A real root-admission sweep reproduced a scanner defect with just ASCII `a=1`:
with 53 remaining root slots, a nested managed helper returned neutral zero and
the scanner misreported UnexpectedCharacter (kind 1, Err 7). The retained
pre-fix repro is `bootstrap/out/scanner-root-regression/repro.exe`.
The narrow repair changes ordinary rootful byte/number/exponent/continuation
helpers to return fresh Boolean status with separate value outputs. Every failed
helper propagates Storage (kind 5); a successfully decoded NUL still diagnoses
UnexpectedCharacter.

The regression fixture registers actual root nodes to the runtime limit once,
then releases one slot per attempt through 0..200 remaining slots. It does not
inflate an internal counter. Five source families cover ASCII, continuation,
real exponent, BOM/Unicode and doubled quotes, plus a valid native envelope.
Every false result must preserve complete old output and the pre-call root
baseline while reporting fresh storage failure. Successful calls must match the
independent expected result and preserve seeded Err. The formal gate reruns this
fixture through both current-source stages; the development replay alone is not
qualification.

## Measured raw-scanner costs

The observed executables collected 20 samples per stage: source sizes 0, 2, 31,
4096 and 16384 bytes with long bare names, quoted strings, comments and dense
punctuation. Every sample passed zero source-payload copying, at most 2N executed
decoder feeds, geometric capacity and the contract's growth/publication bounds.
These measurements cover the raw scanner call; envelope recognition has its
separate functional/failure tests. They are not a whole `--check` throughput or
combined metadata/cooking cost measurement. Cost samples start with no old token
output; failure tests separately retain nonempty previous output. Caller root
holders/workspace below do not measure all generated callee stack/root storage.

For the 16384-byte dense sample, both stages observed 16386 tokens of stride 36,
capacity 32768, 13 capacity requests, 49151 counted byte reads and 32768 decoder
feeds. Growth copied 1179360 bytes. Publication copied 1179792 bytes: 589896
observed record-copy bytes plus 589896 runtime payload-copy bytes. Their sum,
2359152 bytes, is strictly below 4RT (2359584). Source payload copying was zero.
Record initialization and padding are excluded from payload-copy counts.

That sample requested 16 allocations totaling 3540968 bytes and the same requested
calloc initialization. This includes cumulative intermediate arrays, not just
retained output. The report separates 16384 source bytes, 128 bytes of caller
root holders, 172 bytes of caller workspace, 240 requested array-header bytes,
1920 requested GC-header bytes and eight publication-workspace bytes. Requested
zero bytes are not measured physical writes. Sampled process peak working set
for stage two was 48898048 bytes; it includes the C harness, runtime, fault
fixtures and process overhead and is not the compiler's steady-state footprint.

## Historical acceptance-definition snapshot

The following sections preserve the earlier definition-only result and handoff.
Their statements about an unimplemented scanner and unavailable raw Unicode
data describe that earlier snapshot. Current implementation and data evidence
are above and in `../../std-lib/UNICODE-EVIDENCE.md`.

The completed goal is the next definition item in `Roadmap.md`, governed by
`SCANNER-CONTRACT.md`. It defines acceptance over the already qualified source
snapshots. No production scanner, parser, preprocessor, backend or scheduler was
implemented by this goal. The executable still reports checking unavailable.

## Definition gate

```powershell
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tools/check-scanner-contract.ps1
```

Passed 2286 executed consistency assertions over 102 independently authored
vectors: 62 token/source-partition cases and 40 envelope cases. The catalogue
covers 174 grammar/literal/comment words, preserving reservedness separately
from ordinary-call eligibility. The exact run report is
`bootstrap/out/scanner-contract/01faedb66ddd4f899ea33cf159c7c936/report.json`.
Report SHA-256: `63493F66FAD769246A0192AA5EBADCB681A4A71E39E91A4FBD7ECE37B6CB7B92`.
The local `bootstrap/out/audit-scanner-definition.ps1` rechecked all 154 unique
definition input identities, report/count agreement and the handoff. The existing
handoff audit also passed PowerShell/JSON parsing, local Markdown link targets,
manifest targets, protected-instruction preservation and tracked whitespace.

The report pins fixture/checker/contract/authority inputs and records original
UTF-8 hex plus computed start/end positions. Token grouping is hand-authored;
selected numeric coordinate anchors are independently written. Envelope spans
are independently specified substrings whose coordinates are computed, not
independent numeric expectations. This distinction is intentional.

The gate checks data consistency, not correct scanner behavior. It verifies
exact physical partitions, virtual newline/EOF width, decoded quoted content,
explicit simple-fold examples, longest punctuation/suffix boundaries, original
positions and metadata/name agreement. Controls reject omitted physical input,
incorrect coordinates, absent metadata, undefined diagnostics and redundant
synthetic newlines. Ordinal checks
explicitly distinguish embedded NUL, composed/decomposed text and sharp-S/ss.

Native format 01, identifier-spelled native identity strings, REAL_TEXT detail
and equal-position diagnostic order are explicitly attributed consumer choices
under the owner's delegated decisions. Existing phrase/suffix rules take
precedence over wider VB dialect conventions. The definition does not turn
all ordinary library-call overlaps into legal bare declarations.

Independent reviews corrected a hand-authored continuation offset (16, not17),
separated callable eligibility from reservedness, and clarified missing-at-EOF
versus unterminated-lexeme anchoring. No archived compiler output was used as a
token/envelope expected answer.

## Preserved qualified baseline

`rtk proxy powershell -NoProfile -File bootstrap/out/scanner-prerequisite-audit.ps1`
rechecked 2228 recorded source/tool/report/artifact identities and the selected
470-check result. It did **not** rerun the full native gate. No accepted
production source, manifest, runtime, protected instruction or current selection
was changed. Current qualification remains the source-input scope in
`SOURCE-INPUT-EVIDENCE.md`:

| Identity | SHA-256 |
|---|---|
| Final manifest | `D6F484A8B725410F43AB3C9EE5292744E8E78CB7868DB4396AA88E92884897AA` |
| Immutable source manifest | `340106F0BF5A1CBF35F4D54F37884B94DE5965D5424257DA8DCDA9C3EE86C0F1` |
| Selected v2 stage two | `C15F4C29EF54DCB9A3922CAB27D114989CB3618DDDC188DE967A5BBC96FD4E6C` |
| Runtime | `F354F653A3819161B616FDCA3B342C4CD37C68708DFE924704836116FE98C4E2` |

## Focused bootstrap readiness probes

`rtk proxy powershell -NoProfile -File bootstrap/out/check-scanner-storage-diagnostic.ps1`
passed through both accepted v2 stages with byte-identical LLVM and exact
expected native output `257 / 512 / 513 / 0` (one number per line). It exercises
257 ByRef appends into arrays of nested scalar records, geometric Preserve
capacity to 512, retained field values and independent array copying. Generated
Append has typed resize and no whole-array `ube_value_assign` call. This is a
bounded success/readiness diagnostic, not measured scanner copying, allocation
failure or concurrency qualification.
Report: `bootstrap/out/scanner-storage-diagnostic/960f0baea68d41f398c45f312b62735f/report.json`.

A focused search/manual review found six reserved declarations in current
v3/UBECore source: SourcePosition.Line; three SourceInput Input parameters;
one SourceFile Input local; and ByteBuffer's low-level Preserve parameter.
Bootstrap acceptance does not prove their full native-language conformance.

`rtk proxy powershell -NoProfile -File bootstrap/out/probe-bracket-source-names.ps1`
tested complete isolated native modules through both accepted stages. Bracketed
field, parameter and local names consistently reject with UBE2113, UBE2120 and
UBE2200, exit1 and no LLVM. Report:
`bootstrap/out/bracket-source-name-diagnostic/63de4a4f334a4a25a0cd32e5fc585f24/report.json`.
Use ordinary nonreserved renames during implementation; adding bracket support
to v2 is unnecessary for this need. This is a narrow declaration-form review,
not an exhaustive parser-based conformance audit.

## Unicode data readiness

The target remains Unicode18. Its [official release announcement](https://blog.unicode.org/2026/09/announcing-unicode-standard-version-180.html)
and [versioned UCD ReadMe](https://www.unicode.org/Public/18.0.0/ucd/ReadMe.txt)
establish publication/final-data status. The [CaseFolding source](https://www.unicode.org/Public/18.0.0/ucd/CaseFolding.txt)
supports the explicit Kelvin/sigma/sharp-S fixture mappings using C/S statuses;
full sharp-S expansion is deliberately excluded. Letter membership data is
[DerivedGeneralCategory](https://www.unicode.org/Public/18.0.0/ucd/extracted/DerivedGeneralCategory.txt).

Exact retained raw-input hashes and exhaustive comparison against clean
bootstrap generated headers remain **unverified**. Local raw retrieval did not
complete; no downloaded table or dependency was added. Existing generated
headers/comments are not a substitute for this independent provenance proof.
Before qualifying ordinary UBE lookup, retain authoritative data bytes, hashes
and license/provenance offline and independently compare every C/S mapping and
merged Letter interval. Never substitute host Unicode/casing or add a privileged
Unicode intrinsic to hide ordinary library work.

## Exact next implementation handoff

1. Use this contract/corpus for the existing scanner item. Make the narrow
   reserved-declaration renames with positional API/layout/behavior preserved;
   update callers/tests/docs together and retain the baseline gates.
2. Establish versioned Unicode data provenance and implement only the ordinary
   UBE Letter/simple-fold lookup and cursor work the scanner actually needs.
   Typed arrays/records already suffice; no new storage primitive or generic
   collection is justified. Tokenizing literal spans does not require a full
   numeric/String/Date implementation.
3. Implement source-header recognition and raw token/span production in UBE,
   preserving exact source ownership, continuation separation and deterministic
   diagnostics. Respect the context boundaries for callees, dates/file markers,
   designer fragments and later conditional compilation. Do not claim complete
   source checking from successful scanning.
4. Add the real native fixture-comparison gate through both source-built stages,
   with intact source/actual UBECore Reference, independent data, allocation/root
   faults, complete-output atomicity, cleanup, private workers and observed
   source/token copying/allocation budgets. Only then qualify scanner behavior
   and update the accepted selection. Parsing/code generation remain later work.
