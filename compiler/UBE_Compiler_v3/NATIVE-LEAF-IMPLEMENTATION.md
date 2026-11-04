# Bounded native leaf traversal

This implements the pending leaf-extent prerequisite of First checked native
executable. The instruction-reader contract and observed multi-return Err setter
motivate an explicit reachable-instruction walk; no new architecture is selected.

TryInspectNativeLeaf borrows immutable bytes and a caller-supplied positive fence
within that snapshot. The fence must eventually be bound to the admitted code
section/definition by the build owner. It is not treated as the function length.
The result is the smallest prefix containing all reachable decoded instructions,
with a map distinguishing starts, continuations and unreachable bytes. It makes
no claim about the ownership or meaning of unreachable bytes inside that prefix.

NativeLeaf owns a byte map and Long worklist, each of capacity N (the fence size).
Fresh zero state is required. Allocation reserves N and 4N bytes separately in
both shared inspection storage and the global native payload ledger before each
allocation. No input or array contents are copied. Each successful allocation is
recorded immediately; failed allocation reservations are released. Status 4 means
partial/unqualified state; only status 1 publishes First, CodeBytes and
InstructionCount. The caller always disposes successful or partial owners with
TryDisposeNativeLeaf, which releases each array and its ledger charge. Allocation
failure, cancellation and root refusal leave a disposable owner. An invalid
nonfresh owner is unchanged. This matches existing inventory owner discipline.
No aliases may mutate or dispose the owner during inspection. Separate owners
are reentrant; immutable input can be shared. Shared budgets require the existing
serial owner or synchronization, not unsynchronized worker writes.

Map values are 0 unseen/unreachable, 1 pending, 2 instruction start, 3 continuation.
Entry offset zero is scheduled first. Each instruction is scheduled at most once;
a bounded LIFO worklist follows both conditional successors and direct jumps.
Normal RET has no successor. Cycles terminate through the map, even without RET.
Every successor must lie inside the fence; queued/decoded starts are shared,
continuation targets reject. Decoding may not overlap any queued/decoded start
or continuation. This rejects branches into immediates in either discovery order.
Only flows 0..3 are accepted. Calls, indirect jumps, traps and writes to RBX, RSP,
RBP, RSI, RDI or R12..R15 reject. The decoder rejects unsupported SIMD forms.
This is a control-flow/leaf-register proof, not memory safety, relocation equality,
stack admission, final function ownership or executable qualification.

Each allocation attempt, scheduling attempt, worklist pop and continuation-map
check is preceded by a cancellable zero-byte inspection event. Actual instruction
reads use the decoder's byte/events ledger. For a successful walk with K reachable
instructions and B reachable bytes, source reads are exactly B, K <= B <= N,
worklist occupancy <= K, payload is exactly 5N, and events <= 3 + 2B + 2K (and hence <= 3 + 4N).
A failing final decode/check can read at most 15 additional bytes. Fixed-width
decode/mark operations are bounded by 15; traversal is nonrecursive and linear
in the number of reachable instructions/bytes, with no full-map rescan.
The existing numeric caps and declaration/body/argument bounds are unchanged.

Invalid API/owner state uses 1509; malformed, escaping or disallowed instructions
use 1506; storage/work refusal uses 1502/resource 7 (or the existing global ledger
resource); cancellation uses 1507. Err and input bytes are preserved. Required
qualification includes independently specified reachable maps and extents, both
branch-overlap discovery orders, loops/multiple returns, exact resource boundaries,
every allocation/cancellation failure, root pressure and pinned object comparisons.
