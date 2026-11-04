# Checked little-endian byte decoding

Concrete portable dependency of native object/image inspection. `BinaryBytes`
contains ordinary UBE conversion, no file-format policy or new primitive.

`TryReadLittleEndianBits(ByRef Bytes() As Byte, ByVal First As Long,
ByVal Width As Long, ByRef Value As LongLong) As Boolean` borrows an immutable
zero-based byte array for one call. Width is 1..8, and the whole byte range must
exist. Nil/empty arrays, negative offsets, invalid widths and truncated ranges
return False, preserving Value and Err. Bounds use subtraction before addition.
Successful reads preserve Err and the input owner/content. Outputs must not
alias input storage. The caller retains the input owner during the call.

Widths 1..7 return the nonnegative integer encoded by those bytes. Width 8
returns the exact 64-bit bit pattern in LongLong's two's-complement
representation, including negative values when bit 63 is set. Format consumers
that require a nonnegative offset/address reject negative results explicitly.
This is not a new unsigned language type or an implicit signed-width conversion.

Decoding reads exactly Width bytes, uses constant scalar workspace, allocates
and copies no payload, retains no references and has no mutable globals or I/O.
Independent calls and shared immutable inputs are reentrant. Existing managed
entry/root failures remain controlled; a refused entry cannot publish a result.
Sign-first accumulation keeps every intermediate representable, including the
minimum and maximum LongLong, without negating the minimum or overflowing a
positive accumulator. No input-controlled recursion is used.

Qualification requires independent expected vectors across widths/offsets and
64-bit boundaries, malformed/truncated ranges, output/Err/input preservation,
actual byte-visit counts, allocation/copy observations, root pressure and
allocator denial, plus identical raw output from both bootstrap stages.
