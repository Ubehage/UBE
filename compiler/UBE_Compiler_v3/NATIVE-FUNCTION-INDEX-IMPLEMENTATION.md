# Native function address index and code fences

This is the pending retained-definition/leaf-fence prerequisite of First checked
native executable. The focused retained-artifact diagnostic in
bootstrap/out/native-function-order-diagnostic.json inspected 144 objects and 16
images: every image's function symbols are unordered by section/address and has
an address alias. A file-order successor or rejection of all aliases is unsuitable.

NativeFunctionIndex borrows one immutable, prepared NativeSymbolInventory and its
layout. Preparation visits primary symbols once, selecting positive-section,
EXTERNAL/STATIC TypeCode 32 definitions. It sorts section/address keys with the
existing UBECore budgeted byte-key ordering. Four-byte big-endian unsigned COFF
values represent address order within the section partition. Equal-address aliases
remain valid. Query uses an upper-bound binary search to find the next strictly
greater address in the same section, or the section's initialized end.

TryReadNativeFunctionFence consumes a one-byte NativeDefinitionRange anchor. It
checks the exact primary symbol, section, offset, initialized file start, flags
and image addresses, then returns that range expanded to the conservative fence.
The next symbol only bounds traversal: it does not establish the function extent.
The existing reachable-instruction walk must compute that extent. Interior labels
without function type are not function boundaries. Sections must be readable,
executable, nonwritable and initialized at the anchor. Both object and PE layouts
are supported. Escaping, nonpositive or mismatched ranges reject with 1506.

The owner must be fresh/zero before preparation. It owns temporary 16P-byte keys
and 4P-byte address bytes, where P is primary count, plus the library's 8F-byte
sort workspace for F selected functions. At sort success 4F bytes remain as order;
order entries are remapped to raw symbol indexes, then temporary key/address
arrays are released. Retained payload is 4F, peak <= 20P + 8F. Every allocation
is admitted through both inspection storage and global payload ledgers first.
Library sorting copying remains measured; no symbol or input bytes are copied.
Status 4 denotes partial/unqualified state; status 1 publishes the complete index.
TryDisposeNativeFunctionIndex releases successful or partial ownership, including
each charge. Invalid/nonfresh input rejects unchanged. No numeric cap increases.

Primary visits, address encoding, order remapping, allocations and each binary
search comparison are cancellable inspection events. Sort reads/events reuse the
same ledger through ByteKeyBudget. Queries use O(log F) cached symbol reads, one
section descriptor read, fixed scalar workspace, no allocations/copies, and
publish their scalar range only on success. Failure codes follow the existing
inventory contract: 1509 invalid API/owner, 1506 malformed candidate, 1502 resource
refusal (inspection token 7 or the existing global ledger token), 1507 cancellation.
Err and borrowed inputs are preserved. Owners and budgets require the existing
serial build ownership; independent owners can share immutable inventories.

Required gates include independently ordered aliases/sections, malformed anchors,
empty indexes, exact budgets, allocation/cancellation/root refusal and cleanup,
logarithmic lookup observations, and actual object/image fence comparisons.
This index does not bind complete leaf extents, validate relocation equality,
unwind operations, stack safety, debug data or executable publication.
