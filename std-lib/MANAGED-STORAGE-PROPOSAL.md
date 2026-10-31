# Managed byte-storage decision

Status: approved by the owner on 2026-10-30; implemented and qualified for the
first byte/text subset. Current results are in
[BYTE-BUFFER-EVIDENCE.md](BYTE-BUFFER-EVIDENCE.md).
The owner explicitly authorized extending v2 as much as necessary because its
purpose is bootstrapping, not preserving the generation for its own sake.
The allocation-free
decoder is implemented separately under [the byte/text contract](BYTE-TEXT-CONTRACT.md).

## Approved scope

Implement the compiler-wide managed-value prerequisites in v2 and its
linked support, using ordinary Byte arrays and value records first. Keep byte
growth, validation and text algorithms in UBECore. Do not begin fresh v3
scaffolding or a replacement compiler architecture to get this proof working.

This follows existing array/value and tracing-GC semantics. It does not propose
reference-counted strings, ownership visible as raw addresses, custom destructor
syntax, new compiler generations, or a new `Type As` representation family.
The existing unmanaged scalar mechanism remains qualified only for scalars.

The specific approval boundary is compiler-wide lifetime and root/barrier
handling. [Root AGENTS.md](../AGENTS.md) says: “Ask the repository owner for
explicit approval before making a fundamental, architectural, or system-wide
change.” Focused bootstrap fixes already have permission; introducing managed
lifetimes across procedure entry/exit, temporaries and stores is broader than a
local allocator repair. The owner's subsequent explicit approval satisfies
that boundary; further permission is not required for these prerequisites.

## Evidence before choosing

`std-lib/tools/probe-byte-storage.ps1` executes small independent obligations
through both exact accepted v2 stages. Current results are in
[BYTE-TEXT-EVIDENCE.md](BYTE-TEXT-EVIDENCE.md):

- Byte-array assignment rejects instead of producing an independent copy.
- A value record containing a Byte array also rejects its required copy.
- 1,000 local 16-byte arrays retain 1,000 allocations (40,000 allocated bytes)
  after returning and requesting collection; the desired live count is zero.
- One injected failure exits 70 instead of collecting/retrying successfully
  with the earlier Err preserved; two injected failures also exit 70 instead
  of returning safely with Err 7. This tests ordinary allocation failure, not exhaustion of
  the minimum bookkeeping needed to preserve memory safety.

These are bootstrap limits, not failures hidden by a library wrapper. The
probes leave production compiler/runtime and archived implementation unchanged.
The decoder itself requires none of these managed operations and passes its
separate acceptance suite.

## Recommended mechanism boundary

Use the already specified independent array/record value semantics, rather than
introducing an opaque managed native type immediately. The first owned buffer
can be an ordinary value record containing Byte storage and logical length;
compiler layout and value-copy rules apply uniformly to differently named
records. Capacity is an implementation detail, not an aliasing permission.

Compiler responsibility:

1. Derive exact managed-reference locations from the existing type graph.
   Scalars carry no roots; array storage is a traced reference; a record's
   reference locations are derived from its fields. Do not scan integer bytes.
2. Publish live local/parameter/result/temporary locations before allocation,
   calls and other required safe points. Leave roots on every normal/error
   exit. Root storage has a bounded, explicitly checked allocation policy.
3. Synthesize independent array/record value copying at assignment, ByVal and
   result boundaries. Prepare the new value while the old destination and all
   source/temporary references remain rooted; publish only after success.
4. Generate required barriers and safe managed-reference accesses. Bulk copies
   preserve the same safety guarantees as individual stores. No unsynchronized
   user race may expose freed memory or an invalid reference.
5. Keep unsupported managed families diagnosed until their own proof passes.
   Byte-array success cannot establish objects, recursive records or String.

Linked primitive responsibility:

- Check target-sized bounds and allocation arithmetic before allocating.
- Try allocation, perform the specified collection/retry, and on ordinary
  failure return a fresh Boolean status plus Err 7 while preserving the old
  destination. Success preserves an earlier Err; status never comes from Err.
- Provide compiler-only layout/root/store primitives with explicit ownership
  and scope. No user-callable address or implicit foreign ABI is introduced.
- Reclaim unreachable storage through the normative tracing model. Do not
  replace it with process-lifetime allocation or reference counting.

The current support runtime contains collector code, but its presence is not
qualification. Review and test only the required substrate against the frozen
contract; replace/fix it narrowly if necessary. No archived library/compiler
implementation is imported, and no large historical runtime test result is
inherited. Keep the clean seed source-compatible and retain the existing
source-build fixed point and independent acceptance gates. No temporary
user-facing managed-storage mode or duplicated algorithm is introduced.

## Proof before an owned UBECore builder

Specify exact oracles before implementation. At minimum, prove zero/default
state, actual layout/stride, independent copies/calls/results, a nested live
array surviving collection, dead roots reclaimed after scope/early return,
failure-atomic copying/growth, partial construction cleanup, stale/thread-local
Err, and deterministic allocation/metadata exhaustion. Retain the existing
204 compiler assertions and eight decoder assertions.

Then implement the smallest UBE buffer/builder around the tested primitives.
Use geometric capacity growth with a predeclared linear-copy budget; instrument
the allocator and executed copy operations. Publish decoded immutable text only
after validation. Prove that reusing a builder cannot mutate published text.
Qualify shared immutable input and independent builders concurrently before a
compiler consumer uses them. Full builtin String replacement remains separate
until its managed representation and language bindings are proved.

## Alternative and recommendation

Moving this work into fresh v3 now would require an unproved compiler scaffold
before the library prerequisite is ready. A custom C byte-buffer implementation
would move ordinary library behavior out of UBE. Merely wrapping legacy arrays
would retain the observed copy/lifetime/failure gaps.

Recommend the bounded v2 managed-value prerequisites above, then the ordinary
UBE builder. The owner is being asked to approve that scope; detailed layout
and primitive signatures should be resolved and tested within it.
