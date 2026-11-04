# Native reference-pointer cells

This extends the reviewed generated-target ownership work using the existing
symbol inventory, range locator, byte comparison and contribution-isolation
consumers. It introduces no owner arena, public ABI or compiler phase.

TryBindNativeReferencePointer consumes a qualified decoded instruction and signed
effective position, its resolved named one-byte image target, and a frozen
generated definition with its producer-bound retained range and name arena.
The caller retains all these associations to the same immutable image. The image
inventory and layout are qualified and refer to the supplied image bytes.

The target name must be exactly `.refptr.` followed by the frozen referent name.
The referent must be ordinary generated storage, not a function or TLS variable.
The consumer resolves the complete eight-byte cell from the image inventory,
matches every anchor coordinate, requires initialized readable nonexecuting,
nonwritable, nondiscardable data without the code flag, and reuses contribution
isolation to reject section/file-table overlap. The cell's eight bytes must equal
the retained referent VA. This validates the linked cell's meaning; it does not
assume that a candidate symbol spelling proves that meaning.

The instruction must be an ordinary eight-byte RIP-relative read at the exact
cell start, with no index, segment override or memory write. Address formation,
partial/interior reads and direct/indirect transfers do not pass this pointer-load
consumer. Register propagation and subsequent referent accesses remain separate
whole-function obligations. The prequalified signed field association supplies
the relocation domain and instruction placement.

The result is the full cell range, published only after every check succeeds.
Inputs and Err are preserved. The function allocates/copies no payload and keeps
only fixed private scalar records; it retains no owner and is reentrant. Existing
name lookup, byte/event admission, cancellation and section traversal costs apply,
plus one initial inspection event, eight prefix bytes, the two name spans and
eight cell bytes. Isolation visits at most the existing 96-section limit. No
numeric cap or lowering traversal bound changes.

Malformed caller shapes use 1509; candidate identity, content, access or permission
mismatches use 1506. Budget/cancellation use the existing 1502/token7 and 1507 paths.
Qualification requires literal independent images, full output preservation,
name/anchor/permission/content/access mutations, exact measured budgets and all
cancellation points, allocation independence, root refusal and faulty-result
controls. The retained image matrix must compare the cell/referent association
independently and preserve the earlier generated/signed-target checks.

Import/IAT and TLS metadata, register propagation, global data aliases, complete
function/stack/debug semantics, build ownership and final native acceptance remain
required. This cell check does not establish PE relocation-directory processing
or loader behavior for a rebased image; those remain image/runtime obligations.
