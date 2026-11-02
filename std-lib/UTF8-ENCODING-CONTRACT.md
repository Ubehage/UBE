# UTF-8 scalar encoding

Implementation: [Utf8Encoding.bas](src/portable/Utf8Encoding.bas). Its maintained
gate is `powershell -NoProfile -File std-lib/tools/check-scalar-storage.ps1
-SelectionPath <selection.json>`, using both verified source-built stages and
writing reports beneath `bootstrap/out/scalar-storage/`. Coordinated source-cohort
acceptance remains necessary after a source change. The encoder is a generic text facility.
Identifier syntax, folding, normalization and compiler policy remain elsewhere.

`TryEncodeUtf8Scalar(ByVal Scalar As Long, ByRef B0 As Byte, ByRef B1 As Byte,
ByRef B2 As Byte, ByRef B3 As Byte, ByRef ScalarWidth As Long) As Boolean`

True encodes exactly one Unicode scalar value as UTF-8, sets ScalarWidth1..4 and returns
four byte slots with unused slots zero. U+0000 is valid and produces one zero
byte. Noncharacters/unassigned code points remain valid scalar values; surrogate
code points do not. A negative value, U+D800..DFFF or a value above U+10FFFF
returns False while preserving all five outputs and Err.

The operation allocates/copies nothing, registers no managed roots, retains no
reference/global state, and preserves Err on success and failure. Outputs must
be distinct caller-owned writable scalars. Calls are reentrant/thread-safe with
independent outputs; callers synchronize any shared mutable destination. Ordinary
caller lifetime rules apply if an output is inside an owned field/array.

The encoder is ordinary UBE. The native gate checks exact hand-authored byte boundaries,
unchanged failure outputs, actual zero resource use and operation counts through
both source-built stages, including a completely full actual root registry.
