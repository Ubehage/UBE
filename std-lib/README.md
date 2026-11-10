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
required by this capacity-limited helper; it does not grow the destination.

`BufferPrimitives.TryResizeBytes` binds `Array.TryResize` and
`BufferPrimitives.TryCopyBytes` binds `Array.TryCopy`. These return usable Boolean
status and publish replacement storage only on success. Resize uses zero-based
bounds and optionally preserves the intersection of old and new logical indices.
Copy preserves the source bounds and produces an independent value. Negative
resize count records Err 5; allocation or storage-limit failure records Err 7.
Success leaves the Err record unchanged. These declarations do not add a growing
append algorithm; the ordinary AppendBytes contract stays capacity-limited.

The bounded compiler admits fixed and dynamic rank-one scalar/finite-record
arrays. Default dynamic values are empty. Managed text, reference-bearing records
and general collection remain separate dependencies. The [runtime inventory](INVENTORY.md) and
[per-name ledger](VB6-RUNTIME-INVENTORY.md) describe the wider planned surface;
these two modules do not implement that full inventory.

The [counted-buffer gate](../bootstrap/tests/counted-buffers/README.md) compiles
these actual modules with native O0/O2 fixtures. Its 25 groups passed on
2026-11-10, including record-only primitive failure versus ordinary AppendBytes
FAIL, overlap, validation and publication behavior.

The [dynamic-storage gate](../bootstrap/tests/dynamic-storage/README.md) passed
41 groups on 2026-11-10, covering growth, independent replacement, allocation
failures, production page quota, cleanup and live element aliases at O0/O2.
