# Native parser-probe oracles

Run `compiler/UBE_Compiler_v3/tools/check-parser-probes.ps1` from the repository
root. This is the test-only native prerequisite in `PARSER-PROBES.md`, not a
production parser, CLI feature or new language ABI. The 116 definition fixtures
and the current production sources/selection remain unchanged.

## Independent expectations

The 77 `syntax` shapes in the frozen expression/statement/unit fixture files
supply storage inputs. `oracles.ps1` resolves their exact original byte witnesses
and serializes their manually authored trees into postorder construction commands,
linked records and contiguous-edge records. It does not parse source, infer an
operator tree, or use either candidate to generate its expected answer.
Deferred/rejection fixtures do not become syntax trees. Empty synthetic storage
is a separate container boundary, not acceptance of an empty source program.

Both actual UBE storage builders must produce every expected node field, root,
edge/order and source identity. Their actual UBE iterative readers must reproduce
the original command sequence. Native C comparison independently reads the
arrays; its own traversal is not reported as UBE traversal performance. Source
and input command bytes stay unchanged, and stale Err 77 survives ordinary
completion. Complete previous result arrays and metadata survive failure.

`traversal-oracles.json` explicitly lists the narrower expression cases shared
by both algorithm candidates, rather than guessing scope from a shape's node
kinds. For example, a Name shape can still contain a use-site suffix or Me that
the narrow experiment does not implement. Its focused extra cases cover the
invalid Not contexts and valid controls without changing the frozen definition.
No host numeric evaluation supplies expected grouping.

## Observations and limits

Intact UBE source copies and the real UBECore Reference compile through both
accepted source-built stages, with byte-identical raw LLVM. `abi.ps1` checks
exact procedure signatures, record layouts and primitive layout descriptors
before emitting separate C adapters and observation wrappers. Deliberately
wrong observed node kind/span controls must fail native comparison.

Event counters count executed read, write, link, validation, reserve and push
helper calls. Reserve/push arguments record actual maximum live requirements.
Append-only command-write events record actual emitted commands. Runtime
allocation/copy hooks count executed requests and payload copies. Byte-array
element acquisitions measure source lookup reads separately from token fetches.
Native success assertions require expected positive counts, not merely an upper
bound that a missing hook could satisfy with zero.

The observed runtime includes the exact identity-checked repository C runtime.
The runner compiles it to LLVM and inserts a callback after every precisely
matched store to its i64 root counter. No store may escape the transformation.
Callbacks receive the actual stored count under the original runtime lock,
including transient internal roots. The original source and the raw/observed IR,
transformed-site count and final object hashes are recorded. The accepted runtime
is also exercised independently. Observation does not change production runtime
source; the focused recoverable-OOM prerequisite is described in
`../../../PARSER-PROBES.md` and must be qualified separately first.

The cost sample set is predefined: 48 storage rows (six sizes, wide/tall,
construct/project, both representations) and 36 traversal rows (flat lengths,
255/256/257 group/prefix/power boundaries, and mixed D4/D8/D256). The plan's
linear work, geometric growth, publication and zero source-copy budgets are
checked against executed counters. Expected resource failures are identified;
an uncompleted target tree is not misreported as a successfully parsed tree.
The recursive frame-guard limitation remains a failed common-domain obligation,
even when the experiment correctly observes its controlled failure.

The copy observer must fire: successful publication copies the exact scalar
payload leaves (including 12/16 bytes of scalar wrapper fields for linked/edge
results, excluding pointer slots and padding), exact trimming copies the logical
output payload, and output growth above eight entries records positive copies.
No unclassified payload copies are admitted. Validation and sibling-link events
also obey the stated node/edge action bounds. Mutated-observation controls reject
missing publication, unclassified copies, excessive validation and excessive
sibling writes; successful expression counters include every emitted command.

Array construction/projection workspace, token/source setup and comparison are
separate from probe payload costs. Requested calloc bytes are not measured
physical writes. Peak registered-root storage is not total native stack usage.
Sampled process working set includes the C harness, runtime, root-pressure
fixtures and allocator overhead, not a steady-state production compiler claim.

Before deep recursive execution, `stack-safety.ps1` reads the linked PE's actual
stack reserve and the corresponding adapted assembly's static recursive frame.
It requires the source's 384-frame guard and at least 256 KiB of remaining
headroom. Its static facts exclude additional helper/CRT/driver frames; source
guard placement is independently reviewed. No PE stack increase is used to rescue
the candidate, and no unsafe pre-fix deep mixed-recursion program is executed.

## Failure and completion gates

Persistent allocation failure sweeps each observed malloc/calloc/realloc boundary, including
retry, growth, exact trimming and whole-result publication. Actual backed root
nodes exercise admission pressure; no fabricated root-count inflation substitutes
for them. Old output pointers, node/edge data, counts/root/source identity and
input source ownership must remain intact on failure. Invalid budgets/graphs and
corrupt links terminate with controlled status. Four joined native workers share
immutable inputs and own private probe state. Root removal and collection restore
the expected baseline with no residual live payload.

Every native run must report completed fixtures, domain and worker suites.
Observed runs also report costs, allocation faults and real-backed roots, with
actual boundary/attempt counts. The maintained runner requires these markers,
the complete cost-row set and exact successful process status/empty stderr.
It snapshots the accepted cohort and all frozen definition/probe inputs before
and after, writes a separate report under `bootstrap/out/parser-probes/`, and
never republishes the production compiler selection.
