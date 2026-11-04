# Directed graph component evidence

The bounded implementation in `src/portable/GraphComponents.bas` supports the
reviewed compiler initialization-warning dependency. Its contract is
`GRAPH-COMPONENTS-CONTRACT.md`. Compiler dependency discovery, module semantics,
warning witnesses and delivery remain outside this library algorithm.

```powershell
rtk proxy powershell -NoProfile -File std-lib/tests/graph-components/check.ps1 -DiagnosticOnly
```

Final focused report:
`../bootstrap/out/graph-components/5425f3efa1344f55b5fed0f5007e6865/report.json`.
Exit 0; six groups passed. Each pinned bootstrap stage passed 2,175,517 native
assertions, including real root-registry fill/drain checks. This is not a count
of distinct graph shapes. Both raw LLVM files are 66,687 bytes, SHA-256
`B2D8605B6A74C22131CF86A3689CE5697F8ED24F68AABE3FB984FDFC197FD342`.
Production source SHA-256:
`1A6B09E82B3EA0AA38A0190F85FC2BB9FAA562F8995EDD999E0E25BF8D3B7B4C`.
The report retains source/tool/artifact identities and all 14 terminal commands
(21,641 ms summed process elapsed time).

The native observer covers 540 graph inputs: empty/singleton/disconnected pairs,
every three-vertex directed graph including self edges, and five shapes at each
of 4/8/16/32/64 vertices. Those include chains, whole cycles, dense graphs,
separate components with outgoing edges and deterministic mixed edges. Nonzero
negative and positive matrix payloads both represent edges. An independent
transitive-closure oracle compares every vertex pair for mutual reachability;
it does not reimplement the production two-stack traversal.

Two owners advance interleaved over the same immutable matrix, using different
chunk sizes. Results and component labels match. The gate asserts the exact
`2*N*N + 5*N + 2` normal transition count, zero allowance, exact remaining-work
completion, repeated completed reads, private partial labels and preserved Err.
A test-only wrapper observes every actual traversal entry and compares those
events to each returned work count. Allocator/copy instrumentation observes no
heap allocation or payload copying during advances and result reads. Workspace
array headers independently establish the 20-byte element size and exact N-slot
payload. The owner is 40 bytes on this target.

Failure checks cover negative/oversized/matrix-short dimensions, persistent
allocation denial, beginning on a live owner, invalid allowance, malformed
cursor/stack indexes, premature/out-of-range reads, shortened borrowed matrix,
actual full root-registry denial, and disposal after success or failure. All
owners and roots are released and collected live payload returns to zero.
The caller must retain the unchanged matrix throughout a traversal; no snapshot
or identity cache is hidden in the library.

Two negative controls pass their rejection checks in each stage. Changed labels
fail at independent mutual reachability. Omitting the actual transition event
fails at the counter comparison. Neither control replaces a production body
with a second implementation of its result.

Pending capacity is checked before each real push. Advance returns actual live
and peak pending counts, including failed chunks, so a caller sharing a budget
can reconcile other live owners without reserving N entries speculatively.
Eight-vertex chains and disconnected graphs exercise limits 0 through 9;
disconnected graphs complete with one slot. Instrumented transition entry
observes actual stack depth and independently checks returned peaks. The first
pending extension report 558791a020ba421aba7e1c144df78478 also passed; the final
run above includes bootstrap-compatible assertion descriptions.

## Retained development observations

- `0fe1fdedddb9434fa0bf911a3da0fdb4` failed C compilation because the initial
  observer used a nonexistent array-header `count` field. The corrected observer
  checks the actual lower/upper bounds and element size.
- `5f5604737e2d45a68cd5d23e4709752d` and the narrowed diagnostic
  `4e977cec188b4c0dab37d1acb8548c5c` rejected the empty graph's cleanup. The
  collector returned zero because it performed no collection work, with zero
  roots and zero live bytes. The corrected test invokes collection and asserts
  ownership/live-byte cleanup directly; it does not require work on an empty heap.
- `21d95ecbd8d64345ae87778011c26c2e` passed the initial functional gate. The final
  run above adds independent transition-entry observation and its negative
  control, and charges attempted transitions before entry even on failure.

These tests use current captured library sources and the historical qualified
df158 bootstrap tools. They do not establish a new source-built cohort, compiler
warning extraction or emitted diagnostics. The component is now in the UBECore
manifest and registered in the full
bootstrap gate through tools/check-graph-components.ps1. Its compiler
matrix/witness consumer has a separate focused pass. The newly registered
full bootstrap has not run; production source discovery remains unfinished.
Independent
owners were interleaved, not measured concurrently on separate native threads.
