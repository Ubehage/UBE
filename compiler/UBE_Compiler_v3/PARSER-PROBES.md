# Native parser representation and traversal probes

The active `Roadmap.md` item is the focused native probe prerequisite after
`PARSER-CONTRACT.md`. This plan fixes comparisons and acceptance before native
measurements. Candidate UBE lives only under `tests/parser/probes/`; no production
parser manifest is changed. A measured decision and exact
evidence will be recorded here or in the companion evidence after the gate passes.

Persistent allocator denial exposed a necessary bootstrap prerequisite: tracing
workspace exhaustion terminated the process, and first-error publication could
itself require heap allocation. The focused runtime correction abandons an
incomplete mark pass without finalization or sweeping, clears partial marks,
and permits allocation retry. Explicit collection reports Err7; opportunistic
collection preserves the incoming error when a later retry succeeds. A fixed
native TLS error record allows first-error publication without allocating the
larger thread/monitor record. The maintained runtime build uses the existing
Clang Windows target, whose emitted native TLS is checked rather than relying on
heap-backed TLS emulation. Small retained pre-fix regressions establish the old
termination; the corrected runtime must pass a fresh complete source-built gate
before final parser probe qualification. Historical accepted artifacts remain
unchanged.

## Questions and candidates

Compare two flat, source-view representations of the same logical syntax:

- Linked children: a 24-byte node containing six Long fields (Kind, FirstByte,
  LastByte, FirstChild, NextSibling, ChildCount). Child/sibling identities are
  indexes within one owned node array.
- Contiguous edges: a 20-byte node (Kind, FirstByte, LastByte, ChildStart,
  ChildCount), with a separate Long array of child identities. Each parent's
  child range is contiguous.

Both build privately from the same postorder construction commands. A command
has four Long fields (Kind, FirstByte, LastByte, ChildCount), occupying 16 bytes.
The independent C/PowerShell oracle serializes the existing manually authored
syntax shapes into commands; that is not parsing their source. Every one of the
77 syntax-shape fixtures participates in storage reconstruction. Rejections and
deferred fixtures do not magically become valid trees for this experiment.

Commands pop the specified number of completed roots and push one new parent.
Each child is older than its parent, has one parent, and retains original order
and source containment. A complete result has exactly one root. Node identity is
test-only construction order, not a public ABI or cross-file identity scheme.
Ordinary UBE readers project each actual graph back to postorder commands using
explicit frames, avoiding recursive traversal of a deep left-associated tree.

Compare two narrow expression algorithms over actual qualified SourceToken
views: explicit operator/operand stacks and bounded recursive precedence climbing.
Use the existing arithmetic/group/prefix/power/Not/Boolean witnesses supported by
both probes; all other grammar remains outside the algorithm experiment. Token
setup/scanning, metadata and name/literal cooking are separate measurements.
These probes are not the full 116-case parser implementation.

## Ownership and publication

Input documents, tokens and command arrays are borrowed immutable views. Outputs
carry spans and a scalar source identity, not copied SourceDocument values or
source payload. The document owner retains the original source while views live.
One caller owns pending arrays, frames, output and metrics. Four joined native
test workers may share immutable inputs and own private results; no UBE scheduler
or production worker pool is introduced.

Publish each storage candidate as one owned, one-element result-record array.
Its nested arrays, logical counts, root and source identity commit together through
the existing transactional Array.TryCopy. Publishing node/edge arrays separately
would permit partial success, so that interface is excluded. Pending storage
starts at eight and doubles with guarded arithmetic. Trim to exact logical length
before final copying; successful results retain no spare node/edge capacity.
Traversal/projection command arrays likewise publish only on complete success.

Failure is fresh status: 0 success, 1 invalid request/structure, 2 explicit budget,
5 storage/admission. Traversal's first syntax diagnostics are a separate 101+
domain, not mistaken for storage failure or stale Err. Callers initialize complete
fallbacks before managed entry because root admission can return neutral False
before the body. Every failure preserves the complete prior output, including
root, counts and source identity. Partial pending state is private and cleaned.

## Resource and progress definitions

Caller budgets cover nodes, edges, construction/projection frames, commands and
syntactic pending depth. Bound arithmetic before allocation or indexing. Wide
children can require many pending construction roots without deep source syntax;
do not call width a violation of the 256 nesting probe.

The expression depth probes exercise 255, 256 and 257 open parentheses or pending
unary/right-associated operands against a limit of 256. The two candidates must
use the same documented counting rule and first-error behavior. Flat left-
associative chains must remain iterative even when their resulting tree is tall.
Projecting that tree uses an explicit result-size budget, not host recursion or
the grammar's open-group limit. Invalid/corrupt indexes and cycles must terminate
with controlled status rather than unchecked memory access or indefinite retry.

## Predefined native budgets

Let N be stored nodes, E child edges, T physical input tokens and R measured record
stride. Separate source setup and existing scanner costs from probe calls. Count
executed accesses/actions/copies; never calculate a reported work counter from N.

| Measurement | Required result |
|---|---|
| Source payload copying in storage/traversal/projection | zero bytes |
| Storage construction command reads | at most N, plus a separately counted optional validation pass of N |
| Child linking/edge construction actions | at most E, plus separately counted optional validation of E |
| Graph projection visits | at most twice N node actions and twice E edge actions |
| Expression token reads | at most 64 * (T + 1) |
| Expression state/reduction actions | at most 64 * (T + emitted commands + 1) |
| Geometric growth payload copies per output array | below 2 * R * logical length, with an initial eight-slot allowance |
| Exact trim and final output publication | at most twice logical output payload, plus at most 64 bytes of fixed wrapper metadata |
| Growth plus publication for output payload | below four times logical output payload, with stated small-array allowance |

Track construction/projection work stacks separately: their measured stride,
maximum live entries, capacities, growth copies and requested allocations must
obey the same geometric bound for their actual maximum live size. No repeated
whole-array or subtree copy per append is permitted. Repeated polling/failed
alternatives must count toward executed traversal work rather than disappear
behind an input-length formula.

Report actual requested allocation and calloc initialization, final retained
nodes/edges, temporary workspace, caller and generated callee roots/peak root
count, retained source/old output and cleanup separately. Requested calloc bytes
are not physical writes. Sampled process working set includes native harness,
fault fixtures and process overhead; it is not a steady-state compiler footprint.
Wall times are observations, not acceptance promises or a substitute for work.

Before deep execution, inspect generated native frames and the actual PE stack
reserve. Initial compilation exposed two separate risks with a repeated mixed-
precedence group: source nesting does not bound native recursive frames, and
source nesting does not bound the number of pending heap operators. The witness
prefix is `a Imp b Eqv c Xor d Or e And f = g & h + i * j \ k Mod (`; nest it D
times around `x` and close D groups. It has 23D+1 logical commands and about
12D+1 recursive frames despite only D open groups.

The initial generated recursive frame occupies 1456 bytes including its return
address, with no dynamic allocas. The default linked PE reserves 1048576 stack
bytes. Pure 256-group arithmetic therefore understates the risk: the mixed
256-group frame estimate exceeds four MiB. No unsafe deep mixed execution is
permitted to discover this by crashing. The recursive candidate now has an
additional test-only limit of 384 native traversal frames, checked before every
recursive call; recheck its final emitted frame before deep tests. It can meet
pure group limits while failing a mixed source below semantic depth 256. Record
that as a candidate limitation against the common source requirement, not a
successful full-domain result or a reason to increase the process stack reserve.

The explicit candidate's pending operator/value arrays instead use the explicit
command budget; an implicit `MaximumDepth + 32` width ceiling was incorrect.
Budget failure is kind 2, never kind 5 merely because a push helper returns False.
Use small mixed D4/D8 samples to measure frame/pending amplification safely, a
focused pre-fix mixed D32 diagnostic, and the protected comparison at D256.

Use increasing small, flat, wide and tall samples (including 1, 8, 64, 1024 and
16384 nodes/tokens where meaningful) and separately test the explicit depth
boundaries. Record unsupported candidate obligations as failures/limits rather
than silently weakening the common comparison. No bootstrap extension is justified
solely to rescue a losing candidate.

## Native acceptance and decision

Compile intact test-only UBE sources plus the required intact production source
views through both accepted source-built v2 stages, using the actual UBECore
Reference. Check emitted record/callee signatures before test-only native ABI and
observation adapters, and require raw LLVM identity. Compare complete shapes,
ordering, spans and first diagnostics against the independent expectations.
Require deliberate corrupted-result controls to fail comparison.

Sweep actual root admission pressure and persistent allocation failure at every
observed growth/preparation/publication allocation boundary. Preserve complete
old results and source ownership, check seeded Err where ordinary completion
preserves it, and require zero residual roots/live payload after cleanup. Native
private workers must return identical logical results without shared mutable
probe state. Preserve/audit the current 116-case definition and 501-check accepted
cohort; native probe qualification does not republish that production selection.

After acceptance, choose only what the measurements justify for the first bounded
consumer, explain tradeoffs and limits, and state the next production action.
Neither storage choice nor expression timings prove full module parsing,
conditional recovery, semantic checking, self-hosting or code generation.
