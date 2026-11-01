# Root registry synchronization proposal

Status: **owner-approved experiment adopted and qualified on 2026-11-01**.
Current cohort a732 passes 785 source assertions, all seven retained gates and
both complete performance sessions under the revised owner policy. The original
numerical target misses remain recorded. See the current accepted qualification
in [frontend evidence](FRONTEND-PERFORMANCE-EVIDENCE.md). This is a scoped dependency of the existing parallel
frontend performance item, not a new compiler generation or subsystem.

## Original problem and evidence

The qualified production cohort49fa passes692 source checks and all seven
retained correctness gates. Both complete performance sessions fail the required
real/balanced parallel speedups. All serial and small-input guards pass. The
original and expanded baselines remain frozen.

Focused current-code experiments identify shared root bookkeeping as a major
cost. Removing only proven unused argument-value slots leaves351,827 root
registrations and703,654 root-lock operations out of1,241,301 total GC-lock
operations. An immediate primitive array-read experiment then removes139,937
registrations, preserves complete results and copied work, and passes its
native lifetime/exclusion proof. Its one/two/four-worker medians are still
0.037059/0.040196/0.068588 seconds. It does not pass scaling and remains ignored.

Earlier address buckets reduce root-list traversal but retain the single global
exclusive mutex. Grouping, waiting and spelling-cache experiments also fail
parallel scaling. These results justify testing synchronization directly rather
than composing more failed optimizations. Exact commands, identities, results
and limitations are in [the performance evidence](FRONTEND-PERFORMANCE-EVIDENCE.md).
No timing experiment is a substitute for the complete performance gate.

## Approved decision

The owner approved one bounded experiment in which ordinary root metadata operations use
locks selected by the **root storage address**, while collection and other
operations that inspect the complete registry freeze those locks under the
existing heap GC lock. Approval permits the ignored prototype and its tests;
production adoption additionally requires all gates below to pass.

Address ownership accommodates a root admitted by a thread creator and removed
by its worker, including existing CallNew captures. There is no new thread-local
root registry, thread-registration lifecycle, source policy or worker pool.

## Required contract

- Preserve the32-byte root representation and existing APIs, precise slot
  offsets, caller-retained ByRef rule, global1,048,576-root capacity, successful
  and failed admission behavior, neutral results and stale/TLS Err behavior.
- A bucket is selected using the numeric root-storage address. Leaving an
  unregistered, poisoned or inaccessible address compares registered addresses
  before dereferencing the sought storage. Keep non-LIFO and cross-thread leave.
  Existing unsupported duplicate registration is not silently made a new API.
- Layout-root admission's ordinary metadata path and root leave use their bucket
  lock without acquiring the heap GC lock. During collection, foreign admissions
  wait outside all bucket locks and recheck the gate under their bucket before
  committing. This preserves exclusion between root snapshot and sweep after
  the snapshot freeze is released. Record the collector's native thread ID
  atomically before publishing collecting=true, and clear it after
  collecting=false; existing recursive collector callbacks retain admission.
  Nested collection rejection must not clear the outer collector identity.
  No new TLS registry or allocator-backed per-thread depth state is required.
  No heap lookup, allocation, collection,
  user callback or attempt to acquire that heap lock may occur while holding
  only a bucket lock. Capacity admission/decrement must be atomic and reconciled
  with actual registration; no partially published root may be traced. Specify
  admission's linearization against shutdown closure. Failed admission leaves
  root storage untouched; frozen capacity accounting equals linked membership,
  and concurrent buckets never admit more than the existing global limit.
- Legacy scalar-root admission still performs its existing heap publication
  bookkeeping. It retains the heap lock and then takes the applicable bucket
  lock. Do not remove pending-publication behavior to improve timings.
- The only permitted combined lock order is heap GC lock, then bucket locks in
  increasing index order; release in reverse order. No bucket-to-heap path or
  lock-order cycle is allowed, including recursive runtime calls and failures.
- Root tracing, alias clearing, shutdown and every other complete-registry
  consumer must be inventoried. Each holds the necessary registry freeze for
  the full interval in which root storage/slots must remain valid. Trace or
  allocation failure unwinds every lock. Shutdown prevents new admission while
  preserving valid cleanup. Acquire all relevant bucket locks simultaneously
  before the first whole-registry slot read or clear; scanning and releasing
  buckets one at a time is insufficient. Identify each exact snapshot/alias-write
  interval. Release the new bucket locks before arbitrary finalizers, callbacks
  or worker waits, preserving the existing heap-lock contract and recursive
  runtime behavior. No extension of a registry freeze across user work is allowed.
- Array access, barriers, allocation, tracing and heap ownership retain their
  existing synchronization. This does not authorize weaker managed-value reads,
  a different collector, safepoints, hazard pointers or a new public native ABI.
- Record the exact fixed bucket/lock count, initialization behavior, collision
  worst case and static bytes before coding. No new per-operation allocation,
  dependency or unbounded retained metadata is permitted. Compiler policy and
  ordinary reusable algorithms remain in UBE; this changes only the existing
  bootstrap runtime's irreducible root/collector synchronization boundary.

## Finite experiment and acceptance gates

1. Write the complete shared-state and lock-order inventory, including all
   registry consumers, global capacity/shutdown counters and legacy publication.
   Independently review it before running the prototype.
2. Use an ignored runtime copy and exact matched current frontend LLVM. Change
   only registry representation/metadata synchronization and required registry
   consumers. Preserve root counts, all non-root instructions, source snapshots,
   repetitions, complete-result reference, toolchain and the same wait policy.
   Do not add spelling caches, root grouping or scalar-read fusion to this test.
3. Retain real full-capacity, partial-admission/recovery, absent/no-access leave,
   forced GC/trace failure, alias clearing, capture, component and shutdown tests.
   Add deterministic overlapping root admission/removal and collector-freeze
   cases, cross-thread capture cleanup, capacity races at the actual limit,
   recursive lock paths and safe negative controls that detect missing freeze
   or reversed lock order. No intentional freed-storage dereference is needed.
4. Run complete frontend result/copy/root/payload/drain comparisons at budgets
   1/2/4 before matched small uninstrumented timing trials. Report failed scaling
   honestly and stop this candidate if it cannot justify full qualification.
5. Only after the focused evidence and independent review pass, integrate the
   concrete change with maintained tests and run the complete fresh source and
   retained gates. Run both unchanged full timing sessions: at least seven
   interleaved trials per budget/corpus, useful repeatable real and balanced gains
   with actual speedups reported against the1.5x/two-worker and2x/four-worker
   engineering targets, serial <=1.05 of both applicable frozen guards,
   small overhead <=1.10, with every resource/failure/lifetime requirement.

The goal remains active until these existing acceptance conditions pass. This
proposal does not authorize another push or a baseline/threshold reset.
The owner separately relaxed only the parallel numerical targets on2026-11-01:
close results are acceptable for a start. The pinned implementation contract
predates that revision; its synchronization invariants remain unchanged, while
acceptance follows PERFORMANCE-ACCEPTANCE.md and the revised development plan.
The pinned measurement contract remains unchanged. No other gate is waived.

## Read-only inventory and review

The initial inventory uses current `runtime/bootstrap_runtime.c`: root record
at102, registry head/count at173/176, recursive heap lock at1111, root tracing
at1331, collection at1401, component alias walk at1811, scalar/layout admission
at2800/2820, leave at2840, capture lifecycle at2868 and shutdown detach at3424.
Collection calls finalizers at1433, so a freeze around the whole collection
function would violate the callback exclusion above. Each consumer needs its
own bounded freeze interval. These anchors identify existing code to audit;
they do not establish that a synchronization implementation is safe.

Two independent read-only reviews found no remaining essential contract
correction after the simultaneous-freeze, callback and capacity/shutdown rules
were made explicit. The detailed audit is
`bootstrap/out/root-synchronization-review/FINDINGS.md`, SHA-256
`F2E0ABA95E0C4A49350199E658B2E97D8CD632E2A5AF2A0B2B33446611ACBB63`;
its handoff SHA-256 is
`032A08AE9DDDFE0D726E85C018CD204025583403BA82443F2381DD8AD7DAD485`.
No synchronization prototype or native test had been performed at approval.
The subsequent shared-state/lock-order and fixed-storage contract, independent
review, native prototype and production adoption are now complete. The following
records preserve that sequence; current acceptance is linked above.

That implementation contract is now written in
`bootstrap/out/root-registry-sync/CONTRACT.md`, SHA-256
`D713375144E5BB6CA69BA3D1EAF412F8E2E03F210E3B6666E04BEEA7F9B26DBC`.
Root and independent review cleared it subject to its compile-only target layout
assertions. It fixes4,096 heads/64 recursive stripes, an atomic capacity/closure
transaction, collector-owner admission gating and permanent uniform heap-lock
fallback after partial lock-initialization failure. The calculated metadata
increase is36,912 static bytes. The pinned-target compile-only gate now passes
all16 static assertions, retaining metadata size36,928 bytes and root size32:
`bootstrap/out/root-registry-sync/layout/15ca4741d7e64cad92221fd9ffbbcc60/report.json`.
The810-byte object SHA-256 is
`22F471B43FDEB7045E8B5E5E9B1C89CE6F995A6861BB6ABDA1B705220B2F2953`.
No runtime behavior is verified by that compile-only check. Independent
`TEST-PLAN.md` in that directory has SHA-256
`67B67A6191C9163CE3FE1718640F75F72D43669F910411C4FD29ECF135782D26`.
No prototype safety or performance result is claimed by these contract reviews.
The frozen layout report originally labeled its count17; counting the compiled
source gives16. All16 assertions passed; the frozen report is retained with this
explicit count correction.

## Approval boundary

[AGENTS.md](../../AGENTS.md) says: "Ask the repository owner for explicit
approval before making a fundamental, architectural, or system-wide change."
Splitting the runtime's root/collector synchronization is such a change. The
earlier caller-retained ByRef approval did not cover it. The owner separately
approved this bounded experiment on2026-11-01. Production adoption followed the
scoped experiment and complete adoption gates; it changes neither language
semantics nor the public root ABI.
