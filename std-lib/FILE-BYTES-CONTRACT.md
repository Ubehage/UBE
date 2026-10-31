# Recoverable byte-file contract

The first source consumer requires byte files, not bootstrap String transport.
This contract specifies the bounded Windows bootstrap adapter and ordinary UBE
orchestration. Full Library envelopes and general language cancellation are not
claimed. Paths are counted strict UTF-8 Byte arrays. Empty paths, embedded zero,
malformed UTF-8 and more than 32,767 UTF-16 code units are rejected. No Unicode
normalization or case folding occurs. Windows opening uses the wide API.

`File.TryOpen(ByRef Path() As Byte, ByVal Limit As Long, ByRef Token As Long,
ByRef Length As Long, ByRef Failure As Long) As Boolean` requires Token zero,
nonnegative Limit and distinct scalar outputs. It opens a regular disk file,
queries its 64-bit size and rejects size above Limit before allocating any read
payload. Success publishes a positive opaque token and bounded Long length.
Ordinary failure preserves Token and sets Length zero. If closing a rejected
native file itself fails, False/Failure 7 returns a live positive Token for caller
cleanup; metadata/token are reserved before opening so this path allocates nothing.
Callers must retain that owner even when opening reports failure.
Tokens are monotonic, never reused
or wrapped, validated against the live registry, and never native addresses.

`File.TryRead(ByVal Token As Long, ByRef Destination() As Byte, ByVal Start As Long,
ByVal Count As Long, ByRef ReadCount As Long, ByRef Failure As Long) As Boolean`
borrows the reader and destination for one call. Start counts from the array's
first payload byte, independently of its lower bound. Count is 0..65,536 and
must fit the destination. Success writes exactly ReadCount bytes, 0..Count;
positive short reads are progress and zero is EOF. Failure leaves destination
unchanged and returns ReadCount zero. Bytes beyond ReadCount are unchanged.
The caller exclusively owns mutable destination storage throughout the call.

`File.TryClose(ByRef Token As Long, ByRef Failure As Long) As Boolean` explicitly
releases the resource and sets Token zero. Zero is an allocation-free successful
no-op. Invalid/stale nonzero tokens fail safely. A real native close failure
retains the token and ownership for retry; callers must not discard that owner.
Registry admission rejects simultaneous read/close of the same token as Busy;
independent readers perform I/O without a shared registry or collector lock.

`Process.TryArgument(ByVal Index As Long, ByRef Result() As Byte,
ByRef Failure As Long) As Boolean` returns an independent exact UTF-8 byte array
for the zero-based argument excluding the executable. Windows wide command-line
parsing supplies the input; CRT narrow argv is not used. Failure preserves Result.
The adapter uses the Windows system shell parser and closes its temporary system
library/module allocation on every path. No new third-party dependency is added.

All calls return fresh Boolean status. Success preserves incoming thread-local
Err; failure records Err and a fresh Failure code. Scalar outputs must not alias
one another or mutable record/array fields used by the operation. The domain is:
0 success, 1 invalid request, 2 invalid path, 3 open/query failure, 4 too large,
5 read failure, 6 premature EOF, 7 close failure, 8 allocation failure,
9 invalid/stale token, 10 cancellation, 11 input grew, 12 missing argument,
13 reader busy. Err is 7 for allocation, 6 for size/overflow, 5 for invalid
request/path/token/argument/busy/cancellation, and 57 for file I/O failures.
`Error.Set(ByVal Number As Long) As Boolean` records an explicit positive error
number and returns False, allowing ordinary UBE to publish policy failures after
cleanup; it does not infer anything from earlier Err.

The source consumer uses a private ByteBuffer and reusable 4,096-byte chunk,
reads the opened size, accepts positive partial reads, rejects premature EOF,
and probes one extra byte to reject growth. It closes before snapshot publication.
Existing Result remains unchanged on every failure, including snapshot allocation
and publication. A failed read's primary Failure is retained through cleanup.
The stepwise API lets callers implement cancellation by explicitly closing their
owned token; no cancellation scheduler or shared Boolean flag is added. This
module deliberately adds no second whole-file convenience API.

Ordinary growth, progress, size policy and publication live in UBE. The C file
under src/win-lib is a bootstrap exception for OS entry, checked token lifetime,
rooted Byte-array access and OS text conversion. Replace it when UBE/platform
declarations and compiler-emitted support pass the same gates; it must never
become a C whole-file loader. Managed arrays use the existing precise-root,
failure-atomic allocation/copy substrate. External resources are not GC cleanup.

Costs: a reader owns one 65,536-byte native scratch allocation after size
acceptance. Each read performs one OS call and copies only returned bytes into
the caller's existing array. Registry lookup measures live readers, not payload
length. The UBE loader reads N+1 bytes at most, performs N chunk-append copies,
less than 2*N geometric-growth copies, and at most 2*N snapshot copies; native
scratch publication adds N, for less than 6*N payload copies (separate zeroing).
Allocation, copying, native read count and resource balance must be observed,
not manufactured from file size. The input may change during loading; this is
not an atomic filesystem snapshot and same-length concurrent edits are possible.
