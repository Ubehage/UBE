# Native import-address association

This implements the next import association from the reviewed native target plan.
It reuses existing PE header, section, symbol-anchor and inspection machinery and
adds no public language ABI, owner arena or compiler phase.

TryReadNativeImageDirectory shares the existing function-table header checks and
reads one of the 16 standard directory slots. An absent slot yields two zeros;
the raw fields are not interpreted as a mapped range by this helper. Callers own
directory-specific size/absence rules. TryLocateNativeImageSpan is moved unchanged
from NativeUnwind to NativeObjects and shared. TryLocateNativeImageRange constructs
an anonymous fully initialized range from that same unique-section mapping. The
function-table reader retains its prior meaning and measured inspection costs.

TryBindNativeImportTarget consumes a qualified decoded instruction, named one-byte
target anchor and signed effective position, frozen DLL/function name spans in
one immutable byte arena, and the associated image bytes/layout. These caller
associations remain preconditions. DLL comparison folds ASCII through the existing
Unicode scalar fold; function names compare exactly. Frozen names are ASCII and
nonempty; caller span shapes are checked before use.

The access must read eight bytes at the exact IAT slot through RIP-relative
addressing, with no index, segment override or write. Ordinary reads and indirect
calls/jumps are admitted for association only; signatures, subsequent register
values and tail-call legality remain later obligations.

The selected profile requires ordinary unbound, named PE32+ imports. Import and
IAT directories must be present; bound-import and delay-import directories must
be absent. Descriptors and aligned eight-byte thunk tables must terminate within
their mapped initialized storage. Lookup and on-disk IAT entries must agree.
Ordinal/reserved-bit encodings, nonzero binding/forwarder fields, malformed names
and ambiguous ownership of the target slot reject. All descriptors are examined,
including after finding the requested slot. Null descriptor padding must stay zero.

The target's complete range must agree with its anchor, be initialized readable
nonexecuting nondiscardable data, and pass existing contribution isolation. IAT
storage may be writable or read-only. Import descriptors, DLL/hint names and
lookup tables may not overlap the IAT directory; the selected target slot must
be owned by exactly one descriptor/thunk entry with the frozen DLL/function name.
This protects the metadata used for the association from IAT writes. It does not
qualify every other runtime import, CRT behavior or arbitrary image aliases.

All inputs are borrowed immutable owners; the result is a scalar range published
only on complete success. The consumer allocates/copies no payload, retains no
owner, is reentrant and preserves Err. Existing inspection byte/event budgets and
cancellation apply to every read and section scan. Descriptor, thunk and string
traversals are bounded by their admitted byte extents, with at most 96 sections
per range lookup. No numeric cap or lowering traversal bound changes.

Caller-shape errors use 1509; candidate access, directory, mapping, name, value or
ownership mismatches use 1506. Resource/cancellation paths retain 1502/token7 and
1507. Qualification requires independent literal images, changed names/slots/
permissions/terminators, aliased metadata and duplicate target ownership, exact
budgets, cancellation, allocation independence, root refusal, atomic output and
faulty-result controls. Retained-image tests must independently compare all 80
generated import references through both readers and retain prior target gates.

TLS index/template association, pointer/register propagation, image rebasing,
remaining global aliases, CRT callbacks/startup, full function/stack/debug meaning,
build ownership and final native acceptance remain required.
