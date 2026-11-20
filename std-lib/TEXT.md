# String values and portable text

UBE String values contain immutable Unicode text. Assignments and ByVal calls
have value semantics; callers do not allocate or free their backing storage.
Empty text is the neutral value. The compiler links precise tracing support
into programs that use managed values, without a separate runtime installation.

The current text surface includes variable-length String literals and values,
`&` concatenation, binary comparisons, and conversions involving the admitted
Boolean and integer types. Strings can occur in admitted records, arrays,
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

The same module implements `Concat`, `CompareBinary`, `FromInteger`,
`FromBoolean`, `ToInteger` and `ToBoolean` for the compiler's admitted
conversions. Numeric text follows invariant language rules, including exact
decimal/exponent parsing and ties-to-even integer rounding. Algorithms remain
ordinary UBE code; native roles provide storage and synchronization.

`Memory.CollectGarbage()` requests a synchronous collection. It returns 1 when
managed storage is reclaimed and 0 when there is no such work. Allocation
pressure also invokes collection automatically before one retry. Live values
remain reachable through exact roots, including retained worker captures and
old array payloads still owned by an element alias.

This increment does not implement Variant, fixed-length String, additional
numeric families, text-folding/Like, objects or the broad-input compatibility
functions such as Len and CStr. Their established definitions remain in force;
these typed functions do not narrow or replace them.

See [native acceptance tests](../runtime/tests/managed-text/README.md),
[runtime contracts](../runtime/managed-memory.md) and
[compiler progress](../compiler/Progress.md) for commands, evidence and remaining
integration work. The normative rules are in
[the language specification](../lang-doc/language-spec.md) and
[managed memory](../lang-doc/managed-memory.md).
