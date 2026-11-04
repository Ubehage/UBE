# Retained native leaf correspondence

This implements the pending leaf correspondence check under First checked native
executable. Inputs are the successful retained one-byte definition anchors, their
qualified function fences, and immutable successful leaf traversals over those
same object/image snapshots. The production build owner must preserve those
associations and lifetimes, as for the existing symbol and extent readers.

TryBindNativeLeafExtent checks that each fence matches every anchor field except
its expanded byte counts; both are initialized readable/executable/nonwritable
code. Each leaf must be ready, own arrays matching its fence capacity, start at
that fence's file offset and have a positive extent within it. Object and image
must have equal positive extents and instruction counts. Their maps must agree
at every byte of that extent, contain only unreachable/start/continuation marks,
start at an instruction, end at a reachable byte and contain the declared number
of instruction starts. Different fence sizes and trailing padding are permitted.
Unreachable interior bytes remain explicitly represented as zero marks.

The result is a NativeRetainedDefinition with both one-byte ranges expanded to
the complete common leaf extent; all other anchor fields are preserved. It is
published only after all checks pass. There is no allocation, payload copying,
mutable shared state or resource ownership. Err and all input owners are preserved.
For extent L, success reads exactly 2L map bytes in 2L+1 inspection events, with
cancellation before each admission and fixed scalar workspace. Existing caps and
declaration/body/argument work bounds remain unchanged. Invalid/unready owners use
1509; correspondence or map disagreement uses 1506; budget/cancellation use the
existing 1502/resource 7 and 1507 failures. Old output is unchanged on failure.

Focused tests must distinguish equal extents with different maps, verify anchor
association, handle multiple returns/loops/unreachable gaps, check exact budgets,
all cancellation positions, allocation independence and root refusal. Actual
linked cases must compose retained-name binding, once-prepared address indexes,
function fences, both leaf walks and this binder, then compare against independent
object-side disassembly expectations. Altered image flow must reject at this
binding check even when it remains independently decodable as a leaf.

Equal maps do not prove equal instructions, branch destinations, memory operands
or relocation targets. Instruction/fixup correspondence, unwind and stack/reserve
proofs, startup/API/refusal closure, debug checks, integrated build ownership and
publication remain required. This is not a new whole-function safety claim.
