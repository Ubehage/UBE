# UBECore standard library

UBECore provides ordinary language-support algorithms as UBE source, with a
narrow compiler intrinsic and platform boundary. [UBECore.UBE](UBECore.UBE)
contains its current portable counted-buffer and file-I/O modules.

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
these modules do not implement that full inventory.

The [counted-buffer gate](../bootstrap/tests/counted-buffers/README.md) compiles
these actual modules with native O0/O2 fixtures. Its 25 groups passed on
2026-11-10, including record-only primitive failure versus ordinary AppendBytes
FAIL, overlap, validation and publication behavior.

The [dynamic-storage gate](../bootstrap/tests/dynamic-storage/README.md) passed
41 groups on 2026-11-10, covering growth, independent replacement, allocation
failures, production page quota, cleanup and live element aliases at O0/O2.

`FilePrimitives` declares explicit open, exclusive create, read, write, flush
and close operations plus record-only Error.Set. Paths are strict UTF-8 bytes;
contents are uninterpreted bytes. A failed close keeps the live token so the
caller can retry. Exclusive creation never truncates an existing file.

`FileBytes.TryReadAllBytes` is ordinary UBE code. It reads up to the smaller of
MaximumBytes and 4,096, accepts partial progress, detects premature EOF/growth,
and closes before publishing an independent Result. Failure preserves Result
and returns any still-live Token to the caller for cleanup. Token must start
at zero; scalar outputs must not alias. `FileBytes.TryWriteAllBytes` advances
by confirmed progress, rejects zero progress and flushes. The caller still
owns the file and must close it, including after failure.

The [file gate](../bootstrap/tests/file-io/README.md) checks actual UBE source
at O0/O2 with independent byte readback and injected allocation/I/O failures.
The contracts are [FILE-BYTES-CONTRACT.md](FILE-BYTES-CONTRACT.md) and
[FILE-OUTPUT-CONTRACT.md](FILE-OUTPUT-CONTRACT.md). Byte packing is explicit
and measured; no zero-copy claim is made for this bootstrap representation.

`FilePrimitives` declares counted open, exclusive create, read, write, flush and
close roles plus record-only `Error.Set`. Callers explicitly own and close tokens;
a failed close leaves ownership available for retry. `FileBytes.TryReadAllBytes`
is ordinary UBE policy: it clamps the requested maximum to the current 4096-byte
array capacity, accepts partial progress, rejects premature EOF or growth,
closes before publishing an independent result, and preserves primary errors
through cleanup. Its Token output retains any failed-close owner.

`FileBytes.TryWriteAllBytes` advances through confirmed partial writes, rejects
zero progress and flushes on completion. It leaves the caller's explicit token
open. Both helpers return usable Boolean status; they do not raise automatically.
The [file-I/O gate](../bootstrap/tests/file-io/README.md) compiles and executes these
actual modules, including independent native-file readback and controlled target
failures.
