# Unicode scalar codec contract

Status: implemented and qualified at O0/O2 through both the bootstrap and
UBE-written compiler; evidence is in tests/unicode-scalars/README.md and
../compiler/Progress.md. This extends the existing
portable Utf8 module under the compiler's complete-language roadmap item.

```vb
Public Function TryDecodeScalar(ByRef Bytes() As Byte, ByVal Offset As Long, ByVal Length As Long, ByRef Scalar As Long, ByRef ByteWidth As Long) As Boolean
Public Function TryEncodeScalar(ByVal Scalar As Long, ByRef Destination() As Byte, ByVal Offset As Long, ByRef ByteWidth As Long) As Boolean
```

These are ordinary UBE functions with usable Boolean results, not implicit
language FAIL. Source/destination storage is zero-based, as for the existing
TrySequenceWidth helper. No String, Variant, locale, BOM stripping, terminator
or Unicode normalization is implicit. U+0000 is a normal one-byte scalar.
All scalar values through U+10FFFF except U+D800–U+DFFF are accepted, including
noncharacters. Overlong encodings, invalid continuation bytes, surrogates,
truncated sequences and values above the scalar maximum are rejected.

Decode uses Length as the logical source end, bounded by physical capacity,
and reads exactly one scalar at Offset. It delegates validation to
TrySequenceWidth. True publishes Scalar and ByteWidth (1 through 4).
False preserves both outputs. Malformed encodings and invalid logical spans
return False without changing Err, matching the validator; unsupported array
bounds or an actual failed indexed access retain the validator's Err 9.
The two output variables must be distinct. Successful decoding preserves Err.

Encode writes the canonical shortest UTF-8 sequence at Offset, only after
validating the scalar, complete destination span and zero-based storage.
True publishes the byte count (1 through 4). False preserves the entire
destination and ByteWidth. Invalid scalar, offset or insufficient capacity
returns False without changing Err, like the existing sequence validator.
Unsupported array bounds or a failed indexed access records Err 9.
Success preserves Err. Both operations leave storage allocation, array bounds
and unrelated bytes unchanged. They allocate no dynamic storage.

Callers keep source bytes stable during decoding and exclusively own the
destination span during encoding. Calls using independent arrays/output
variables are safe concurrently; the algorithms contain no shared mutable
state. Neither operation claims a multi-variable atomic transaction observable
by other unsynchronized threads.

Acceptance requires independent known vectors at every UTF-8 width boundary,
supplementary values and embedded zero, exhaustive scalar round trips checked
against a separate host encoding oracle, all malformed encoding classes,
logical/physical bounds and sentinels, unchanged outputs after rejection,
sticky Err and non-handler Boolean failure, O0/O2 through both compilers,
and existing validator/scanner regression gates.
