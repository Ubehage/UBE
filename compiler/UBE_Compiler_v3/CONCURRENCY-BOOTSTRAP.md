# Bounded reference and thread prerequisites

Date: 2026-10-31. Implementation contract, not completed qualification.
The owner approved qualifying existing UBE classes and CallNew, wait and
cancellation for the [bounded compiler consumer](CONCURRENCY-CONTRACT.md).
This specifies the implementation boundary before adding those facilities.
Normative language, threading and managed-memory contracts remain authoritative.

## Reference scope and names

Source-built v2 admits native `UBE SOURCE 1 CLASS` units in `.cls` files named
by ordinary `.UBE` Source entries. Original bytes and metadata identity remain
intact. A class has public explicitly typed instance fields, including records,
dynamic arrays and other class references. `Dim x As ClassName`, explicit
`Set x = New ClassName`, reference assignment, `Nothing`, and identity `Is`
comparisons supply the required bounded path. Reference ByVal parameters retain
identity; ByRef parameters still borrow the caller's reference slot for the call.
Arrays and inline records retain independent value-copy semantics, including
when their elements/fields contain references (those identities remain shared).

Methods, properties, events, interfaces, default instances, As New locals,
constructors/finalizers and designer/lifecycle behavior are outside this bounded
bootstrap path and must diagnose rather than silently execute differently.
This does not change the fresh v3 parser's deferred CLASS-body contract.

Compiler-private `TypeDeclarationSyntax` gains a declared identity and reference
classification. Records retain their current type IDs and layouts; class
reference IDs occupy a disjoint range and lower to `ptr`. Their value layout is
the existing shared-reference kind 3 with one root at offset zero. Class payload
is a distinct aggregate using the existing typed field layouts and root offsets.
Cycles through references are permitted; recursive inline values still reject.
No managed address becomes a UBE value or public library representation.

Every local, parameter, expression temporary and result containing a reference
uses the existing checked root admission/cleanup discipline. Managed results use
the caller-rooted hidden result ABI. New publishes into an already rooted slot
while holding only the collector's short allocation/publication lock. Allocation
failure yields Nothing and a fresh error without exposing an unrooted object.
Reference reads/writes use existing synchronized value operations; arbitrary user
code never executes under the collector lock. Neutral member access must return
neutral data and an error without dereferencing null or mutating shared fallback
storage. A failed member access suppresses its enclosing write/call as required.

## Thread scope and names

CallNew targets a statically resolved Sub with explicit ByVal parameters. The
initial admitted captures are Boolean, Byte, Integer, Long, LongLong, Double and
class references; builtin String and other capture kinds
diagnose until their independent value capture is qualified. Arguments evaluate
once from left to right on the creator. The returned LongLong ID is positive on
admission and zero on failure. It is never a native handle or reused ID. Statement
use and expression use share the same lowering; Functions and asynchronous ByRef
parameters reject. No source callback is replaced by a C worker implementation.

The compiler emits a typed capture aggregate, root offsets and callback, and uses
the runtime's existing `ube_thread_capture_allocate(size, slot_count, offsets)`
and matching destroy operation. This explicitly owned native aggregate registers
its managed pointer slots before dispatch; it remains rooted from preparation
through native admission and until completion cleanup. Reference capture copies pointers only,
never source arrays or their records. A worker cannot observe incomplete capture.
Admission includes worker TLS and root setup: failure must return zero, execute
no user body and release the capture exactly once. Root failure inside a later
procedure returns through controlled cleanup and is reported in work status.

The bootstrap keeps its existing native callback ABI and adds a checked start
entry for compiler-emitted callbacks. A worker record has creator/worker lifetime
references and a readiness event in addition to completion/stop events. Only
successful TLS and Sub-prologue root/value admission issues its positive ID;
failed reservations do not become issued identifiers. The compiler-generated
adapter invokes the actual Sub, whose admission observer acknowledges after its
checked prologue. A failed prologue returns without user code and reports rejection.
The creator retains the record/events until it observes acceptance or completion;
the worker retains them through capture destruction and completion publication.
This adds one fixed readiness handle and fixed record fields per active admission,
not source-sized storage or another independently allocated task model.

The portable library module `Threads.bas` declares the following explicit fresh
status primitives. Each returns Boolean; True means the request was processed,
not necessarily completed or alive. On False it records a fresh error and
preserves the ByRef output. On True it preserves incoming Err. Output Boolean
uses UBE's one-byte storage. Inputs/outputs are borrowed only for the call.

| Declaration | Primitive role | Meaning on True |
| --- | --- | --- |
| `TryCurrentThreadId(ByRef Id As LongLong)` | `Thread.TryCurrentId` | Positive program thread ID |
| `TryThreadIsAlive(ByVal Id As LongLong, ByRef Alive As Boolean)` | `Thread.TryIsAlive` | Alive is a fresh observation |
| `TryThreadRequestStop(ByVal Id As LongLong, ByRef Requested As Boolean)` | `Thread.TryRequestStop` | Requested says whether a live worker recorded the sticky request |
| `TryThreadStopRequested(ByRef Requested As Boolean)` | `Thread.TryStopRequested` | Current worker's sticky request |
| `TryThreadWait(ByVal Id As LongLong, ByVal Timeout As LongLong, ByRef Completed As Boolean)` | `Thread.TryWait` | Completed distinguishes completion from timeout/cooperative interruption |
| `TryThreadYield()` | `Thread.TryYield` | Scheduling hint issued |

Wait timeout is milliseconds, -1 for indefinite; invalid IDs, self-wait and
invalid timeouts fail. A successful Completed=True wait supplies the normative
visibility edge. False or Completed=False never permits freeing live captures.
Cancellation requests do not terminate workers. These fresh Try facilities are
the initial consumer surface; normative ThreadWait's optional-argument wrapper
and the rest of the full library API remain later work, without altered
signatures. Scheduling, drain policy and source ordering stay ordinary UBE in
the compiler. No generic executor or second worker budget is introduced.

Bindings use checked signature metadata, not privileged source function names.
Minimal Windows adapters belong in `std-lib/src/win-lib/thread_primitives.c`;
the bootstrap runtime supplies existing TLS, registry and GC mechanisms.
Boolean-status C adapters use int32_t returns and uint8_t output slots, with
explicit ABI assertions. Fresh status must use a new error occurrence/revision
or an internal structured result, never a stale Err.Number comparison.

## Costs and acceptance before use

On the current x64 target a reference occupies eight bytes. A capture containing
one SourceWork reference therefore has eight payload bytes, one managed pointer
slot and one aggregate root registration;
capture source-payload copies must be exactly zero at every tested source size.
Each admitted worker owns one capture and one bounded native thread record;
no admission adds a copy of any SourceDocument/token/project array. Procedure
workspace and completed outputs use the existing checked scanner/parser bounds;
the coordinator's ordered handles/context references grow with source count,
active captures/native records with the selected budget, and source byte storage
is independent of that budget. Root registration counts and runtime overhead
are observed separately; fixed bounds must be recorded before consumer coding.

Independent paired-stage cases must cover reference aliasing and reassignment,
Nothing/identity, recursive references, array/record copies with reference leaves,
GC during calls/results/capture, denied allocation/root admission, neutral access,
invalid class constructs and unchanged original source positions. Thread cases
must prove actual native execution, left-to-right capture, TLS isolation,
start/root/wait failures, cancellation/drain, lifetime after creator scope exit,
and zero residual captures/roots/handles. The existing 501-check bootstrap gate
and parser/source gates must pass again for the final source/tool cohort.
Only then may the full 1/2/4-worker acceptance be claimed.
