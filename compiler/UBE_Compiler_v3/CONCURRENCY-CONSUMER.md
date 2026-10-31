# Bounded source-set syntax consumer

Implementation contract fixed before consumer coding. This implements the
owner-approved first concurrency proof in `CONCURRENCY-CONTRACT.md`; it does not
implement semantic checking or a general executor. Bootstrap prerequisite
qualification must finish before this consumer relies on those facilities.

## Domain names and API

`SourceOwner.cls` holds a qualified immutable `Document As SourceDocument` and
nonnegative `SourceId As Long`. One owner retains one original byte snapshot.
Owners may be shared between invocations; a consumer never changes their fields.
`SourceWork.cls` holds one private invocation's source owner, tokens, syntax,
failure, metrics, worker identity, state and four scalar work limits. Every
invocation creates fresh work identities. Publishing those identities cannot
cause a later invocation to mutate an older published result.
`SourceCancellation.cls` contains one Boolean `Requested` with one requesting
owner; coordinator reads use ordinary synchronized UBE scalar semantics.

`SourceParsing.bas` contains compiler-local `ProcessSourceWork` and
`TryParseSources`. Its array length/resize/copy declarations use existing generic
typed storage roles; no new runtime operation or UBECore compiler type is needed.
`ProcessSourceWork(ByVal Work As SourceWork)` is the actual CallNew target.
`TryParseSources` borrows an ordered SourceOwner array, a worker budget, four
scalar scanner/parser limits and a SourceCancellation reference; it returns fresh
Boolean status, a SourceSetFailure and a complete SourceWork-array replacement.
Existing declarations keep their names and signatures.

This bounded API accepts at most 256 sources and worker budgets 1..4. Source IDs
must equal their canonical input indexes; invalid/null owners diagnose before
admission. Documents obey the existing 16 MiB qualified-source contract. Token,
node and pending limits are 0..1048576; depth is 0..256. Zero budgets inside those
ranges are real parser/scanner boundary cases, not permission to skip work.
An empty source set publishes an empty result successfully without starting work.
The same actual worker operation serves budgets 1, 2 and 4.

## Work and results

Each worker obtains its real program identity, observes stop at operation
boundaries, and calls the intact existing conditional preflight, raw scanner and
token-parser entries. Scanner tokens are constructed once and retained in the
private SourceWork; the parser borrows them without copying them. A source facade
which discards its local tokens cannot supply that retained-token contract or
the boundary stop checks. No lexer/parser body is duplicated or replaced.
EntryKind is unit (3); deferred grammar retains its existing outcome.

Work states are 0 incomplete, 1 accepted syntax, 2 source failure, 3 cancelled.
Failure.Kind starts at storage (5) before calling a managed procedure. A neutral
return before its body therefore cannot become an empty successful result.
Scanner errors preserve their existing 200+ syntax-facade classification; storage
remains 5. Syntax metrics keep their existing parser-only meaning.

SourceSetFailure has Kind, SourceId and UnitFailure As SyntaxFailure. Kinds are
0 success, 1 invalid request, 2 native worker admission, 3 source syntax/scanning,
4 observed cancellation, 5 storage/publication, 6 completion-wait failure.
SourceId is -1 when no unit owns the failure. As with existing managed entries,
the caller seeds Kind=5/SourceId=-1 before entry in case coordinator root admission
fails before its body. Success preserves incoming Err. Worker errors cross only
through explicit work status, never through another thread's Err.

The coordinator admits in source order, retains at most the selected number of
live source workers, polls real completion and refills that same budget. It must
poll completion even if a worker never reaches its final state store. A source
failure does not abandon other sources: absent cancellation/infrastructure
failure, every unit runs and the smallest failing canonical source index wins.
No result/state/first diagnostic depends on completion order.

Only after every admitted worker drains and every source succeeds may the
coordinator publish a complete private work array using one failure-atomic typed
array copy. Any failure preserves the entire older result graph, its owners and
original bytes. Completed work becomes immutable after publication. Source work
is not copied into another worker or a serialized whole-project model.

## Stop and resource ownership

Cancellation is cooperative. Once observed, no further source admission occurs;
the coordinator requests sticky stop for admitted workers, then waits for their
actual completion. A wait failure is recorded but never treated as completion.
Retained input/work owners remain alive through drain and capture destruction.
Workers check before preflight/scan, between scan and parse, and after parse.
The existing bounded scanner/parser operations finish normally between checks.

Admission and publication have explicit final cancellation checks. Those checks
are the operation's admission points: an already observed request prevents the
operation; a later request does not undo an admitted atomic publication. Tests
inject before those checks and separately after publication admission. This is
cooperative cancellation, not asynchronous termination or rollback of committed
output. Each invocation owns its cancellation object; it is not reset internally.

Every active native ID belongs to the coordinator until completed drain. Capture
ownership belongs to native admission/cleanup. Private partial work becomes
unreachable only after workers drain. No extra pool, C worker implementation,
global work lock or independent nested worker budget is introduced.

## Additional bounds fixed before coding

On x64 SourceOwner payload is 32 bytes. SourceWork's ordered fields are Owner
(8), Tokens (8), Syntax (8), Failure (12), Metrics (20), WorkerId (8), State (4)
and four Long limits (16), with final alignment: 88 bytes. Its managed slots are
at offsets 0, 8 and 16. SourceCancellation payload is one byte. Tests assert the
actual emitted layouts rather than accepting these formulas as measurement.

For N sources and W active workers, additional class payload is 88N plus one
cancellation byte; input owners (32N) and original bytes are shared independently
of W. Coordinator pending/publication reference arrays hold eight bytes per
element; publication copies exactly 8N reference payload bytes and no source,
token or syntax-node payload. Each active worker has one eight-byte capture,
the existing fixed native capture header, one native record, one TLS record and
three owned event handles. Tests record their actual sizeof values separately
from GC headers, native stack, allocator overhead and OS/CRT storage.

Before measuring, additional coordinator registered roots are capped at 256 and
the worker wrapper at 128. Each worker's underlying bounded scanner/parser call
tree is capped at 4096 live registrations, covering the previous 1707-root
source-wrapper actor. The observed invocation bound is consequently
256 + W*(128+4096+1), excluding deliberately retained test pressure/old results.
The final term is the active capture registration. Actual emitted prologues and
runtime counts must satisfy those limits; failures do not relax them.

Existing scanner/parser workspace/growth/copy bounds still apply to each actual
unit. Reports separate shared input, per-source outputs, old retained outputs,
active worker workspace, source intake and publication. Growing input formulas
do not substitute for executed allocation, copy, read, transition or root counts.

Limits pass unchanged to the established scanner/parser. For a nonempty set,
MaximumTokens=0 therefore preserves the scanner's existing domain failure
(unit kind 207); MaximumTokens=1 exercises its record-budget failure (206).
Zero node/pending budgets, and nested syntax with zero depth budget, exercise
the parser's existing budget failure (unit kind 2). Flat syntax may need no
nesting depth. An empty set accepts zero limits without invoking either component.

## Required witness

Use 1/2/4 real UBE workers over unequal independent cases and every current
native MODULE source, including the 16 previously qualified modules and the new
Threads module. Compare complete tokens, ordered graphs, source IDs/spans and
fresh first failures against the one-worker result and independent fixture
expectations. Observe actual work entry/exit and native/program identities,
interleaved executed operations and CPU/memory/copy costs; parking threads alone
is insufficient. Repeated/reversed completion schedules, corrupted-comparison
negative controls, allocation/root/start/wait failures, cancellation checkpoints,
old-output preservation and zero residual owned resources remain mandatory.
Also exercise separate UBE parser workers borrowing one completed immutable token
owner while writing distinct private results. UBECore retains only its generic
mechanisms; all source policy, ordering and publication live in this compiler.
