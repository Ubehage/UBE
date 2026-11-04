# Counted byte output dependency

Implementation contract for the counted output dependency selected by
`../compiler/UBE_Compiler_v3/NATIVE-RESOURCE-CONTRACT.md`. This extends the
existing explicit file-token ownership model. It does not qualify executable
publication, add a general stream framework, change source intake, or introduce
a path-opening fallback around the reviewed native-build path guards.

## Operations and ownership

The concrete UBECore declarations to implement in `FileBytes` are:

```vb
Intrinsic Function TryWriteByteFile(ByVal Token As Long, ByRef Source() As Byte, ByVal Start As Long, ByVal Count As Long, ByRef WrittenCount As Long, ByRef Failure As Long) As Boolean
Attribute TryWriteByteFile.UBE_Primitive = "File.TryWrite"
End Function

Intrinsic Function TryFlushByteFile(ByVal Token As Long, ByRef Failure As Long) As Boolean
Attribute TryFlushByteFile.UBE_Primitive = "File.TryFlush"
End Function
```

These are bounded bootstrap bindings using the existing explicit attribute and
exact-signature validation mechanism. Replace their native implementation when
UBE platform declarations and compiler-emitted support pass the same tests.
They add no special procedure-name recognition and no source-language syntax.

The token must own a writable regular disk file admitted by its producer. The
native-build producer must reserve token metadata before acquiring the file,
create it exclusively relative to the reviewed held directory, and publish
ownership only after admission. A test may use a private native producer to
exercise the writer before that path boundary exists. Such a test does not
qualify production path acquisition. The counted writer must never reopen a
pathname or adopt a source-language integer as a native handle.

Read and write owners share the existing monotonic nonreused token namespace,
busy admission and explicit `TryCloseByteFile` release. A read-only token
cannot be written or flushed; a write-only token cannot be read. Independent
files perform OS I/O without a held registry/collector lock. Concurrent
operations on one token reject as Busy; they do not queue or race close.

Write borrows an immutable caller-owned Byte array, pins its exact existing
payload for the native call and releases the pin on every return. The caller
retains its snapshot and must not mutate, resize, replace or release it during
that borrow. Start is relative to the first payload byte, independent of the
array's language lower bound. Validate the complete range before any I/O:
Start is nonnegative, Count is 0..65536, and Start+Count fits without overflow.
Zero count permits the end offset, including Start=0 in a neutral empty array;
it still validates the writable token, then succeeds without an OS write.
Scalar output arguments are distinct and do not alias input storage.

One positive-count operation performs one native write. Success returns a
fresh True with WrittenCount in 0..Count. Positive short writes are progress;
the ordinary UBE caller advances by the confirmed count and supplies the exact
remaining suffix. Zero progress is observable; a whole-output consumer must
reject it rather than loop indefinitely. No terminator, newline translation,
encoding conversion, hidden buffer snapshot or whole-file loop is added.

Failure returns False and a fresh Failure code. WrittenCount reports only
confirmed bytes in 0..Count, zero when no progress is confirmed. It is not a
rollback guarantee: failed I/O may have changed the owned temporary file, so a
compiler consumer abandons publication rather than guessing or blindly retrying.
The source array is unchanged. The file owner and its current position remain
live until explicit close. Preserve the primary write/flush failure through
cleanup and separately report a failed close with its retained token.

Flush borrows the writable token and performs one native FlushFileBuffers call.
It neither closes the file nor promises atomic replacement or power-loss
durability. Close retains the existing contract: successful release zeroes the
token; failed release retains the owner for retry; zero is a successful no-op.
Compiler code checks cancellation before and after each bounded operation.
These synchronous file calls do not establish an elapsed-time cancellation
guarantee or the separately reviewed diagnostic-delivery thread boundary.

## Failure domain and costs

Keep FILE-BYTES-CONTRACT.md's existing codes and add 15 for write failure and
16 for flush failure; both record Err 57. Existing request/path/token/Busy,
allocation and close codes retain their meanings. Success returns Failure=0
and preserves prior Err. Initialize WrittenCount=0 before validation except
when the output pointers alias and no distinct output can safely be written.
Reject invalid/stale tokens and wrong access modes before an OS operation.

Write/flush allocate no payload, copy no source bytes and retain no managed
reference after completion. Token metadata belongs to the file owner, not to
each write. Observe actual native calls, confirmed byte counts, payload copies,
pins and live handles in tests. Do not infer zero copying merely from length
or count formulas. Ordinary UBE handles chunking and partial progress.

## Independent acceptance cases

Before qualification, test the actual operations and exact UBE declarations
through both selected source-built stages, with unchanged-input identities:

- all byte values, embedded zeros, empty/default arrays, nonzero lower bounds,
  exact subranges, end offsets, 65536 bytes and rejected 65537 bytes;
- negative/overflowing offsets and counts, null/aliased outputs, stale tokens,
  read/write mode mismatch and Busy, with no accidental I/O;
- preseeded Err 7/77 preserved on success and exact fresh failure codes;
- real partial writes, injected positive short writes, zero progress and write
  failure, with independently read-back bytes and unchanged source payload;
- flush success/failure, close failure and retry, including ownership and pin
  retention/release on every branch;
- allocation/root pressure, independent concurrent owners, same-token conflict,
  and cancellation between calls with explicit cleanup;
- actual call/copy/allocation observations and controls that reject an omitted
  write, changed byte, wrong count, untriggered injected failure or lost owner.

The guarded native producer and final executable publication remain separate
required integration tests. Passing this dependency is not completion of the
First checked native executable goal.
