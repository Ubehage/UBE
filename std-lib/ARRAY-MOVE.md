# Array ownership transfer

Status: implemented supporting primitive for managed-text binding publication;
native/concurrent and bootstrap/actual-UBE source checks pass at O0/O2, including
source-depth boundaries and binder preparation recovery (evidence in
`../runtime/tests/array-move/README.md`). This does not change ordinary
array assignment, which continues to make an independent value copy.

`Array.Move` is an identity-bound intrinsic role with a Boolean result and two
ByRef rank-one arrays of the same exact element type. Typed library declarations
may select different admitted element types; nominal record identity must match.
The destination is the first parameter, the source the second.

For distinct descriptors, a successful operation transfers the source bounds,
payload and ownership into the destination and leaves the source empty. The
source must be empty or have independently owned heap-backed storage. A nonempty
source whose payload is inline storage is rejected before mutation: False is
returned and Err records 5. This is a Boolean-status primitive, not a language
FAIL result. The destination may previously contain inline or owned storage.
Self-move is a successful no-op, including for inline storage. Successful moves
preserve the existing Err value.

The primitive allocates nothing. It acquires the existing heap/descriptor locks
in the runtime's documented order, acquires an identical stripe only once, and
transfers the four-cell descriptors as one protected operation. Replacing an
owned destination drops its old ownership reference; retained element aliases
keep that old payload alive through their existing pins. Native freeing and
collection are deferred to the existing reclamation path. The primitive does
not perform a fallible allocation, a native free, collection, or source-procedure
call-depth admission after descriptor commit begins.

The identity-bound native wrapper bypasses ordinary source-procedure entry
depth accounting, as other direct primitive wrappers do. Argument preparation
still obeys ordinary source rules. Invalid signatures do not bind this role.

## Multiple-output publication

Expression binding builds its fact array and immutable constant-text byte arena
in private owned candidates. It completes all allocations, validation and
diagnostic work before publication. It then moves both candidate arrays to the
caller's outputs and publishes the completed counts. Each source candidate is
known owned or empty and cannot be concurrently changed, so neither commit can
fail. There is no fallible ordinary source helper call between the commits.
Before commit, any failure leaves both prior output arrays untouched. This
protocol does not claim an atomic transaction observable by unsynchronized
readers; callers may consume completed facts only after successful return.

## Required qualification

Test owned-to-owned and owned-to-fixed-destination transfer, empty sources,
nonzero/negative bounds, same-descriptor moves, retained old-destination aliases,
and nonempty inline-source rejection without mutation. Verify exact nominal
element matching, sticky Err, no allocation during transfer, no post-commit
native-free failure, and operation at the source call-depth boundary. Inject
every fallible preparation step in the two-output binding operation and check
both previous arrays remain intact; follow with successful recovery. Run at
O0/O2 through the bootstrap and actual UBE compiler, with balanced disposal.
