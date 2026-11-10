# Counted byte output contract

Status: implemented with scoped native acceptance in compiler/Progress.md. These operations extend
the explicit ownership and failure domain in FILE-BYTES-CONTRACT.md.

The owner approved exclusive writable-file creation on 2026-11-10:

```vb
Public Intrinsic Function TryCreateByteFile(ByRef PathUtf8() As Byte, ByRef Token As Long, ByRef Failure As Long) As Boolean
Attribute TryCreateByteFile.UBE_Primitive = "File.TryCreateNew"
End Function
```

Procedure spelling is arbitrary. Require Token zero and valid counted UTF-8.
Create a new file exclusively; an existing path must fail without truncation
or modification. Reserve metadata and adapter storage before OS acquisition.
Publish a writable token only after admission. A failed cleanup close returns
a live token and Failure 7 as with TryOpen. A failed later write may leave a
partially written newly created file. This operation does not promise atomic
publication, replacement, rollback or deletion on close.

TryWrite and TryFlush have the exact normative signatures in language-spec.md.
They require a live writable owner; read-only owners cannot write or flush,
and write-only owners cannot read. No integer is adopted as a native handle.
TryWrite validates the entire source span before touching the file, using the
same logical offsets and count ceiling as TryRead. Scalar outputs are distinct
and cannot alias input storage. Zero count still validates ownership and range
but performs no OS write.

For a positive count, perform one OS write. Success reports WrittenCount in
0..Count. A short positive write is progress; ordinary UBE must supply the
remaining suffix. Zero progress is observable and a whole-output helper must
reject it rather than loop forever. Failure reports only confirmed progress,
zero when none is confirmed. It does not promise rollback of file contents.
The source array is unchanged on every path. Its borrowed storage must not be
mutated, resized or released concurrently.

The approved bootstrap representation requires bounded packing from i64 Byte
cells into OS byte storage. Observe the actual copied bytes and scratch lifetime
in tests; do not inherit historical zero-copy assertions. No newline, encoding
conversion, terminator or hidden whole-file loop is added to TryWrite.

TryFlush performs one FlushFileBuffers call and neither closes the owner nor
promises atomic replacement or power-loss durability. Failure codes 15 and 16
denote write and flush failure, both recording Err 57. Success sets Failure 0
and preserves Err. TryClose retains its owner on native release failure.

Ordinary UBECore code owns partial-progress loops and explicit flush policy.
The caller retains the token until successful close, including after a failed
write or flush. Preserve the primary error through cleanup. Tests must check
independent byte readback, existing-file preservation, short/zero/failed writes,
flush failure, retained ownership after close failure, and record-only status
versus a subsequent explicit language Raise.

This is ordinary file acquisition. It does not replace NativeBackend's guarded
staging and executable publication, qualify a general stream framework or
introduce new source-language file statement syntax.
