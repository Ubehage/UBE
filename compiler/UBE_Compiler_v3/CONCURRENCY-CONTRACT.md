# Bounded compiler-concurrency acceptance

Date: 2026-10-31.

Status: the owner requested a goal to complete this contract and its real
UBE-driven proof. Behavioral acceptance below follows that approved objective.
The owner approved the existing-language reference/thread route below (option 1).
The bounded implementation contract is in
[CONCURRENCY-BOOTSTRAP.md](CONCURRENCY-BOOTSTRAP.md); its facilities still require
independent qualification before the compiler consumer can rely on them.
This is not completed compiler-concurrency qualification.

## Authority and bounded consumer

The existing [development plan](../../project-docs/Development-Plan.md),
[language specification](../../lang-doc/language-spec.md),
[threading contract](../../lang-doc/threading.md),
[managed-memory contract](../../lang-doc/managed-memory.md) and adopted library
boundaries remain authoritative. The current source/scanner/parser contracts
define the work a worker performs and its original spans/first failure.

One invocation processes an ordered, bounded collection of native MODULE source
units in the already qualified syntax scope. The caller supplies a worker budget
of 1, 2 or 4 for acceptance. Inputs remain immutable during work; each worker owns
its pending tokens, parser state and result. The same work operations serve every
budget. This proof is not semantic checking, literal conversion, full grammar,
conditional selection, an IDE or complete UBE threading conformance.

Normal project/source policy stays in the compiler. Any required `.UBE` source/
direct-reference loading acquires its own bounded input expectations. UBECore
contains reusable thread/storage mechanisms, not source documents, tokens, syntax
nodes, project ordering or compiler diagnostic selection.

## Diagnosed prerequisites

[CONCURRENCY-EVIDENCE.md](CONCURRENCY-EVIDENCE.md) records exact paired-stage
probes against the accepted source-built v2 cohort:

- An ordinary scalar call prints 7 through both stages.
- `CallNew RunWorker(7)` compiles and exits successfully but emits no worker call
  or native thread-start call and prints nothing. Unsupported work is silently
  omitted. This needs a focused bootstrap correction and a retained regression.
- An array-containing record passed ByVal is an independent value. Actual UBE
  procedure/runtime observations copy 1, 64, 1024 and 16384 payload bytes for
  those respective array lengths. Caller bytes, incoming Err and cleanup pass.
- The minimal `Object` parameter probe rejects with UBE3213. `.cls` source is
  rejected by the bootstrap project's `.bas`-only path check. These probes do
  not qualify reference sharing or class implementation.
- Module array storage is not available as a shortcut: its use diagnoses an
  undeclared assignment target. A global compiler-context registry is not
  selected as a workaround.

The C runtime's existing thread functions are implementation candidates to audit,
not evidence that UBE can invoke them correctly or that capture/GC is safe.
Native C worker tests of independent library/parser calls remain component proof.

## Owner-approved prerequisite route

Approved route: qualify the smallest necessary portions of **existing UBE
reference and thread semantics** in source-built v2. This means real `CallNew`,
completion/cancellation support, and a bounded reference-class path sufficient
to hold the compiler's source-work context. Ordinary arrays/records keep their
independent value-copy rules. Object captures retain identity and lifetime.
No asynchronous ByRef escape, raw-address API or special array-alias rule is
introduced.

For example, a compiler-owned reference context can contain one immutable
`SourceDocument` and exclusive worker output. A callback of the conceptual form
`Sub ProcessSourceWork(ByVal Work As SourceWork)` captures one object reference,
not a deep copy of every array in the context. `SourceWork` and this callback name
are proposed compiler-local identifiers, not new UBECore public APIs or an adopted
layout. The owner initializes inputs before start; the worker alone writes output;
the coordinator observes completed output after the required join/publication
ordering. The class and captured reference keep the source alive through drain.

This route needs a reviewed bounded implementation contract for field-only
reference storage, allocation/neutral access, exact passing/rooting, source-kind
admission and thread capture. Full class methods/interfaces/events/lifecycle and
designer support must not be silently claimed. Missing features diagnose or defer.
Every necessary extension remains ordinary existing UBE syntax/semantics; the
bootstrap compiler's own source stays in the proven seed subset.

An alternative managed immutable-sharing mechanism would require a separate
owner-approved representation/lifecycle contract. The adopted native-value proof
currently covers scalar representations; it does not authorize new managed opaque
types. Changing record ByVal into aliasing is not an alternative.

Before production changes, record its precise API/layout contracts.
The focused silent-omission correction does not depend on choosing a reference
representation; it can be implemented and tested independently.

## Ownership and publication requirements

| Value/resource | Ownership before dispatch | During execution | After completion/failure |
| --- | --- | --- | --- |
| Ordered source set and source identities | Coordinator/caller | Immutable views; all required owners rooted/retained | Retained until all admitted work drains |
| Individual original bytes | One explicit source owner | Shared read-only under the approved reference mechanism | Remain alive for every published span |
| Task/capture metadata | Coordinator prepares complete metadata | Exactly one admitted task owns each mutable output | Reclaimed only after safe completion/drain |
| Scanner tokens and parser pending state | Worker prepares privately | Single mutable owner; no whole-project state transport | Publish complete private result or reclaim it |
| Complete result set | Existing caller output | Remains unchanged while new work is pending | Atomically publish only the complete successful replacement |
| Native thread/wait/coordination resources | Explicit creating owner | One bounded budget, documented handoff and cancellation | Drain and release on every path |

No task starts before its capture, roots and source-owner lifetime are established.
Successful wait/publication supplies the normative visibility edge. Cancellation
stops new admission, requests cooperative stop where needed, drains admitted work
and releases private partial results before input owners can be released. A wait
failure is not proof that a worker has finished.

Failure returns fresh per-call status and a structured disposition independent of
stale Err. Worker Err is thread-local; errors cross to the coordinator only through
the agreed result/status contract. Existing syntax/deferred/domain/budget/storage
classifications remain distinct. Root/admission failure cannot silently turn a
source into an empty successful result.

## Determinism and budget

The canonical source order is the caller's qualified manifest/source order.
Source identity, result association and first reported source error never depend
on worker completion order. Each worker preserves its parser's first diagnostic.
Any tie-breaking needed within a source retains that source's existing contract;
this document does not create a new public diagnostic ABI.

At most the selected budget of compiler work operations may run concurrently.
An empty source set and budgets larger than the source count have explicit
results. Thread creation failure stops additional admission and drains work
already started. Nested work shares the same budget; no private executor/pool is
created by scanner, parser, semantic work or a library helper.

Work is a source unit, not a fresh compilation of the whole project. No per-worker
project copy, whole-model serialization, subprocess compiler restart, shared
mutable global syntax arena or global lock covering compiler work is permitted.
Short substrate synchronization must be measured separately from work itself.

## Independent acceptance fixed before implementation

| Family | Required assertions |
| --- | --- |
| Real execution | Actual UBE coordinator/callback and intact source/scanner/parser bodies; budgets 1, 2 and 4; observed overlapping work with distinct native/UBE thread identities, not merely a jobs option or faster elapsed time |
| Syntax results | Independent success/reject/deferred sources, unequal sizes, empty input, original BOM/CRLF/non-ASCII positions, and all 16 current source modules within their syntax scope |
| Result identity | Full graph/kind/ordered children/spans/source identity comparisons; deterministic source association and first failure across repeated/reversed completion schedules |
| Capture/sharing | Actual copy/allocation observations at growing source sizes; source owners retained throughout capture/execution/drain; no whole-source/model duplication for each worker |
| Value semantics | ByVal array/record controls still copy independently; reference capture preserves identity without exposing a managed address |
| Failure | Persistent runtime allocation denial, actual root pressure, thread-start/wait admission failure and source/node/pending/depth budget boundaries; complete old output and original bytes retained |
| Cancellation | Before dispatch, while admitting, during work and before publication; no new admission after stop, no abandoned worker, lost output, leaked root/handle or freed live input |
| Errors | Stale Err before success/failure, TLS isolation, fresh status, correct neutral/admission outcomes and deterministic cross-thread error publication |
| Cleanup | Zero residual test-owned roots/live payload/handles after all workers drain; repeated invocations and independent simultaneous contexts do not share mutable state |
| Controls | Deliberately corrupted comparison results are rejected; real byte-copy/worker-observation positive controls cannot report fabricated zeros |
| Reproduction | Both accepted source-built v2 stages, identical raw compiler/proof LLVM where emitted, recorded exact tool/input/artifact identities and all applicable prior gates |

Existing per-source scanner/parser copy/work constants continue to apply to actual
worker work. Before coding the coordinator/representation, record concrete
additional capture, publication, workspace, root and memory bounds from the chosen
layout. Input-size formulas are expectations, not executed-operation counters.
Growing inputs must separate shared storage, per-worker workspace, retained old
output and completed new output. Source payload copied by task capture must be
zero for the approved immutable reference route; required initial source intake
and ordinary result publication are recorded separately.

Wall time/CPU/memory samples accompany actual operation/copy observations. They
must expose contention/overhead; success is not inferred from a speedup alone.
Neither acceptance thresholds nor supported scope may be relaxed after a slow or
failing implementation is observed.

## Exact next action

The current qualification outcome, exact source/tool identities and next
authorized action are recorded in [CONCURRENCY-EVIDENCE.md](CONCURRENCY-EVIDENCE.md).
Prerequisites and the compiler consumer each require their own complete gates;
a diagnostic run never substitutes for either. Semantic/backend expansion
remains outside this bounded contract and goal.
