# Generated native target ownership and extents

This is the next consumer of the existing frozen-definition, retention and signed
instruction-target proofs. It adds no architecture, owner arena or public ABI.

TryValidateNativeGeneratedTarget consumes a qualified decoded instruction,
relocation, resolved named one-byte target anchor and signed target position,
together with the matching pre-tool NativeExpectedDefinition and successful
NativeRetainedDefinition from its defining object's TryBindNativeDefinition.
The build owner preserves these immutable associations with the same image.
The function examines the image range; it does not reread names, rebind the
producer object, discover an owner from a candidate spelling or prove global
nonaliasing. Those producer identities and associations remain preconditions.

The resolved anchor must agree with the retained image definition's symbol,
section, file start, type, initialized first byte, section offset, RVA, VA and
characteristics. Storage count must equal the frozen StorageBytes, or one byte
for a function entry. Existing retention permissions and scalar range checks are
reused. Data/function family classification is shared with the retention binder.

Direct conditional branches, jumps and calls to generated functions require a
relative relocation and the exact frozen function entry RVA. An interior code
address does not pass this entry check. This does not establish the caller's
stack state, call signature, tail-call legality or the callee's full extent.

Generated data accesses use the frozen complete storage extent. Ordinary data
uses a RIP-relative RVA; stack-floor/error-state TLS families use SECREL and a
register-based section offset. The relocation domain must match the family.
All observed access bytes must fit the extent, and writes require writable
storage. Address formation with zero memory width requires one addressable byte
and cannot write; it does not admit a one-past pointer. Indirect memory calls or
jumps may only read an eight-byte cell here; this bounds the cell access without
authorizing its contents as a callee. TLS base provenance is a separate proof.

Callers supply qualified descriptors. Scalar shape, bounds and frozen/retained
state errors use 1509; incompatible target identity, kind, entry, permissions or
access extents use 1506. The operation charges one zero-byte inspection event
for each well-shaped attempt, uses fixed private scalar workspace, allocates or
copies no payload, retains no owner and preserves all inputs and Err. It is
reentrant. Cancellation and budget failures use the existing 1507 and 1502/token7
paths. All numeric caps and lowering traversal bounds remain unchanged.

Qualification requires independent function/data/TLS examples; first/last-byte,
read/write and zero-filled storage cases; changed anchors, interior entry,
straddling accesses, wrong relocation domains and caller shapes; exact budgets,
cancellation, allocation independence, root refusal and forced Boolean controls.
The retained matrix must compose production binding of every producer's frozen
rows with the consumer and compare the generated-owner image ranges independently.
Pointer cells, IAT/TLS metadata, dataflow, complete function/stack/debug meaning and
native build/publication integration remain required.
