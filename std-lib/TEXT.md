# String values and portable text

UBE String values contain immutable Unicode text. Assignments and ByVal calls
have value semantics; callers do not allocate or free their backing storage.
Empty text is the neutral value. The compiler links precise tracing support
into programs that use managed values, without a separate runtime installation.

The current text surface includes variable-length String literals and values,
`&` concatenation, binary comparisons, and conversions involving the admitted
Boolean, integer, Single and Double types. Strings can occur in admitted records, arrays,
parameters, results and worker captures. Comparison uses text content rather
than backing-storage identity.

The ordinary UBE module `Text` provides these typed byte-boundary operations:

```vb
Public Function Length(ByRef Value As String) As LongLong
Public Function FromUtf8(ByRef Bytes() As Byte, ByVal Offset As Long, ByVal Count As Long) As String
Public Sub ToUtf8(ByRef Value As String, ByRef Result() As Byte)
```

`Length` counts Unicode scalar values, including embedded zero. `FromUtf8`
imports a logical byte span using strict UTF-8 validation. It snapshots the
input before validation, retains embedded zero and BOM characters, and rejects
malformed encodings. `ToUtf8` produces an independent zero-based Byte array;
it replaces the destination only after successful preparation.

Successful operations preserve Err. Invalid spans report Err 9, negative
counts Err 5, malformed UTF-8 Err 13, and exhausted allocation Err 7. Ordinary
FAIL propagation preserves an unfinished assignment's previous destination.

Custom algorithms may also use `TextPrimitives.TryCreate`, `TryWriteByte`,
`TryCandidateInfo`, `TryReadCandidateByte`, `TryPublish` and `TryAbandon`.
Candidate handles are checked identities, not backing addresses. Reads and writes
require an unpublished candidate owned by the calling thread. `TryPublish`
checks strict UTF-8 and the declared scalar count through installed UBE support
before committing the destination. Invalid encoding/count reports Err 13 and
preserves both the destination and the candidate, permitting repair and retry.
Consumed, abandoned and foreign-thread candidates are rejected. Successful
publication makes the String immutable. Raw `Text.Commit` is support-only and
cannot be acquired through an ordinary copied or renamed declaration.

The same module implements `Concat`, `CompareBinary`, `FromInteger`,
`FromBoolean`, `ToInteger`, `ToBoolean`, `FromFloating` and `ToFloating` for the compiler's admitted
conversions. Numeric text follows invariant language rules, including exact
decimal/exponent parsing and ties-to-even integer rounding. Algorithms remain
ordinary UBE code; native roles provide storage and synchronization.

Single and Double text conversions accept finite values only. Formatting uses
the shortest significant decimal representation that parses back to the same
value and preserves negative zero as `-0`. Parsing rejects malformed text and
Infinity/NaN spellings with Err 13, and out-of-range finite values with Err 6.
The `BinaryFloat`, `BinaryFloatValues`, `BinaryFloatText`, `BinaryFloatMath` and
`BinaryFloatPower` modules implement shared numeric algorithms in ordinary UBE;
they do not introduce new VB6 compatibility function names. Exact spelling,
rounding and acceptance evidence are in
[Single/Double support](../compiler/FLOATING-POINT.md).

`Memory.CollectGarbage()` requests a synchronous collection. It returns 1 when
managed storage is reclaimed and 0 when there is no such work. Allocation
pressure also invokes collection automatically before one retry. Live values
remain reachable through exact roots, including retained worker captures and
old array payloads still owned by an element alias.

This increment does not implement Variant, fixed-length String, Currency,
Decimal, text-folding/Like, objects or the broad-input compatibility
functions such as Len and CStr. Their established definitions remain in force;
these typed functions do not narrow or replace them.

See [native acceptance tests](../runtime/tests/managed-text/README.md),
[runtime contracts](../runtime/managed-memory.md) and
[compiler progress](../compiler/Progress.md) for commands, evidence and remaining
language work. The normative rules are in
[the language specification](../lang-doc/language-spec.md) and
[managed memory](../lang-doc/managed-memory.md).
