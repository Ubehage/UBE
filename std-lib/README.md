# UBECore standard library

UBECore provides ordinary language-support algorithms as UBE source, with a
narrow compiler intrinsic and platform boundary. [UBECore.UBE](UBECore.UBE)
contains its current portable counted-buffer modules.

`BufferPrimitives.ByteStorageLength` binds `Array.Length` and returns the logical
element count. `BufferPrimitives.CopyByteRange` binds `Memory.CopyBytes`; offsets
are relative to the payload start regardless of language lower bounds. It
validates complete spans before writing and handles overlapping ranges.

CopyByteRange returns an ordinary usable Boolean. Invalid count returns False
with Err 5; invalid offsets/spans return False with Err 9. Failure preserves the
destination; success preserves the previous Err record. False does not transfer
to an On Error handler by itself.

`ByteBuffers.AppendBytes` is ordinary UBE code. It validates the destination's
used count and capacity, copies the requested source span, and publishes Used
only after success. It returns the new count. Negative Used/Count values raise
Err 5, and insufficient capacity raises Err 9; primitive failure is explicitly
raised by the wrapper. Those raises return language FAIL immediately, so caller
assignment/handler rules apply. No allocation or external resource cleanup is
required by this fixed-storage helper.

The bounded compiler currently admits fixed rank-one arrays. Dynamic growth,
default empty arrays, allocation/collection, managed text and additional storage
roles remain separate dependencies. The [runtime inventory](INVENTORY.md) and
[per-name ledger](VB6-RUNTIME-INVENTORY.md) describe the wider planned surface;
these two modules do not implement that full inventory.

The [counted-buffer gate](../bootstrap/tests/counted-buffers/README.md) compiles
these actual modules with native O0/O2 fixtures. Its 25 groups passed on
2026-11-10, including record-only primitive failure versus ordinary AppendBytes
FAIL, overlap, validation and publication behavior.
