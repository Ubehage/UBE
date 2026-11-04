# Bounded directed graph components

The current compiler's reviewed circular-initialization warning analysis needs
two iterative component traversals over a bounded dependency matrix. UBECore
owns this generic graph operation; module policy, dependency discovery, source
witnesses, warning ordering, cancellation and resource admission remain with the
caller. This contract introduces no language feature or platform dependency.

## Representation and ownership

Vertices have zero-based Long identities. The immutable borrowed Long matrix is
row-major, with at least N*N elements. Zero means no directed edge; every other
value means an edge. Payload values are ignored, so callers may use positive
witness indexes without a second adjacency matrix. Only the first N*N elements
are read. Self edges are accepted. N=0 has no components.

`GraphComponents` owns N `GraphComponentSlot` records, each five Long fields
(20 bytes of payload). The fields are reserved algorithm state: visit marks,
finish order, component labels and an explicit vertex/neighbor stack. The scalar
owner carries counts and traversal direction. Pass the owner ByRef to avoid
ordinary value-copy costs. No matrix or source owner is retained; retain and
borrow the same immutable matrix for every advance until completion. Different
owners may borrow the same matrix concurrently. One mutable owner has one user.

`TryBeginGraphComponents` accepts only an empty owner, checks nonnegative N and
matrix length using widened arithmetic, and allocates the one exact workspace.
It does not resize a live owner or copy the matrix. A failed begin leaves an
explicitly disposable owner. The published capacity records allocated payload
even when subsequent work fails. The caller admits 20*N bytes before begin and
releases that charge when disposal ends ownership. Allocator headers, roots and
unreachable collected storage are separate from this payload count.

`TryAdvanceGraphComponents` takes a nonnegative maximum work allowance and
takes a nonnegative live-stack limit, and returns actual work, live pending
entries, the peak pending count during that call and a completion flag. It performs at most that many
transitions. Zero allowance preserves an active owner. A completed owner returns
complete with zero work. Invalid input or state returns False and makes an active
owner unusable until disposal; partial component labels must not be consumed.
`TryReadGraphComponent` returns the positive component label for a valid vertex
only after successful completion. Labels are deterministic for fixed vertex
order; their numeric ordering is not a source/warning ordering guarantee.
`TryDisposeGraphComponents` releases the workspace and resets the owner, including
after failure or cancellation. Cancellation means the caller stops advancing and
disposes; the library has no compiler cancellation object or worker pool.

Try calls receive a fresh failure output: 0 on success, 1 for invalid arguments
or state, 2 for the live-stack limit, and 5 as the managed-admission/allocation fallback. False never clears a
failure to zero. Callers seed 5 before entering a managed operation because a root
admission failure may prevent its body from running. Successful calls preserve
the thread's Err. No external resource or global mutable state is owned.

## Work and publication

The algorithm clears workspace slots, traverses outgoing edges to record finish
order, then traverses incoming edges in reverse finish order. Each vertex enters
each explicit stack at most once. Matrix cells are read once per direction.
Each clearing, root-selection, edge-probe, stack-pop or direction/completion
transition attempt counts one actual work event, including a failing attempt;
the counter increments before the operation, not from the input size. Each push checks its supplied
live-stack limit before marking or adding the vertex. No capacity-sized pending
reservation is required: a disconnected N-vertex graph can run with one entry. For nonempty graphs completion takes exactly
2*N*N + 5*N + 2 events. Empty graphs complete at begin with no events.

The caller may cap each advance at 4096 or less, check cancellation between calls,
and supply an allowance no larger than its remaining work budget. It charges the
returned actual work (including when an advance returns False) before subsequent
operations. It also reconciles the returned live/peak stack counts with its
shared ledger. Both pending outputs must be seeded with the prior live count
before managed entry; rejection before traversal preserves them. During a chunk
the library enforces the caller-derived allowance before each push. The caller
must provide no more than the remaining shared pending budget plus this owner's
already charged entries. No concurrent user may consume that private allowance.
This admits a bounded chunk
before execution without counting unused allowance as work. The library makes no
elapsed-time cancellation guarantee and performs no allocation, resize or payload
copy during advances or reads. Scratch payload is O(N), matrix work O(N*N), and
source-driven native recursion is forbidden.

## Independent qualification required

Test empty/singleton, self-edge, directed chain, cycles, disjoint components and
edges leaving a cycle. Compare every vertex pair against an independently
computed mutual-reachability relation, including every three-vertex graph and
larger deterministic matrices. Compare results across different chunk sizes,
interleaved independent owners and both bootstrap stages. Assert actual event
counts, workspace payload, unchanged matrix, no advance-time allocations/copies,
exact-limit completion, zero allowance, below/exact/above pending limits on
chains and disconnected graphs, invalid spans, premature output reads,
allocation/root denial and complete cleanup. Mutated component labels must fail
the independent relation check. This document is a contract, not a passing test
or compiler-warning qualification.
