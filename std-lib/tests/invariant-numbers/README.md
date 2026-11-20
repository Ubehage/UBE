# Invariant numeric conversion qualification

Run `check.ps1 -CompilerExe <UBE.exe>` against an actual UBE compiler. The gate
builds and runs the ordinary portable `InvariantNumbers` module at O0 and O2.
The PowerShell test oracle uses arbitrary-precision integers and exact rational
rounding; production code does not use host conversion or locale facilities.

`TryParseInteger(Bytes, Offset, Count, Minimum, Maximum, Value)` and
`TryParseBoolean(Bytes, Offset, Count, Value)` consume a counted span in
zero-based byte storage. `Count` is a byte count, not an endpoint. They validate
UTF-8 and the complete trimmed input, publish their output only on success,
and preserve an existing Err record on success. Invalid span/range arguments
record Err 5, malformed conversion text Err 13, and integer overflow Err 6.
These are record-only Boolean library operations; the language conversion
wrapper must turn an unsuccessful operation into the ordinary fresh FAIL.

The implementation follows the frozen conversion rules in
`lang-doc/v3-language-definition.md` section 3.3:

- Decimal forms accept a sign, fractional part, and E/e exponent. Integer
  conversion rounds exact decimal values to nearest with ties to even, then
  checks the destination range. Arbitrarily many input digits are scanned;
  no floating-point intermediary or digit-count admission limit is used.
- Hexadecimal and octal forms accept case-insensitive `&H`/`&O` prefixes and
  an optional leading sign. They denote checked signed magnitudes. Suffixes,
  interior whitespace, trailing junk, and host-localized punctuation are
  rejected.
- Boolean words are case-insensitive `True` and `False`. Numeric Boolean
  conversion tests mathematical zero without rounding a fraction or
  underflowing a small exponent. Nonfinite spellings are rejected.
- Surrounding whitespace is Unicode White_Space: U+0009–000D, U+0020,
  U+0085, U+00A0, U+1680, U+2000–200A, U+2028–2029, U+202F, U+205F,
  U+3000. U+FEFF is not whitespace.

The local VB6 compatibility observation script is
`runtime/tests/managed-text/probe-vb6-numbers.ps1`. Evidence
`75c3c8e3-5bb2-4baa-b050-6348ea3f3058` confirmed this whitespace set and
Boolean case handling. VB6 locale-dependent decimal punctuation, hexadecimal
bit reinterpretation, and floating underflow do not override UBE's explicitly
invariant, range-checked, mathematical-value rules. Microsoft's
[VBA conversion reference](https://learn.microsoft.com/en-us/office/vba/language/concepts/getting-started/type-conversion-functions)
also describes locale-aware conversions; it is compatibility context rather
than the production conversion algorithm.

Actual generation-2 UBE from rebuild `30c8f236` passed the 163-case gate at O0
and O2, including independently calculated 21–80-digit inputs, all destination
integer boundaries, minimum signed magnitude, exact half ties and sticky
digits, malformed Unicode and numeric forms, counted subspans, unchanged
failed outputs, stale Err preservation, and changed-oracle negative controls.
Evidence: `d9a14c01-fcd3-4ad6-80b4-05772dca853f`.

This qualifies the counted-byte conversion algorithms. It does not claim
managed String layout, compiler constant-conversion integration, or runtime
String conversion lowering.
