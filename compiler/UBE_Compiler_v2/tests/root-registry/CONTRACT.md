# Root registry regression contract

This gate retains the owner-approved root-registry synchronization proof from
[ROOT-REGISTRY-PROPOSAL.md](../../../UBE_Compiler_v3/ROOT-REGISTRY-PROPOSAL.md).
Run `check.ps1 -SelectionPath <verified-selection.json>`. It verifies the current
selection, pins the current runtime, native dependencies, compiler, manifest,
Clang, Unicode object and all four gate files, and rechecks those identities
after execution. It writes a unique report below `bootstrap/out/root-registry`
and prints `Evidence: <report-path>`. No ignored artifact is an input authority.

The report contains exactly **87 checks**: 86 deterministic cases and safe
negative controls, plus the independent legacy proof requiring exactly
**2,106,814 assertions**. A process timeout, unexpected status, diagnostic,
missing assertion line, changed input or incomplete inventory fails the gate.
Native compilation uses the selected pinned Clang and Unicode object, the
Win64 GNU target, C17 and optimization level O2. Every native child is bounded.
No timing acceptance claim is made by this gate.

## Representation and synchronization obligations

The runtime keeps 32-byte opaque roots, precise offsets, the global capacity of
1,048,576, existing APIs, caller-retained managed ByRef locations/owners and
cross-thread capture destruction. Root-storage addresses select 4,096 heads
and 64 recursive critical-section stripes; lookup compares addresses before
dereferencing registered storage. Absent, uninitialized and inaccessible
nonmember storage must remain safe. Duplicate admission remains unsupported;
the legacy test observes its existing self-cycle without invoking tracing.

The Win64 registry object occupies 36,928 bytes, aligned to 64: stripes at 0,
heads at 4,096, atomic count/closure state at 36,864, INIT_ONCE at 36,872,
collector owner at 36,880 and immutable mode at 36,884. It adds 36,912 static
bytes over the former head and count. Native critical-section internals are
bounded by 64 locks; no claim is made about their implementation allocation.
No per-operation allocation, thread-local registry or new managed ABI exists.

Initialization uses InitializeCriticalSectionEx in ascending stripe order.
Failure at any index destroys every initialized stripe in reverse order and
permanently publishes uniform existing-heap-lock mode; no partial stripe is
exposed. All 64 failure indices run in fresh processes, with ordinary behavior,
cleanup and a full-capacity fallback case retained. Successful locks remain
with the runtime image. The existing heap mutex initialization is unchanged.

Combined lock order is heap first, then all stripes in ascending order; release
stripes in reverse order before releasing heap. Metadata-only layout admission
and leave take one stripe, never heap while holding it. The capacity/closure
word uses atomic reservation; a failed admission leaves caller storage and
prior errors unchanged, except the existing typed RootFull error behavior.
Shutdown closes admission atomically and detaches all roots under full freeze.

Collection publishes its native owner before collecting=1, and clears
collecting before clearing owner on every success/failure path. Foreign layout
admission checks the gate before and after stripe acquisition. On rejection it
releases the stripe, acquires/releases heap with no stripe held, then retries.
Collector-owner recursive callbacks preserve existing recursive behavior.
Legacy scalar admission retains heap ownership and publication behavior.

Exactly three consumers require whole-registry freeze under heap: root tracing
through completion of root-slot worklist publication; component registered-root
alias clearing; and shutdown root detachment. Stripes are released before
heap graph tracing, callbacks/finalizers or native component teardown. Mark
allocation failure unfreezes fully and preserves the prior no-sweep behavior.

## Deterministic schedules and negative controls

The 14 normal cases cover whole freeze, post-snapshot foreign admission,
under-stripe gate recheck, already admitted in-flight entry, root/slot storage
lifetime, cross-thread capture, real capacity, forced shared-load CAS collision,
closure before entry and after reservation, collector-owner recursion and mark
failure, alias clearing, shutdown, and full-capacity heap fallback.

The lifetime case places root and slot in one VirtualAlloc page. Only after
successful leave following snapshot release does it revoke the page; remaining
collection, subsequent GC and absence handling must not access it. The CAS
case gates two distinct stripes after reading the actual capacity-minus-one
count: exactly one wins, one retries with the updated full count and fails
without modifying storage; frozen membership and count must match.

The eight private mutants omit root freeze, collection gate, under-stripe gate
recheck, stripe release before heap wait, actual leave, alias freeze, shutdown
freeze or CAS reservation. Each must terminate at its exact safe guard status
before unsafe traversal/reclamation. Whole-freeze ownership is checked
independently so the collection gate cannot mask a missing freeze. All event
waits are bounded. Hooks and mutants exist only in generated private runtime
copies; production contains no test switch or public observation API.

`legacy-proof.c` independently exercises non-LIFO membership, absent and
inaccessible storage, actual GC and mark allocation denial, precise aliases,
cross-thread captures, the real capacity boundary and recovery, unchanged
rootless scalar admission/error behavior, duplicate preconditions and shutdown.
Its original assertions remain intact; only private registry names were
adapted. Each deterministic process starts with fresh runtime state.
