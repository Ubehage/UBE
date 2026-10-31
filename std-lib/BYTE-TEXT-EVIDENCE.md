# Byte/text foundation evidence

Recorded 2026-10-30 for the owner's foundation work. The original decoder/probe
snapshot below was blocked awaiting managed-storage approval. The owner then
approved [MANAGED-STORAGE-PROPOSAL.md](MANAGED-STORAGE-PROPOSAL.md) and extending
v2 as needed for bootstrap. That approval is satisfied; it is not a current
blocker. [MANAGED-STORAGE-EVIDENCE.md](MANAGED-STORAGE-EVIDENCE.md) records the
subsequent 276-assertion managed-foundation source gate and exact identities.
The decoder follows [BYTE-TEXT-CONTRACT.md](BYTE-TEXT-CONTRACT.md).

Its eight assertions and measured zero allocations remain in the new gate.
The ordinary ByteBuffer source body additionally passes 13 functional checks;
its cost/failure/concurrency qualification is pending at this snapshot. Neither
result establishes a full Library build, released binary or builtin String
replacement. Earlier failed storage obligations below retain their original
tool identities and failures; they are not rewritten as passing results.

## Implemented ordinary UBE component

`src/portable/Utf8.bas` supplies `Utf8Decoder`, `ResetUtf8Decoder`,
`FeedUtf8Byte` and `FinishUtf8Decoder`. There are no intrinsic declarations,
managed references, retained arguments, heap allocations or external resources
in this component. It preserves embedded zero and reports fresh validation/
completion status without using or changing Err. It does not implement owned
storage, a builder or builtin String.

Command from the repository root:

```powershell
rtk proxy powershell -NoProfile -File std-lib/tools/check-utf8.ps1
```

Result: **eight acceptance assertions passed** through both accepted v2 stages.
Raw LLVM is byte-identical. Each stage executes the independent native suite
twice: once with the exact accepted runtime objects and once with allocator
instrumentation in a separately compiled copy of the same runtime source.
The accepted source/artifact identities are checked before use; no restored
compiler participates and no production runtime object is replaced.

Independent predefined oracles in `tests/utf8/` check:

- All 1,112,064 Unicode scalar values, encoded independently and decoded exactly.
- Every one-byte string (256) and two-byte string (65,536), including invalid,
  truncated and overlong cases, against a separate whole-sequence oracle.
- Nineteen explicit boundary/malformed vectors and all their prefixes, including
  surrogate encodings, CESU-8, overlong forms, maximum scalar, out-of-range
  encodings, BOM and noncharacter values; 50,000 deterministic random streams.
- Multi-scalar input with embedded NUL, pending/neutral outputs, sticky failure,
  reset, repeated Finish, truncation and five malformed-state cases without
  overflow or process failure.
- UBE record assignment and ByVal mutation, proving that copies of a split
  scalar proceed independently. The C harness does not substitute state copies.
- Existing Err 77 preserved through sequential success and failure predicates.
  Four bounded native test workers read shared immutable input, each using its
  own decoder and distinct thread-local Err, for 10,000 iterations per worker.
  Every worker is joined and its handle/start event closed. This is direct
  library reentrancy evidence, not proof of UBE CallNew or compiler scheduling.
- Actual target state size/alignment 16/4 from LLVM GEP layout queries; zero
  observed runtime allocator calls during decoding in the instrumented runs.
  A positive control allocates/releases an actual bootstrap array and must
  increment the allocator counter before it is reset for decoder measurements.
- Executed Feed calls measured at input sizes 11, 176, 2,816 and 45,056 bytes:
  exactly one Feed per byte. Feed has bounded arithmetic/branches, no loop,
  buffer copy or allocation. State memory does not grow with input length.

Sequential test execution recorded **4,723,522 actual Feed calls per run**;
worker calls are checked separately and are not included in that counter.
Observed native durations were 163/144 ms for stage one accepted/instrumented
and 150/150 ms for stage two. These are diagnostic single-run times, not a
throughput guarantee. Sampled process peaks include the harness and linked
support; they are not the decoder's own allocation cost.

The C whole-sequence oracle assembles numeric digits and independently checks
shortest length and scalar membership; the product uses incremental state.
Test-only LLVM bridges expose C-callable functions and layout queries, renaming
only the unused generated program entry. They replace no UBE procedure/type.
The instrumentation header redirects calls made by the repository runtime;
it does not intercept CRT startup. Initial linker-wide interception hung before
main and was abandoned; that failed harness run is retained at
`bootstrap/out/utf8/078ac707609342ec999e966f5b0a3abd/report.json` and is not evidence
of a decoder failure or a passing allocation test.

Report: `bootstrap/out/utf8/dcd95bcbe3b14b2d951b12004d6a2996/report.json`.
SHA-256: `EE1F9135202B3A05957DCE8AF8C14ED67E1E69C3C19E1A40E6248E2C2F4E0DB7`.
It retains exact inputs, compiler/runtime identities, commands, native outputs,
measurements and generated artifact hashes. The fresh Library manifest now
includes the module. Tests remove exactly its two source-envelope lines and
compile the unchanged ordinary body using v2's documented bare-source exception.
The full native envelope/Library manifest build is **unverified**.

## Owned-storage diagnostic: requirements not passed

Before attempting compiler-wide changes, the smallest fixtures isolate the
required copy, lifetime and allocation-failure behaviors:

```powershell
rtk proxy powershell -NoProfile -File std-lib/tools/probe-byte-storage.ps1
```

Diagnostic completed successfully; **zero of ten target obligations passed**.
Each of the following five obligations was exercised through both stages:

| Required behavior | Actual result in both stages |
|---|---|
| Independent Byte-array assignment; copy remains 65 after original changes to 66 | Compiler exit 1, UBE3221 unsupported independent array copying. |
| Same copy through an ordinary value record containing Byte storage | Compiler exit 1, UBE3221. Array initialization goes through supported explicit ByRef storage, isolating the copy. |
| Dead local storage reclaimed after scope exit and collection | 1,000 allocations remain live, 40,000 instrumented allocation bytes; collector returns 0; Err remains 77. Required live count is zero. |
| A single failed allocation collects/retries and succeeds, preserving Err 77 | One injected allocation failure exits 70 with a bootstrap-array out-of-memory diagnostic. |
| Persistent ordinary allocation failure returns safely with Err 7 | Two injected allocation failures also exit 70 on the first attempt. No safe result returns to the caller. |

The lifetime probe counts allocation/free events in the separately instrumented
current runtime while repeatedly executing the complete compiler-generated
procedure. It calls the existing collector afterward. Retention is measured
before process-exit cleanup; this does not claim that the allocator leaks after
the whole process exits. The failure probe returns NULL at the actual runtime
allocation boundary. No hostile oversized allocation or host-memory exhaustion
is used. These findings are not target conformance passes or crash repairs.

Report: `bootstrap/out/byte-storage/c3db1630a521432aabd3ac9d38e4b3e9/report.json`.
SHA-256: `BC920F23DB7C9427FBDA0D3329638311F3132E78D447065DBB95EA0250335215`.
Required values are specified independently in `tests/byte-storage/obligations.json`.
An initial record fixture hit unsupported ReDim-member syntax before the desired
copy; it was narrowed to initialize via ByRef and now diagnoses the copy itself.
An oracle review then separated single-failure recovery from persistent failure:
the normative contract requires collection and one retry before Err 7. The
earlier eight-obligation report is a superseded diagnostic snapshot. The local
allocation fixture ends immediately after ReDim so an index operation cannot
mask the allocation result with a later error. Both failure probes request
collection after return before testing the retained allocation count.

## Trust and remaining work

Both suites use the selected source-built v2 manifest
`bootstrap/out/v2/6df71ef3a52749ac9bd6c965e086022f/manifest.json`, SHA-256
`006D6EC71EF0423E8B70A57B7293B611E452C709867FE74AFEA901B880F99CDC`, and stage-two
executable SHA-256
`9C6B666F858B451D8E8D96E2595FF4AFCB8B7298ABC3499DA14A8DE0BBA28866`.
At that snapshot, 204 assertions formed the compiler gate; the eight decoder
assertions were a separate library gate, not silently added to that count.
The subsequent managed-foundation gate explicitly includes its decoder child
proof and records the merged 276 count separately.
See [native evidence](tests/native-type/NATIVE-EVIDENCE.md) for that trust chain.

The original decoder/probe work recorded above changed no compiler/runtime
source or archived implementation. The subsequent approved managed work does
change active v2/runtime sources, with its separate proof linked above.
No fresh v3 scaffold exists. Decoder code is ordinary new UBE; C and LLVM here
serve only as test instrumentation. The first compiler consumer is identified
as UTF-8 source ingestion with separate byte/scalar positions; integration is
still pending. The subsequent managed root/copy/cleanup proof is complete for
its bounded ordinary Byte/record scope. Builder cost qualification and an
immutable Text/builtin String publication proof are separate obligations.

Structural/document checks also passed:

- `rtk proxy powershell -NoProfile -File docs/assets/tools/validate-docs.ps1`:
  265 HTML files, including the decoder reference added to the library overview.
  Interactive/browser/accessibility verification remains unperformed.
- `rtk proxy powershell -NoProfile -File compiler/archived/verify.ps1`:
  367 originals/archive files, 13 relocation-only edits, nine previews, 28
  previous library files, six manifests/133 source paths and 21 scripts.
  The extra manifest source is the new Utf8 module, not an archive change.
- `rtk proxy powershell -NoProfile -File std-lib/tools/check-inventory.ps1`:
  175 baseline names, 73 historical hooks and 52 local links.
- `rtk proxy git -c core.safecrlf=false diff --check`: passed.

Final local handoff audits also passed. Generated
`bootstrap/out/audit-byte-text.ps1` checked 35 proof input/artifact hashes, the
eight decoder assertions/four native runs/two measured zero-allocation runs,
all ten retained storage failures, both manifest sources and the three exact
public signatures. `bootstrap/out/audit-native-completion.ps1` rechecked 262
accepted compiler identities, existing 204/130 final/core and 66/8 nested
assertions, 13 PowerShell syntax parses, seven JSON parses, 29 Markdown link
checks and diff hygiene. These generated audit procedures are local handoff
checks; the maintained commands above remain the reproducible gates.

The original snapshot ended blocked pending the owner decision on compiler-wide
root/barrier/lifetime prerequisites. The owner subsequently approved that work.
The separate managed evidence now supersedes those capability limits for the
new source-built tool, while preserving the earlier diagnostic history.
