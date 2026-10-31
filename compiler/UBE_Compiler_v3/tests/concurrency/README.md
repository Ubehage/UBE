# Source concurrency acceptance

Run from the repository root:

```powershell
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tools/check-concurrency.ps1
```

A successful report must say `success:true`, `qualified:true`, contain both
accepted source-built stages and identical raw LLVM, and retain unchanged input
identities. Diagnostic modes never qualify compiler concurrency. Reports and
generated inputs/programs live under `bootstrap/out/source-set-proof/`.

The production contract is [CONCURRENCY-CONSUMER.md](../../CONCURRENCY-CONSUMER.md).
The gate compiles the intact compiler-owned coordinator and scanner/parser with
test entries. All work admission and compiler algorithms execute in UBE. C adds
assertions, observations, bounded schedule controls and fault injection.

The corpus contains every current production MODULE in the compiler and UBECore,
an empty module, BOM/CRLF/non-ASCII bytes, nested syntax, four growing functions,
and independent rejected/deferred fixtures. CLASS-body parsing remains deferred;
the bootstrap's field-only reference classes do not expand v3 grammar coverage.

Each stage must pass:

- Two complete 1/2/4-worker runs, ordered graph/span/source association, complete
  tokens/failure/metrics equality, actual worker identities and interleaved work.
- A serialized-work negative control that has four entered workers but zero
  operation overlap, and reversed actual native completion of the first batch.
- Required source-intake copy positive control, zero worker source-payload copy,
  exact reference captures, growing-case executed costs and exact retained input
  and completed-result GC payload. Every actual root admission and payload
  allocation is observed, with predefined bounds checked rather than adjusted.
- Actual shared-token UBE parser workers and independent simultaneous UBE
  coordinators, each with private publication/cancellation/results. The shared
  token test retains the caller's published owner and makes no sole-owner or
  separate operation-overlap claim.
- Canonical rejected/deferred failures at all budgets, including reversed drain,
  domain/empty/token/node/pending/depth boundaries, cancellation before dispatch,
  during admission/work, before publication and after publication admission.
- Actual allocator, native start/wait, publication-root/storage and worker-root
  admission denial. A rejected source Sub gets no ID and executes no body.
  Failures retain the entire earlier full-corpus graph, owners and original bytes.
- Corrupted graph comparison rejection, drained native records/captures/handles,
  and zero residual test-owned roots and GC payload after final collection.

Failure/budget tests use focused four-source inputs while retaining the full
earlier published corpus. This isolates each boundary without duplicating the
full performance workload for every injected fault. Publication admission's
successful cancellation control still commits the full corpus.

Timing includes instrumentation. Reports separately count and time collector
critical-section acquisition/wait/hold, actual work CPU, elapsed time, GC payload,
allocation requests and copies. OS peak memory includes assertion snapshots and
deliberate root pressure; it is not compiler-only resident memory. Native stack,
event, CRT and allocator costs are separate from measured GC payload. Passing
correctness does not establish production speedup or broad thread/class semantics.
