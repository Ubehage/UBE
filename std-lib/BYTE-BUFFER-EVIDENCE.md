# ByteBuffer source-body evidence

Recorded 2026-10-30. The ordinary UBE ByteBuffer and UTF-8 bodies pass the
functional and instrumented acceptance gates through both source-built v2
stages. The stable semantics and budgets are in
[BYTE-BUFFER-CONTRACT.md](BYTE-BUFFER-CONTRACT.md), with predefined oracles in
[tests/byte-buffer/ORACLES.md](tests/byte-buffer/ORACLES.md).

The combined 296-assertion source-build snapshot and detailed measurements are
recorded below. This is a qualification record, not a released Library binary,
a built native Library envelope or builtin String replacement. Compiler source
ingestion was the identified next consumer. Its subsequent integration and
newest accepted tool record are tracked in
[`../compiler/UBE_Compiler_v3/SOURCE-INPUT-EVIDENCE.md`](../compiler/UBE_Compiler_v3/SOURCE-INPUT-EVIDENCE.md).
The 296-assertion identities below remain the immutable earlier body snapshot.

## Maintained acceptance commands

From the repository root:

```powershell
rtk proxy powershell -NoProfile -File bootstrap/build-v2.ps1
rtk proxy powershell -NoProfile -File std-lib/tools/check-byte-buffer.ps1
rtk proxy powershell -NoProfile -File std-lib/tools/check-byte-buffer-costs.ps1
```

The combined source gate builds the clean seed/runtime and two compiler stages,
checks the exact self-compilation LLVM fixed point, and binds every child proof
to the same immutable source manifest before publishing a selection. Its
recorded 296 assertions comprise 136 core, 66 native scalar, eight ordinary
record, eight managed substrate, 52 managed value, eight decoder, 13 ByteBuffer
functional and five ByteBuffer cost/ownership/concurrency report checks.

Both ByteBuffer runners remove exactly the two documented module-envelope
lines from Utf8.bas and ByteBuffer.bas, preserving the ordinary UBE bodies.
Functional fixtures check all Byte values, embedded zero, ownership copies,
exact snapshots, growth, overlap, malformed state/ranges, strict UTF-8 and reuse.
Each positive result requires exact native output/exit/stderr and byte-identical
raw LLVM through both stages. Full Library-kind manifest/native-envelope
compilation remains unbuilt.

The instrumented suite executes **210,645 internal C assertions per stage**.
Its five report checks comprise each stage's instrumented acceptance, each
stage's exact accepted uninstrumented-runtime subset, and raw LLVM identity.
The C/LLVM test adapters call the actual generated library procedures, query
their target layout and observe executed operations. They do not replace buffer
or UTF-8 algorithms. The ordinary buffer record size/alignment, Count offset,
decoder size and root-storage size are checked against the emitted types.

## Actual work and storage observations

The report contains **20 measurement rows: ten input sizes through two stages**.
Both stages produced the same deterministic values below. Append calls are
observed calls into the compiled UBE procedure; copies count actual runtime
payload-copy leaves, and allocator counters observe calls made by the runtime.
They are not counters manufactured from N.

| N appends | Capacity | Growth payload allocations | Growth copied bytes | Peak tracked requested bytes above baseline | Collector live bytes after collection | Snapshot copied bytes |
|---|---|---|---|---|---|---|
| 1 | 8 | 1 | 0 | 152 | 24 | 2 |
| 8 | 8 | 1 | 0 | 152 | 24 | 16 |
| 9 | 16 | 2 | 8 | 312 | 32 | 18 |
| 16 | 16 | 2 | 8 | 312 | 32 | 32 |
| 17 | 32 | 3 | 24 | 488 | 48 | 34 |
| 64 | 64 | 4 | 56 | 696 | 80 | 128 |
| 65 | 128 | 5 | 120 | 968 | 144 | 130 |
| 256 | 256 | 6 | 248 | 1368 | 272 | 512 |
| 4096 | 4096 | 10 | 4088 | 9624 | 4112 | 8192 |
| 65536 | 65536 | 14 | 65528 | 133080 | 65552 | 131072 |

All growth copies satisfy the predeclared `<2*N` budget and capacities satisfy
the documented doubling bounds. Every row has zero tracked allocation delta
and zero collector live bytes after values leave scope and collection runs.

At N = 65,536, the observed allocation sequence is 8,16,32,...,65,536: 14 payload
allocations and 65,528 copied payload bytes. The allocator requests 133,080
successful calloc bytes during growth, including observed allocation headers;
131,064 of those requested bytes are array payload zero-initialization.
Peak requested live bytes above the measured baseline are 133,080. Collection
retains 65,552 collector-accounted bytes, including the live array's own storage
header; this is not a payload-only or process-memory number.

The snapshot executes two payload allocations plus one pointer-sized copy
workspace allocation. At N = 65,536 it copies 131,072 payload bytes, requests
131,072 payload zero-initialization bytes and 131,368 total successful calloc
bytes including headers/workspace. The two copies are the independently
prepared snapshot and its failure-atomic publication.

These calloc counters measure **successful requested zero-initialization
bytes**, not physical CPU zero stores. Requested live/peak accounting excludes
allocator/OS overhead and fixed test-tracking storage. Sampled process working
set is reported separately and includes the harness/runtime; it is neither the
builder's memory cost nor a throughput guarantee. The default runtime contains
no test copy observer or observation-only traversal field/argument overhead;
instrumentation is confined to separately compiled test runtime objects.

Satisfied reserve, clear, length/capacity queries and UTF-8 validation execute
zero observed allocator requests and payload-copy leaves. Successful validation
feeds exactly Count bytes and calls Finish once. Invalid first byte 255 executes
one Feed and zero Finish calls; truncation is rejected by Finish. The independent
decoder gate retains its measured zero-allocation result.

## Failure, Err, ownership and workers

Injected failure targets real runtime allocation attempts, including both
collection/retry attempts and the snapshot's final publication allocation.
Tests preserve existing buffer bytes/count/capacity and an earlier output
`[91,92]` when reserve, snapshot preparation or publication fails with Err 7.
Partial temporary allocations return to the measured baseline after collection.
One failure followed by retry succeeds while preserving Err 77. Successful
operations also preserve stale Err 7; status is a fresh result for each call.
The maximum signed-Long reserve path is tested with deterministic failure and
observed allocation bounds, without requesting a two-gigabyte host allocation.

Four actual native C caller threads share only a rooted immutable 256-byte
input. Each owns its builder/output, uses a distinct marker 0,65,128 or 255 and
a distinct thread-local Err value, and completes 32 rounds of append, snapshot,
clear and reuse. Worker zero additionally injects snapshot-publication failures
and exercises the compiled cancellation-style early-return cleanup path.
All workers are joined within the predefined bound, all handles are closed,
shared bytes remain unchanged, and all managed/observed storage returns to the
baseline. This qualifies independent instances and immutable shared input;
it does not qualify a UBE scheduler, coherent unsynchronized shared mutation or
general language cancellation.

The combined gate also fixes and directly regresses first-error bookkeeping
exhaustion. Previously, failing the host TLS-state calloc while publishing an
ordinary Err 7 silently returned Err 0. The before diagnostic is retained in
`bootstrap/out/error-bookkeeping/2df17f6f48f84b9799b432b367e974f7/report.json`.
With adequate bookkeeping, the accepted runtime records Err 7 normally. If the
minimum storage required to record that error itself fails, it follows the
permitted safety-bookkeeping fatal path: exit 70, empty stdout and exactly
`UBE managed support: insufficient bookkeeping memory while recording an error`
on stderr with a terminating newline. The corrected standalone reproduction is
`bootstrap/out/error-bookkeeping/6c3c8d33353b4717af0b278769cf1e06/report.json`;
the combined managed-substrate report repeats both normal/failure regressions.
Ordinary managed payload exhaustion still returns False/Err 7 after retry.

## Current combined source qualification and identities

The final source recapture passes 296 assertions and binds the stabilized
contract/oracle documents as immutable build inputs. Their semantics/budgets
are unchanged; changing snapshot identities live here rather than in those
inputs. The qualification covers the specified source bodies and gates, not
the remaining full Library/compiler-consumer work.

| Artifact | Path or SHA-256 |
|---|---|
| Manifest | `bootstrap/out/v2/bddd33dcc3cd46d8ba4e1d783b3d3391/manifest.json` |
| Manifest SHA-256 | `EDEA7D8E2E5CE8535360CF510730A8DAC2B504924827B31936E99A320D4DA156` |
| Immutable source-manifest SHA-256 | `107D75A63C126879D74159564D8864F0DD8220E7F8754C9335F81BBB5DA62579` |
| Source inputs | 216 |
| Clean source-built seed SHA-256 | `FE1B37977175AA2C7DF87AE04B2CF3C19FA9FF078F4EB3126D6E9AB3B5C5D38E` |
| Stage-one compiler SHA-256 | `8F781F56498F1BD8B000C67D4234B89F8BFDAED05F544DA1FCCB7177069C8D45` |
| Stage-two compiler SHA-256 | `9D5DBBEEDA9F2BF327048C980FB2AC28A9DBA10555BA1DA11957A1BE57D1515C` |
| Accepted runtime object SHA-256 | `4BEAF811D31FF39B26B6219B3DD5CF3C067EDE5899016C9C087CFB29A7E04835` |
| Accepted Unicode runtime object SHA-256 | `AB41E49C6E1375AC878F588FF88DC7DB43A7018CAD8F3F811DE811F7C245EDFD` |

| Child report below `bootstrap/out/` | SHA-256 |
|---|---|
| `byte-buffer/a0df6cf6ec7e45e388a7df3b09e34a2e/report.json` | `3EAE04511161252B1A265138C605E7C7ABCAF0072C6ED4F687085D7E0989976F` |
| `byte-buffer-costs/0abfa0f675e14e89bddac9f25a43c05b/report.json` | `8C217BA5B3C5B6A11BA530FE135246E993C014C58F12CC8FAEE102A014072CE9` |
| `managed-storage/89522238a66f4d3492c27fdbea5c64d9/report.json` | `06E5ED2D45970A41F857D53B40E54F3815C73B5C702DEF90014D85BD4517AD59` |
| `managed-values/e8e0ebe17f714e6f9c74d0c6ffecafbe/report.json` | `5889DEDA8A81534E4771C958001908DA662E73FF860F7DDAC94551A5D2B41F56` |
| `utf8/f75090f58cf2484e8a083138f0087570/report.json` | `E4DAF1EF7CDA3C3071A6EF86C73097E4D9A8D4C9ACB0B83711CD5542F29B8DE8` |
| `native-type/616dce31e9d84fe48a586d289a18f1e8/report.json` | `81FBD476F5FC64127235BE0AD958F47E9FD7969030F73DACB9E257564D64F0C7` |
| `value-record/366a82ae335c4a0b90f96726176d43fc/report.json` | `A87AB688E9FCB58F9D2F6827A65C850AD2BB00D216FA877FA5BFE0548D933EFA` |

| Source/proof input | SHA-256 |
|---|---|
| `std-lib/src/portable/ByteBuffer.bas` | `E9317A4900418A401EEEA1A0FF24386EB4309FB911A9767217C35A3179C244A8` |
| `std-lib/src/portable/Utf8.bas` | `81183C68FD1A797CE43389DD39FAB152C6D356D1BD7812F0C251686F36163B81` |
| `compiler/UBE_Compiler_v2/Main.bas` | `3B6401F3CB89128AACC6D2076D98AA1B0B445A721AF2DD0F44F93A09F38FDF3F` |
| `runtime/bootstrap_runtime.c` | `A40FE47F2F902E563F54EFFEA0C70351D07B635D88568D98DBCDD3C8C2912403` |
| `runtime/value_storage.h` | `C1A8F0723A412FD1C0411412A0DD7C42426128B3A9F4CBA7E7786DD0F78A2B92` |
| `std-lib/tools/check-byte-buffer.ps1` | `E6AC80E08748AC361452E0E0472925A9DA2ACF75ABB88A95E9A2B1EE74757354` |
| `std-lib/tools/check-byte-buffer-costs.ps1` | `BA5E1C8A0ADD2B8AE119A8A624DBF588FF9AC06616B1EE25301420AD9D3DAB68` |
| `std-lib/tests/byte-buffer/metrics.c` | `FEC14674A4C0656E85234F8DD112659A27011F1A9543278864AB25087EBA072F` |
| `std-lib/tests/byte-buffer/metrics-entry.bas` | `5834D2124CE82A4A67C66FC996FC7FD8FF1FDFF98CA24A03F476481636A4BECB` |
| `std-lib/tests/byte-buffer/metrics-adapters.ll` | `753F4A44ED496A29F3654943072BA52567087AD7DA9C788A378A61C323ABD996` |
| `std-lib/tests/managed-storage/copy-probe.h` | `A07818ED10ABEC76E3D4F2E1EA4746895DD8953AA0E53D032F40DBC831EC425B` |
| `std-lib/tests/byte-storage/allocation-probe.h` | `35277B48DED35DD1917E4FFDC2DA44E198A3901F46F1E65FE7D144676772512A` |

The recorded GCC/G++ 16.2.0 tool hashes are respectively
`206F9FC067234F48AE077550658DAE06BD75D99110C1B3166887B7090CBD7FA0` and
`FADAC447401F77FD88D77624CCD6028D57DB5CA028A731DB9DE6A039CF86C62A`.
Clang 23.1.3 at the qualified x86-64 Windows GNU target has SHA-256
`F3425B2BFF01BC401C84AF6E5E180629182FAFC2EB35CF971A3E50C9CF13F263`.
The manifests retain complete tool paths, versions, commands, artifacts and
limitations; no restored executable or archived implementation participates.

The earlier combined 296-assertion run is preserved at
`bootstrap/out/v2/4e5e0ca14362476d9c8ec7afc6d3771d/manifest.json`, SHA-256
`1B60AD04655EFFD8FE9302507DE207FAC027ADFE3C05803F6D18179DAC43AD01`.
It preceded the documentation-status recapture. The current table above is the
accepted qualification after those stable contract/oracle inputs were bound.

## Remaining boundary

The next compiler consumer is owned source-byte ingestion, strict validation
and independent exact-length snapshot publication. File I/O, tokenization and
source byte-position policy remain compiler responsibilities. This proof adds
no fresh v3 scaffold, immutable Text class or builtin String replacement.

All growth, range/domain policy and UTF-8 algorithms are ordinary UBE. Generic C
program support remains a bounded bootstrap exception for allocation, precise
roots, atomic reference/scalar access and memory movement. Its removal condition
is equivalent UBE-emitted/type-specialized support passing the same managed,
functional, failure, cost and concurrency gates before replacing it. External
resources still require explicit release; no collector/destructor equivalence
or full native Library build is inferred from source-body acceptance.

## Consumer handoff

The concrete next consumer is compiler source intake before lexing. One owner
appends each file's input chunks with TryAppendBytes, validates the logical
buffer with TryCountUtf8Scalars, and publishes TrySnapshotByteBuffer's exact
independent bytes only after both fresh statuses succeed. Reusing the builder
cannot change the snapshot. Reader workers may borrow that snapshot under an
immutable-input contract; its owner retains it until every reader has joined.
Source BOM/NUL/line-ending policy and byte-to-line/scalar position mapping stay
in the compiler. File handles must close explicitly on every path. This
handoff requires no unproved builtin String representation or library growth
algorithm. Creating the fresh v3 consumer source/manifest is the next workplan
item, not a completion claim in this library proof.

## Final verification and scope audit

The original storage diagnostic was rerun unchanged against the final selected
tool with `rtk proxy powershell -NoProfile -File std-lib/tools/probe-byte-storage.ps1`.
All **10/10 required obligations now pass**, including both independent copy
cases, scope/collection cleanup, one-failure recovery and persistent-failure
Err 7 through both stages. Report:
`bootstrap/out/byte-storage/ddb196f0d3e94a0e8bcc7bc42f22dda3/report.json`.
The earlier zero-of-ten report remains historical evidence of the actual gap.

Additional final checks passed:

- `bootstrap/tests/v2_usage_tests.ps1`: exact byte-array execution, controlled
  invalid-constant rejection, old executable preserved on failure, successful
  replacement. Report `bootstrap/out/v2-usage/b050e78b58034cb7a771bbc809491889/report.json`.
- `std-lib/tools/check-native-example.ps1`: four exact public-example/body/
  stage-output/LLVM assertions. Report
  `bootstrap/out/native-example/bebc2945ec8a4ac9ac4c3269dfa53ae1/report.json`.
- `lang-doc/tools/validate-grammar.ps1`: 202 core and 19 conditional productions;
  `lang-doc/grammar/fixtures/validate-fixtures.ps1`: 12 fixtures/four categories.
- `compiler/archived/verify.ps1`: 367 original/archive files, 13 relocation-only
  edits, nine previews, 28 old library files, six manifests/134 source paths and
  21 scripts. No archived implementation bytes were imported or changed.
- `std-lib/tools/check-inventory.ps1`: 175 reference names, 73 historical hooks,
  52 local links and the existing 710-row documentary inventory.
- `docs/assets/tools/validate-docs.ps1`: 265 HTML files. Browser/interactive/
  accessibility release matrices remain unverified; no UI behavior changed.
- Generated `bootstrap/out/audit-final-buffer-evidence.ps1`: 296 final/136 core
  assertions, 216 source inputs, seven immutable-bound child reports, 624 unique
  artifact/input/tool identities, 20 actual measurement rows, 210,645 native
  checks per stage and current evidence/source hashes. Its JSON report is
  `bootstrap/out/final-buffer-evidence-audit.json`.
- Generated `bootstrap/out/audit-library-handoff.ps1`: 17 PowerShell parses,
  ten JSON parses, 35 Markdown files/130 local links, three manifest sources,
  ten public reference names, unchanged protected instructions and diff hygiene.

The maintained commands above are prefixed with
`rtk proxy powershell -NoProfile -File` when run from the root; final diff hygiene
used `rtk proxy git -c core.safecrlf=false diff --check`. Generated audit scripts
are local handoff checks, not new production build dependencies.

The completed scope is the first tested byte/text foundation: agreed contracts,
managed substrate proof, ordinary UBE implementation, independent functional/
failure/cleanup/cost/concurrency evidence, a concrete consumer handoff and
synchronized documentation. The remaining boundary above stays explicit.
