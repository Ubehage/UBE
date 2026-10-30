# RP7 implementation contract

This is the resumable engineering checklist for Release Preview 7. Normative
behavior remains in `../../lang-doc/`; this file maps that behavior to compiler,
linked-support, source-library, and executable-test work.

RP7 is complete only when every inherited RP1-RP6 gate still passes, the
preserved v2 compiler builds the same v3 source, the self-built compiler repeats
the build deterministically, and the native RP7 corpus passes through both
compiler stages.

Status: complete and verified on 2026-10-23.

## Existing baseline

- RP6 provides verified typed IR, precise managed metadata, automatic tracing
  collection, managed values, classes/interfaces, module lifecycle, project
  references, a seven-module `UBECore` slice, and a frozen foreign ownership
  ABI.
- Grammar already recognizes `On Error`, `Resume`, `CallNew`, `SyncLock`,
  `Event`, `RaiseEvent`, `WithEvents`, `Load`, and `Unload` forms.
- IR already reserves error/resume edge kinds and cleanup-depth transitions,
  but RP7 must make them executable and verify their control-flow invariants.
- Default forms are created on their first bare value reference. After an
  accepted unload, the slot records the user's decision and stays `Nothing`;
  only explicit `Load FormName` creates the next default identity.

## Slice A: thread-local error state and structured recovery

- [x] Add linked-support thread registration and independent `Err` records with
  stable number, description, source, and explicit clear operations.
- [x] Lower recoverable failures to neutral results plus status publication;
  successful operations must not clear an earlier error.
- [x] Implement procedure-local `On Error GoTo`, `On Error Resume Next`,
  `On Error GoTo 0`, `Resume`, `Resume Next`, and `Resume label` without native
  exception unwinding.
- [x] Route every handler/resume/return/exit edge through verified cleanup and
  monitor-release depths.
- [x] Add bounded recursion admission and controlled fatal handling for unsafe
  resource exhaustion that cannot reach ordinary recovery.

Gate A: native fixtures prove per-thread isolation, neutral failure values,
handler selection, every Resume form, nested calls, disabled handlers, cleanup,
and controlled unrecoverable diagnostics.

## Slice B: thread creation and lifecycle

- [x] Add typed IR and LLVM lowering for `CallNew` with a statically resolved
  Sub target, required `ByVal` parameters, and a `LongLong` result.
- [x] Snapshot scalar and managed arguments left to right before publication;
  copy value types independently and retain shared object identity.
- [x] Implement monotonically increasing non-recycled IDs, current ID, alive,
  cooperative stop, stop observation, timeout-aware wait, and yield.
- [x] Release completed native handles, captured arguments, roots, wait state,
  and transient `Err` while retaining bounded completion identity.
- [x] Enforce shutdown admission and the live-thread/active-event-source rule.

Gate B: repeated native fixtures cover ignored IDs, argument order and copies,
shared objects, multiple waiters, cancellation wakeup, self-wait, stale IDs,
creation failure, cleanup, and shutdown admission.

## Slice C: synchronization and coordination

- [x] Lower `SyncLock` to reentrant object monitors acquired and released on
  every structured/error/cancellation edge.
- [x] Provide sequentially consistent `AtomicBoolean`, `AtomicLong`,
  `AtomicLongLong`, and `AtomicObject` operations.
- [x] Provide documented `ThreadEvent`, `Semaphore`, and FIFO `MessageQueue`
  modules/classes with timeout, cancellation, invalid-object, and unload rules.
- [x] Keep collector, handle-table, dispatcher, queue, and finalizer locks away
  from arbitrary UBE callbacks.
- [x] Verify non-tearing publication, barriers, monitor roots, fairness where
  specified, and concurrency-safe collection.

Gate C: stress tests cover reentrant monitors, contended increments, atomic
compare/exchange, auto/manual events, semaphore bounds, FIFO messages, multiple
waiters, cancellation, destruction, and collection during coordination.

## Slice D: events and subscriptions

- [x] Create semantic Event contracts and validate exact private
  `<WithEvents-field>_<event>` handler signatures.
- [x] Lower `WithEvents` assignment to ordered disconnect/connect operations
  while retaining strong managed edges and preventing stale callbacks.
- [x] Lower `RaiseEvent` to synchronous subscription-order dispatch on the
  raising thread with argument preparation before the first handler.
- [x] Snapshot each invocation's subscription set while honoring removal before
  turn, addition on the next invocation, and identity-wide unload disconnect.
- [x] Support recursive event dispatch until the bounded recursion guard reports
  a controlled error.

Gate D: native fixtures prove zero/one/multiple subscribers, two fields bound to
one source, reassignment, self-removal, addition during dispatch, recursive
raising, handler errors, cross-thread raising, and unloaded-source rejection.

## Slice E: forms, controls, and component lifetime

- [x] Create form/control identities, `Me`, default-form slots, explicit
  instances, and configured startup-form ordering after modules and before
  source `Main`.
- [x] Implement synchronous `Load`, first-load hooks, repeated-load idempotence,
  active-event-source registration, and failed-load rollback.
- [x] Implement cancellable `Form_Unload`/`Control_Unload`, native-state release,
  admission closure, active-call/monitor drain, exact-once termination, and
  identity-wide alias/subscription clearing.
- [x] Keep UI dispatch behind a platform adapter and report direct dispatch-wait
  cycles as controlled failures; source exposes no owner-thread restriction.
- [x] Implement first-reference default-form creation, prevent bare recreation
  after accepted unload, and support explicit `Load FormName` recreation.

Gate E: native fixtures prove startup ordering, explicit/default identities,
load idempotence, cancellation, accepted unload, alias clearing, active-call
drain, event-source liveness, controls requiring a parent, and GC roots.

## Slice F: UBECore and permanent release gates

- [x] Add documented portable modules and target adapters for errors, threads,
  atomics, waits, queues, event-source liveness, and component support only as
  required by the preceding slices.
- [x] Add deterministic failure injection for thread creation, wait bookkeeping,
  dispatcher admission, subscription snapshots, recursion guards, and shutdown.
- [x] Run all RP7 positive, negative, timeout, cancellation, low-memory,
  lifetime, and stress cases through v2-built and self-built compilers.
- [x] Run the complete clean RP1-RP6 suite unchanged and preserve the compiler
  and exact `UBECore` fixed points.
- [x] Record tools, inputs, comparison policy, corpus results, and hashes in
  `bootstrap/out/v3-rp7-build-manifest.json`.
- [x] Update status documents and preserve the verified RP7 executable and
  SHA-256 under `compiler/release-previews/`.

## Verification record

The clean `bootstrap/build.ps1` gate passed on 2026-10-23 with LLVM/Clang
23.1.3 targeting `x86_64-w64-windows-gnu`. It records 49 cross-stage corpus
cases, byte-identical stage-two/stage-three compiler LLVM, matching normalized
COFF objects, and identical `UBECore` LLVM and objects in
`bootstrap/out/v3-rp7-build-manifest.json`. The verified executable and its
SHA-256 are preserved under `compiler/release-previews/`.
