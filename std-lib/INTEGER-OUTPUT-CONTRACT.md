# Incremental decimal integer output

Concrete ordinary-UBE dependency of the reviewed native LLVM emitter. The
compiler owns LLVM syntax and output budgets; UBECore owns numeric conversion.
This extends `SignedIntegers` without an intrinsic or a language change.

`BeginDecimalIntegerEncoding(ByVal Value As LongLong, ByRef Encoder As
DecimalIntegerEncoder, ByRef ByteCount As Long)` initializes caller-owned scalar
state and returns the exact 1..20 output byte count. It accepts every LongLong,
including its minimum. Encoder fields are reserved library state. Initialization
replaces any prior state and retains no references.

`TryNextDecimalIntegerByte(ByRef Encoder As DecimalIntegerEncoder, ByRef Value
As Byte, ByRef HasByte As Boolean) As Boolean` emits the next ASCII byte with
fresh HasByte=True, or returns True/HasByte=False when exhausted. Exhaustion
preserves Value and remains exhausted. Neutral state is exhausted. Invalid
state that would cause unsafe arithmetic returns False and preserves all
outputs/state. Callers must not modify reserved fields or alias the arguments.

The complete format is optional ASCII minus followed by decimal digits, with
no leading zeroes, plus, whitespace, separator, terminator or locale dependence.
Zero is exactly `0`. Negative accumulation avoids negating the signed minimum.
Initialization and byte extraction require no managed roots, allocation, copying
of payloads or mutable global state, and preserve incoming Err. Independent
encoders may be used concurrently. The scalar state is a value and can be copied.

Initialization takes at most 19 magnitude comparisons/divisions; extraction
uses constant scalar workspace and at most one digit division and remainder per
byte. There is no input-controlled recursion. The caller owns storage and decides
whether to append a byte, stream it or abandon an unfinished encoding.

Independent acceptance covers zero, both signs, each power-of-ten transition,
the signed minima/maxima at 16/32/64 bits, exact counts and bytes, exhaustion,
restart, independent interleaved encoders, old Err 7/77, and invalid arithmetic
state. Both source-built stages must agree on raw LLVM. A direct call-inventory
check and native full-root/allocator-denial controls distinguish the rootless
algorithm from the compiler's separately managed output buffer.
