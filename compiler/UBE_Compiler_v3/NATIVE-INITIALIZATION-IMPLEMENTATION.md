# Native module initialization implementation

This implements the reviewed First checked native executable item. The language,
NATIVE-EXECUTABLE-CONTRACT.md and NATIVE-STACK-REVIEW.md remain authoritative.
No lifecycle hooks, threading syntax or public ABI are introduced.

## Runtime state and entry

The bounded executable has one language thread and process-owned module state:
0 not started, 1 active, 2 complete, 3 failed. A private failure latch distinguishes
failure to complete a required module from an ordinary neutral expression result
and Err. Successful operations never clear Err. All globals have static neutral
storage; each written declaration still establishes its neutral value immediately
before evaluating its initializer.

The private always-inline ube.module.require(owner, lexicalModule) helper skips
local storage (owner -1) and access within the lexical module, after checking the
failure latch. A foreign not-started module enters active state, admits its whole
initializer footprint and calls its generated Boolean initializer. Success marks
it complete exactly once. Refusal sets Err 28 and marks initialization failed.
An initializer body returning false, or a failure latch set by a nested required
module, propagates failure. An already failed module cannot be retried. Main must
not run after failure. Ordinary user-call refusal and arithmetic failure do not
set this latch; their neutral expression results can complete initialization.

Foreign access to an active module enters the required indefinite wait, without
recursive re-entry. The separate ube.module.wait platform support entry is noreturn.
Its complete footprint occupies the final frame-table slot and is admitted before
entry. Failure to safely enter that wait uses the existing controlled fatal path;
it cannot turn into a successful access. The platform wait implementation and its
actual footprint still require qualification. Invalid internal owner identities
also follow the controlled fatal path before indexing any array.

Initializer frame indexes follow ordinary procedure indexes, in source identity
order. The last index is the wait-support footprint. Every entry must bind to
actual linked code; unknown footprints cannot be supplied as zero. The helper
contains no recursive or non-inlined helper frame. The initialization table holds
one generated Boolean initializer address per source. TryEmitNativeInitializationData
emits one shared data unit with external initializer declarations and global state.
Each source output includes TryEmitNativeInitializationSupport, an internal inline
helper referring to that shared data through external declarations. Initializer
definitions belong to their source output. This follows the selected per-module
buffer/object boundary; it never duplicates process initialization state.

NativeInitialization emits support into the existing private bounded writer. It
owns no scratch arrays or external resources, borrows limits/cancellation, charges
two actual module-entry visits per source (initializer declarations and table),
M+3 data identities, 41 support identities per helper copy and every emitted byte, and leaves a disposable
private prefix on failure. Inputs are positive source count and a nonnegative
ordinary-frame count whose sum plus one fits Long. Output contains M state bytes,
M pointer entries and one failure bit; these are target runtime globals, not
compiler-owned heap payload. All mutable compiler state remains build-private.

## Required body integration

Generated module initializers consume only checked declaration initializer trees
in written order, using the existing explicit cursor and fixed temporary slots.
Neutral declaration storage is emitted on entering the declaration node, before
its initializer children. Entry-block allocation alone does not implement that
rule for a later global changed by an earlier helper or a local declaration
executed again in a loop.
The normal startup order is referenced library packages before the executable,
then each package's manifest order. Current admission permits one direct library;
canonical source identities used for diagnostics remain unchanged.

Foreign reads, writes and ordinary/intrinsic calls require their target module.
Call arguments retain their existing evaluation order before callee admission.
ByRef pointers must retain a private owner-module companion through exact alias
forwarding; local, ByVal and forced/default temporary storage use -1. Actual
foreign dereferences enforce initialization. Merely forwarding an unused alias
must not manufacture a dereference. The private call ABI must preserve the adopted
one-component native aggregate and caller/callee agreement.

On require failure, initializer bodies return false and procedures return their
neutral result without further effects. After ordinary calls, the failure latch
must be checked before subsequent work, allowing failure to unwind through helper
procedures. Successful ordinary-call refusal remains a neutral recoverable result.
Lifecycle hooks and managed cleanup are deferred by checker admission; there is
no user termination hook to execute in this scalar subset. Later lifecycle support
must implement reverse completion order under its own approved contract.

## Qualification boundary

First prove emitted support using independent native state/effect/Err oracles,
including early dependencies, exactly-once entry, own-module access, controlled
admission refusal, ordinary recoverable expression failure, nested failure and
actual waiting under a bounded process observer. Reject altered state/admission
controls. Then integrate real checked bodies, provenance and startup and run the
full source fixtures. Support-only evidence cannot qualify that integration or
actual stack-floor/frame/recovery/platform behavior.

## Private ByRef owner operand

Each ordinary ByRef parameter is emitted as a pointer followed immediately by an
i32 owner-module operand. Its incoming owner uses the identity immediately after
ValueIdentity; preparation reserves that identity during the existing declaration
visit. AddressIdentity still equals the pointer ValueIdentity. This adds one
charged SSA identity per ordinary ByRef formal, no target/plan payload or scan.
Intrinsic formals have no ordinary signature and reserve no companion identity.

Exact global actuals supply their canonical SourceId; exact ByRef formal actuals
forward the incoming companion. Local/result/ByVal formal storage and forced or
omitted temporaries supply -1. The call emitter derives that companion directly
from the existing checked actual node and resolved target during its formal-order
argument visit; it does not enlarge operand arrays or re-resolve names. Native
aggregate argument/result layout and pointer aliasing remain unchanged. Companion
transport must be proved independently before access guards rely on it.

## Procedure-root lookup for module emission

NativeGraph now retains checked procedure-root indexes during its existing
planning walk, so the remaining module emitter need not rescan procedure bodies.
Use one private per-module Long array bounded by min(F,V), where F is the prepared
ordinary frame count and V is this module's checked node count; capacity is
therefore at most 4*V bytes even when other modules contain many procedures.
Reserve that payload before allocation and release it with the existing graph
owner. Array allocation failure leaves a disposable private plan. No input owner
is copied or mutated, and no new body traversal or worker is introduced.

Ordinary frame indexes are assigned in declaration order. Record this module's
first frame and validate consecutive frame identities as procedure roots enter
the planning walk. Definition emission can then resolve a procedure root by
FrameIndex minus the first frame, with checked bounds. Each root store belongs
to its already-counted node entry. The module declaration/member walk emits
static globals and complete procedure definitions; its definition visits remain
charged. Emit the module initializer afterward by following module-root children
once, charging those edges and walking only declaration initializer subtrees.
Procedure subtrees are emitted exactly once through the indexed roots. Together
these emissions must stay within the second body walk's 2*V+E allowance. The
approved 3*D declaration bound is unchanged. The additional typed-import proposal
in NATIVE-DECLARATION-WORK-REVIEW.md is now approved as a separate I allowance.

The index is implemented and has focused allocation/root-pressure, cleanup,
invalid-identity, empty-index and exact-payload/work checks. The graph plan owns
one additional array and its capacity/count/first-frame scalars (104-byte owner);
TryReadNativeProcedureRoot preserves its output on failure. Complete per-module
output, foreign declarations and the normal startup schedule remain unimplemented.

## Checked initializer body emission

TryEmitNativeInitializer now emits a Boolean initializer for one checked module.
It borrows the same catalog, target plan and graph plan as procedure emission and
uses the existing 64-byte-per-node body storage. The shared subtree cursor visits
the module root and declaration subtrees in written order. After a procedure
edge, TrySkipNativeTraversalChild defers that subtree without creating a frame;
the edge stays counted, and later procedure emission accounts for its body.
The same cursor therefore owns all live pending/depth charges and cleanup.
Skipping is permitted only immediately after an announced edge; invalid calls
preserve cursor state. No node, edge or definition visit is hidden by the index.

The root initializer's planned forced/default argument count selects fixed entry
slots through TryAllocateNativeTemporaries, shared with procedures. Declaration
entry resets storage before initializer children evaluate. Successful body
emission returns true, including ordinary recoverable arithmetic or call-refusal
errors. The access/unwind integration below adds runtime false returns on failed
requirements. The earlier body-only proof does not establish that integration.

The checked single-module fixture invokes the emitted initializer through a
native observer with controlled frame metadata. It specifies events 1233, First
4, Later 1, Quotient 0, Forced 3, Defaulted 5, Snapshot 1233 and Main 41350, with
Err 11 and one revision increment. Refusing all four ordinary calls must still
complete initialization: Later is 1, other globals are 0, Main returns 1000 and
Err is 28 after five revision increments (four refusals and division by zero).
Exact work is 3*V+6 for this initializer: its actual node events, four deferred
procedure edges, one definition visit and two argument-map visits. Independent
zero/below/exact/above work tests preserve complete cleanup. These fixtures also
require identical output/work/identities at jobs 1/2/4 and reject removal of the
Later neutral reset or corruption of the optional default.

This is a body-emission test. It does not prove shared-state integration,
exactly-once scheduling, cross-module barriers, actual linked footprints,
platform waiting or normal process startup. Those remain required next work.

## Access and failure propagation

NativeBodies now calls the shared requirement helper immediately before foreign
storage loads/stores and ordinary/intrinsic calls. Call operands, conversions and
forced/default temporary effects have already executed. An exact ByRef argument
only transports its pointer and owner; it does not require or read that storage.
Actual ByRef loads/stores pass the incoming owner operand to the helper. Known
local and own-module storage avoid a redundant requirement. The lexical source
comes from the current procedure or module declaration, never the caller.

Every ordinary call also checks the shared latch through require(-1, lexical)
after the admitted/refused paths merge. Placing this check after the result phi
preserves both actual predecessors and lets the result dominate the continuation.
Failed requirements emit an immediate neutral return: false for initializers,
zero (including the native aggregate representation) for Functions, or void for
Subs. An earlier assignment to a Function result cannot survive that unwind.
Recoverable ordinary-call refusal still returns neutral without setting the latch.

The body owner records NeedsInitializationSupport in its existing padding and
remains 64 bytes. Each emitted requirement charges its SSA result, two blocks and
all output bytes through the normal writer. It adds no allocation, declaration
scan, graph visit, worker or mutable shared compiler state. Ordinary call guards
now address the same F+M+1 frame table as the module helper: ordinary functions,
source-ordered initializer slots, then wait support.
The module output consumer must emit stack support whenever initialization support
is needed, even if that module has no ordinary call. These are fixed support
records, not extra declaration or body traversals.

The new three-source fixture links actual checked bodies, shared data and the
production requirement helper. Its test-only combined LLVM body unit deliberately
does not implement or qualify per-module output/imports. Direct C entry selects
the module, controlled frame data can refuse C's initializer, and a noreturn C
observer identifies entry to the wait path. Actual platform waiting, actual frame
sizes, normal package/source scheduling and process startup remain separate work.
The existing scalar/native/call fixtures retain their independent expectations
with an explicit always-successful single-module requirement adapter; those
fixtures cannot establish initialization semantics. Qualification of the new
integration is recorded separately in NATIVE-INITIALIZATION-EVIDENCE.md.

## Normal initialization schedule

The initialization schedule consumes canonical checked source/package identities,
without changing their diagnostic order. Current admission allows the executable
package followed by at most one direct library package. Validate those source
associations once, counting M source-record visits, then emit M requirement calls
in library-manifest order followed by executable-manifest order. Each emitted
schedule entry is also counted. These are source/schedule visits, not additional
declaration or body traversals. The cumulative work ceiling includes all 2*M.

The generated private ube.module.initialize helper is always-inline and returns
Boolean completion. It requires each source with lexical identity -1; the shared
state helper therefore starts untouched modules and skips dependencies already
completed by earlier access. A failed requirement immediately returns false and
does not visit the remaining schedule at runtime. The process entry consumer must
call Main only after true completion. Its actual entry and stack-footprint proof
remain separate work.

The schedule owns no compiler scratch payload and borrows the checked catalog.
Its emitted function, entry/failure labels, M results and M continuation labels
charge 2*M+3 target identities and every output byte. Invalid metadata, cancellation,
allocation/output failure and exhausted budgets return controlled failure with
only a disposable private output prefix. No retry, worker, public API, extra
source graph or change to the approved declaration-work contract is introduced.
