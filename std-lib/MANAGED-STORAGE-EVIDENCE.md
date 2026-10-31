# Managed array and record evidence

The latest recoverable-memory correction and complete 501-check requalification
are in [the parser-probe evidence](../compiler/UBE_Compiler_v3/PARSER-PROBE-EVIDENCE.md).
Tracing-workspace and first-error publication now require recoverable behavior;
the older fatal expectations below are historical. The current gate retains all
foundation proof families and strengthens those checks with native regressions.

The earlier byte/buffer qualification is recorded in
[BYTE-BUFFER-EVIDENCE.md](BYTE-BUFFER-EVIDENCE.md): the final recapture passes
296 assertions, including the managed substrate/value gates, decoder and
functional/instrumented ByteBuffer source-body proofs. The **276-assertion run
below is the historical managed-foundation snapshot**, with its original exact
identities and limits preserved. Current selection/report identities belong in
the linked evidence; this file does not describe pending ByteBuffer costs as
the present state.

Recorded 2026-10-30 against the owner-approved
[managed-storage contract](MANAGED-STORAGE-PROPOSAL.md). The owner explicitly
authorized extending v2 as necessary for bootstrap. Ordinary Byte arrays and
finite value records containing arrays now have a bounded managed-value proof;
this does not qualify builtin String, objects, the complete language, or a
released UBECore binary.

## Reproducible source gate

From the repository root:

```powershell
rtk proxy powershell -NoProfile -File bootstrap/build-v2.ps1
```

The recorded run passed **276 acceptance assertions**: 136 core, 66 opaque
native scalar, eight ordinary-record, six managed-substrate, 52 compiled
managed-value and eight decoder checks. It built the C++ seed, runtime objects
and both v2 stages from source. Stage-two/stage-three self-compilation LLVM and
each positive pair's raw LLVM are byte-identical. No restored compiler,
archived implementation or new dependency was used.

The former whole-array, ByVal-array and managed-record copy rejections now
have independent mutation/zero oracles; this changes the core report count
from 130 to 136. Inline recursive records retain a controlled UBE3221 rejection.
Counts describe report assertions, not the number of individual scalar checks
inside each native program.

The build hashes source, headers, fixtures, scripts and tools before use,
retains an immutable source-build manifest, and binds every child proof to its
compiler and that exact manifest. Only a complete pass updates
`bootstrap/out/v2/current.json`. Failed runs retain their manifests and leave
the earlier selection intact.

| Recorded artifact | Identity |
|---|---|
| Final manifest | `bootstrap/out/v2/4c958e4f9e594a0eaaf052f1926ce3f5/manifest.json` |
| Manifest SHA-256 | `6EB2DF20FD434A41BB74D903A64E09CF7AEE494C392CECF3951B4DEEDDF3250D` |
| Immutable source-manifest SHA-256 | `8974802AD05E896BFE945D97EAC04D1D0635AA11A4B6188AF28A94A6FE021033` |
| Stage-two compiler SHA-256 | `E239322555908818CB4D01CBE4AA95618F9D66F6583A36A78C434E043D971F9E` |
| Bound source inputs | 199 |

This is the recorded managed-foundation run, not a claim that subsequent
ByteBuffer cost/failure/concurrency qualification is complete. Later accepted
selections must retain their own exact identities.

## Compiler-generated value behavior

`tests/managed-storage/cases.json`, `binding-cases.json` and
[VALUE-ORACLES.md](tests/managed-storage/VALUE-ORACLES.md) specify results
independently of compiler output. The maintained child command is:

```powershell
rtk proxy powershell -NoProfile -File std-lib/tools/check-managed-values.ps1
```

Its 52 assertions passed through both source-built stages:

- Empty/default arrays, zero bytes, embedded zero/255, self-assignment,
  independent assignment/ByVal/results, deliberate ByRef mutation and Preserve
  growth. Actual record size/alignment is checked as 24/8 on the recorded target.
- Nested arrays of records containing Byte arrays survive allocations and
  forced collection. Copies remain independent. A borrowed ByRef element stays
  live while its parent holder is replaced and the callee collects.
- Normal/early procedure returns and 1,000 repeated local calls leave zero
  additional live managed payload bytes after collection.
- Injected managed allocation failures preserve the destination's old value.
  One failure collects/retries and succeeds while retaining Err 77; two failures
  return controlled failure with Err 7. Resize returns a fresh Boolean.
- Failed ByVal-array preparation returns the neutral scalar result; failed
  whole-array/whole-record result assignment retains a neutral result. Fully
  initialized source records remain unchanged, and failed/returned temporaries
  leave no live payload after their roots leave and collection runs.
- Twenty-eight negative cases check exact UBE3232/UBE3230 binding categories,
  metadata ownership, wrong signatures/modes/types/result flags and managed
  program entry rejection UBE3004. Both stages return exit one, produce no LLVM
  and give identical diagnostics.

Test-only C/LLVM bridges expose complete generated procedures, root caller
locations, inject actual managed allocation failures and query actual target
layout. They do not replace UBE copy, result or resize bodies. The measurements
use runtime managed payload accounting, not process working-set estimates.

The actual entry bug was reproduced first: `Main As Long()` explicitly assigned
an empty Long array, yet the earlier compiler emitted a hidden-result void
procedure and an incompatible i32 entry call without the output argument.
`bootstrap/out/managed-main-before-92fbfd08203c4741802bb8d603c1d1f4/`
retains that diagnostic. The accepted compiler rejects it with UBE3004.

A separate exploratory record test initially expected implicit rollback over
several user statements. That oracle was incorrect. If `Local.Data = Source`
fails and later source sets `Local.Marker = 123`, `{Data = Nothing, Marker = 123}`
can be an ordinary subsequent value. Failure does not introduce an implicit
procedure abort or a transaction around later user code. The corrected fixture
injects failure into the single whole-record result assignment from an already
complete source. No compiler change was made to redefine error control flow.

## Runtime substrate and bounds

`std-lib/tools/check-managed-storage.ps1` contributes six report assertions.
Its C suite executes 162 internal assertions, exact capacity/recovery of
1,048,576 precise roots, four independent concurrent workers, nested tracing,
borrowed lifetimes, partial-copy rollback, bounded traversal, neutral private
reads, and real payload-copy observation. The minimum tracing-bookkeeping
exhaustion case follows its independently specified bounded exit-70 diagnostic;
ordinary payload exhaustion remains recoverable Err 7.

Compiler-generated layouts enumerate exact reference slots from the type graph.
Roots cover locals, parameters, results, expression temporaries and borrowed
owners before allocation/collection, and leave on procedure exits. Managed
copies prepare a new independent value before publishing it. Managed access
helpers synchronize reference publication with collection; emitted scalar
loads/stores preserve nontearing access, with atomic i8 width/ordering/alignment
assertions retained in the core suite. This is memory-safety machinery, not
permission for coherent unsynchronized mutation of a shared user value.

The qualified v2 surface remains one-dimensional, with signed Long index/count
arguments and checked bounds/allocation arithmetic. TryResize uses a zero-based
count. Invalid element access returns a rooted neutral fallback with Err 9.
This does not qualify the complete language's ranks or index-width surface.

## Explicit storage bindings

These role strings use the existing intrinsic-attribute grammar. Names below
are illustrative; a declaration's spelling never selects its implementation.
`T` in the table means the same concrete supported element type in that
declaration, not new generic source syntax. Every declaration is a Function
with one matching `Attribute Name.UBE_Primitive = "role"` and `End Function`.

| Role | Exact signature |
|---|---|
| `Array.Length` | `(ByRef Values() As T) As Long` |
| `Array.TryResize` | `(ByRef Values() As T, ByVal Count As Long, ByVal Preserve As Boolean) As Boolean` |
| `Memory.Collect` | `() As Long` |
| `Array.TryCopy` | `(ByRef Destination() As T, ByRef Source() As T) As Boolean` |
| `Memory.CopyBytes` | `(ByRef Source() As Byte, ByVal SourceStart As Long, ByRef Destination() As Byte, ByVal DestinationStart As Long, ByVal Count As Long) As Boolean` |

Length returns zero for a default array. Resize/copy return fresh Boolean
status, preserve the old destination on failure, set Err 7 after unsuccessful
collection/retry and preserve stale Err on success. CopyBytes uses zero-based
payload offsets, validates the entire range before writes and handles overlap
as original-input byte movement without allocating; invalid arguments/ranges
return False with Err 5/9. Collect requests synchronous collection and returns
the existing cleanup-work status. No raw address or arbitrary foreign symbol
becomes available. Value.Pack/Value.Unpack remain separately qualified only for
opaque Byte/Integer/Long scalar representations.

## Exact child reports and remaining work

| Suite | Report below `bootstrap/out/` | SHA-256 |
|---|---|---|
| Managed values | `managed-values/aaee5323fde845e5a57b93f69f726850/report.json` | `6B1AC968DADFE58D59493180A379684BCA4B5A163569A431A3203F00A62DA534` |
| Managed substrate | `managed-storage/272a226b4a85452a858fd35f36bd0f59/report.json` | `24A309F9F26B1665155D87658A050363A3AA04471B23B9B58F44479008B4AB8E` |
| UTF-8 decoder | `utf8/1686c49b69bb4694b7ae4d22615830af/report.json` | `DEEA571920C56D78D3B92EBE64606F5C9562F93A1D561B89E2BCF1A1224CD684` |

`bootstrap/out/audit-managed-gate.ps1` rechecked all 276 merged assertions,
136 immutable core assertions, 199 source identities, final artifacts, child
inputs/report hashes and their exact source-manifest/compiler bindings.
`rtk proxy git -c core.safecrlf=false diff --check` also passed at that handoff.

The decoder's unchanged ordinary source body retains its eight assertions and
measured zero-allocation result. Its full native source envelope and the
UBECore Library manifest remain unbuilt. The separately documented
[ByteBuffer](BYTE-BUFFER-CONTRACT.md) source body passes 13 functional checks;
allocation/copy/zeroing budgets, failure injection and independent-instance
concurrency qualification are still pending at this snapshot. No immutable
Text type, builtin String replacement, fresh v3 production scaffold or compiler
consumer integration is established by these managed-foundation tests.

The ten earlier failed storage obligations in
[BYTE-TEXT-EVIDENCE.md](BYTE-TEXT-EVIDENCE.md) retain their original exact tool
identities and failed results. The new acceptance proof supersedes those
capability limits for the recorded new tool; it does not rewrite history.
