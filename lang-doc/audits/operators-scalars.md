# UBE 1.0 operators and scalar types audit

**Status:** reviewed and promoted to the normative specification  
**Compatibility basis:** classic Visual Basic behavior where it does not
conflict with UBE's checked arithmetic, explicit declarations, invariant
conversion rules, or target-independent results

This audit covers every operator in `grammar/ube.ebnf` and the scalar details
which must be fixed before those operators can be implemented consistently.
It does not add implicit object-to-scalar conversion or late-bound operators.

## 1. General operator rules

1. Operands are evaluated exactly once, from left to right. An operator does
   not change the evaluation order described for calls and arguments.
2. The compiler determines an expression's static result type from the rules
   below. The type of the assignment destination does not influence operator
   selection.
3. A compile-time-known invalid operation or checked overflow is a compile-time
   error. The same runtime-dependent failure returns the operator result
   type's neutral value and records `Err` in the current thread.
4. Integer, pointer-sized integer, `Currency`, and `Decimal` operations never
   wrap or saturate. Implementations must not inherit LLVM or host-language
   undefined behavior.
5. `Single` and `Double` use IEEE-754 round-to-nearest, ties-to-even and retain
   the already approved infinity and NaN behavior.
6. An enum operand is its declared `Long` or `LongLong` underlying type for
   operator selection. The result of an arithmetic or bitwise operation is the
   underlying integer type, not the enum type. Equality and ordering may
   compare different enum types through their underlying types.
7. `Any`, arrays, custom datatypes, and references have no operators except the
   explicitly listed equality or identity operations. No operator is selected
   merely from equal storage layouts.
8. Parentheses do not change a value's type. They only group an expression
   (apart from the separately documented VB `ByRef` compatibility behavior at
   a call site).

## 2. Numeric common type

The arithmetic operators `+`, `-`, and `*`, numeric comparisons, and eager
integral logical operators use the following common-type rules. They are
applied after enum erasure and before evaluation.

### 2.1 Fixed integral types

For `Byte`, `Integer`, `Long`, and `LongLong`, the result is the first type in
this list able to represent the complete ranges of both operands:

```text
Integer, Long, LongLong
```

Consequently, `Byte op Byte` produces `Integer`; mixing `Byte` with a signed
type produces that signed type; and two operands of the same signed type retain
that type. This follows Basic's promotion of byte arithmetic while preserving
the familiar result types of signed integer expressions. If no listed type can
represent both complete ranges, the next rule applies.

### 2.2 Pointer-sized integers

- Two `IntPtr` operands produce `IntPtr`; two `UIntPtr` operands produce
  `UIntPtr`.
- `IntPtr` mixed with `Byte`, `Integer`, or `Long` produces `IntPtr` only when
  the fixed operand's complete range is representable by `IntPtr` on every
  supported target selected for that build. Otherwise it produces `Decimal`.
- `UIntPtr` mixed with `Byte` produces `UIntPtr`. `UIntPtr` mixed with a signed
  integer, or either pointer-sized type mixed with `LongLong`, produces
  `Decimal` so that neither negative values nor the unsigned 64-bit range are
  silently lost.
- A pointer-sized type mixed with `Currency` or `Decimal` follows the decimal
  rules below; mixed with a floating type it follows the floating rules.

This makes source behavior portable across 32-bit and 64-bit targets. A
compiler may fold a representable constant but must not select a different
expression type merely because one particular constant is small.

### 2.3 Fixed point, decimal, and floating point

Apply the first matching rule:

| Operands | Common/result type |
|---|---|
| either is `Double` | `Double` |
| `Single` with `Decimal`, `Currency`, `LongLong`, `IntPtr`, or `UIntPtr` | `Double` |
| otherwise either is `Single` | `Single` |
| otherwise either is `Decimal` | `Decimal` |
| otherwise either is `Currency` | `Currency` |
| otherwise | fixed-integral rules above |

Conversion to the common type is checked. In particular, an integer too large
to be represented exactly by `Single` or `Double` may still be converted, using
IEEE rounding; that is a successful floating conversion rather than integer
overflow. Decimal and `Currency` scale reduction uses ties-to-even.

### 2.4 Literal types

An unsuffixed decimal, hexadecimal, or octal integer literal has the first of
`Integer`, `Long`, or `LongLong` which represents its mathematical value.
There is no implicit reinterpretation of a hexadecimal or octal digit sequence
as a negative two's-complement bit pattern. The leading sign participates in
range checking, so `-32768` is a valid `Integer` literal. A value outside
`LongLong` is a compile-time error.

The classic suffixes select an exact type: `%` is `Integer`, `&` is `Long`, and
`^` is `LongLong`. An out-of-range suffixed literal is a compile-time error;
the suffix never requests wrapping. Unsuffixed real literals are `Double`.
Real suffixes select `!`/`F` = `Single`, `#`/`R` = `Double`, `@` = `Currency`,
and `D` = `Decimal`. Literal conversion and rounding use the same rules as a
constant conversion to that exact type.

The grammar currently also admits integer suffixes `S`, `I`, `L`, `US`, `UI`,
and `UL`, inherited from VB.NET syntax. UBE has no `UShort`, `UInteger`, or
`ULong` core types, so those spellings cannot all receive their VB.NET meaning.
The closure recommendation is to remove all six from UBE 1.0 rather than give
familiar suffixes surprising meanings. This requires an EBNF edit.

## 3. Arithmetic operators

| Operator | Accepted operands | Result and behavior |
|---|---|---|
| unary `+` | numeric | Same type and value after enum erasure. `Byte` promotes to `Integer`. |
| unary `-` | numeric except `UIntPtr` | Same type after enum erasure; `Byte` promotes to `Integer`. Negating the minimum signed value is checked overflow. |
| `+`, `-`, `*` | numeric | Common numeric type from section 2; checked except for IEEE floating results. |
| `/` | numeric | See division rule below. |
| `\` | numeric | See integer-division rule below. |
| `Mod` | numeric | See modulus rule below. |
| `^` | numeric | Both operands convert to `Double`; result is `Double` and uses the platform-independent UBE math implementation. |
| `&` | string-convertible scalar | Concatenation, described in section 5. |

`UIntPtr` unary minus is a compile-time type error rather than an implicit
conversion whose result depends on target width.

Ordinary `/` preserves exact decimal arithmetic when possible:

- if neither operand is floating and either is `Decimal`, the result is
  `Decimal`;
- if neither is floating and either is `Currency`, both convert to `Decimal`
  and the result is `Decimal` (division is not restricted to four fractional
  digits);
- otherwise both operands convert to `Double` and the result is `Double`.

Decimal division rounds once to the representable `Decimal` result using
ties-to-even. Decimal division by zero produces decimal zero plus `Err`.
Floating division follows the approved IEEE rules.

For `\` and `Mod`, each operand is first rounded to the nearest integral value,
ties-to-even, as in classic VB integer division. Floating special values and a
rounded value outside `LongLong` fail. The converted operands and result are:

- the ordinary fixed-integral common type when both original operands are
  fixed integral;
- `IntPtr` or `UIntPtr` when both operands have that same pointer-sized type;
- `LongLong` for all other numeric combinations.

Integer division truncates the quotient toward zero. `Mod` is defined by
`a Mod b = a - (a \ b) * b`; therefore its nonzero result has the sign of
`a`. A zero divisor and the signed-minimum divided by `-1` follow the checked
failure rule.

Exponentiation is right-associative by the grammar. Negative bases with a
nonintegral exponent, zero to a negative exponent, overflow, and other domain
results follow IEEE `Double` semantics (`NaN` or infinity) without setting
`Err`. UBE must specify one reproducible math implementation/test tolerance;
it may not expose arbitrary host `pow` differences as exact language results.

## 4. Boolean and bitwise operators

`Boolean` is a logical type, not an integer storage promise. Its conversion to
numeric remains the approved VB-compatible mapping `False = 0`, `True = -1`.

| Operator | Boolean operands | Integral operands |
|---|---|---|
| `Not` | logical negation; result `Boolean` | bitwise complement; result is the operand type after `Byte` promotes to `Integer` and enum erasure |
| `And` | eager logical conjunction; result `Boolean` | eager bitwise AND in the fixed-integral common type |
| `Or` | eager logical disjunction; result `Boolean` | eager bitwise OR in the fixed-integral common type |
| `Xor` | eager logical exclusive-or; result `Boolean` | eager bitwise XOR in the fixed-integral common type |
| `Eqv` | eager logical equivalence; result `Boolean` | bitwise `Not (left Xor right)` in the common type |
| `Imp` | eager logical implication; result `Boolean` | bitwise `(Not left) Or right` in the common type |

For bitwise operations, the integral family is `Byte`, `Integer`, `Long`,
`LongLong`, `IntPtr`, `UIntPtr`, and enum underlying types. Mixing `Boolean`
with an integral operand is permitted for VB compatibility: Boolean converts
to the other operand's type (`False = 0`, `True = -1`) and the result is that
integral type. Conversion of `True` to `Byte` or `UIntPtr` is invalid, so an
expression which would require it fails under the ordinary checked rule.
`Currency`, `Decimal`, `Single`, and `Double` are not bitwise operands.

`AndAlso` and `OrElse` accept only statically `Boolean` operands (or a
`Variant` whose runtime payload converts to Boolean) and always produce
`Boolean`. They evaluate the left operand first and skip the right operand
when it cannot affect the result. A skipped expression has no calls,
allocations, errors, events, or other effects.

## 5. Strings and `Like`

`&` is the only concatenation operator. `+` is numeric only; it never guesses
between addition and concatenation by parsing runtime strings. Each `&`
operand must be `String`, fixed-length `String`, numeric, `Boolean`, `Date`,
`Empty`, or a `Variant` containing one of those. Non-string scalars use the
approved invariant canonical conversion. Fixed-length padding is retained.
The result is a variable-length `String` unless `Null` propagation makes it a
`Variant/Null`.

String `=`, `<>`, `<`, `<=`, `>`, and `>=` are lexicographic and return
`Boolean`. `Option Compare Binary` compares Unicode scalar values;
`Option Compare Text` applies the versioned locale-independent case folding.
No normalization is implicit. Fixed-length padding spaces participate.

`Like` accepts two strings and returns `Boolean`. Its pattern language is the
classic VB language:

- `?` matches one Unicode scalar value;
- `*` matches zero or more scalar values;
- `#` matches one ASCII digit `0` through `9`;
- `[chars]` matches one listed scalar value;
- `[!chars]` matches one scalar value not listed;
- `x-y` inside a group specifies an inclusive scalar-value range; and
- `[`, `]`, `?`, `*`, and `#` are literal when represented through a bracket
  group in the classic manner.

Pattern matching uses the containing module's `Option Compare` mode. A
reversed range, unclosed group, or empty group is invalid. A known-invalid
constant pattern is a compile-time error; a runtime-invalid pattern returns
`False` plus `Err`. Matching is deterministic over Unicode scalar values, not
UTF-8/UTF-16 code units or locale collation elements.

## 6. Comparison and identity

- Numeric equality and ordering convert both operands to the numeric common
  type and return `Boolean`. IEEE comparisons apply when that type is floating:
  every ordered comparison with NaN is false, `NaN = NaN` is false, and
  `NaN <> NaN` is true.
- Boolean values support `=` and `<>`; ordering Boolean values is rejected.
- Strings support all six value comparisons and `Like` as above.
- Dates support all six value comparisons, ordered by their complete
  timezone-neutral value.
- Two values of the same custom datatype support `=` and `<>` only if every
  field is itself equality-comparable. Comparison is recursive semantic field
  equality; padding bytes and object addresses are never compared. Ordering a
  custom datatype is invalid.
- Arrays do not have value-comparison operators in UBE 1.0.
- `Is`, `IsNot`, and `Is Not` require object-compatible references (including
  a compatible reference against `Nothing`) and compare identity. They return
  `Boolean` and never call a default property or user member. `=` does not
  compare reference identity.

Comparing unlike nonnumeric scalar families is a compile-time error; operators
do not use assignment conversions to turn numbers or dates into strings.

## 7. `Variant`, `Null`, and `Empty`

An operation with one or more `Variant` operands is dynamically dispatched
using the same table that would apply to the payload types. If the operation
succeeds, its value is stored in a `Variant` retaining the exact result type.
This rule does not enable an operation forbidden for the payload type.

`Null` propagates as `Variant/Null` through unary `+`, unary `-`, `Not`, all
arithmetic and bitwise operators, `&`, `Like`, and value comparisons. Neither
operand is converted further after dispatch detects `Null`. Eager binary
operators still evaluate both operand expressions, left to right, before that
dispatch; `Null` does not suppress the right operand's effects.
`Is`/`IsNot` with `Null` are invalid because `Null` is not a reference.

`AndAlso` and `OrElse` are the deliberate exception: they require Boolean
conversion to decide control flow. Converting `Variant/Null` to Boolean fails,
produces `False`, and records `Err`; ordinary short-circuit behavior then uses
that false value. Thus `Null AndAlso X` skips `X`, while `Null OrElse X`
evaluates `X`.

`Empty` does not propagate. For operator dispatch it supplies the applicable
neutral value: numeric zero, `False`, or the empty string. Context determines
the family from the other operand. Where both operands are `Empty`, arithmetic
uses `Long`, `&` uses `String`, logical operations use `Boolean`, and value
comparison compares two `Long` zeroes. Unary `Empty` uses `Long` zero.

A `Variant` object payload remains a reference. It supports only statically
valid `Set`, member access through an explicitly supported contract, and
identity comparison; boxing never creates scalar operator conversion.

## 8. `Decimal` contract

The phrase “128-bit Decimal” requires an exact portable value contract. The
VB-compatible recommendation is:

- a sign, a 96-bit unsigned coefficient, and decimal scale `0` through `28`;
- value `(-1)^sign * coefficient / 10^scale`;
- maximum magnitude `79228162514264337593543950335`;
- positive and negative zero compare equal and canonical conversion writes
  `0`;
- trailing coefficient zeroes are not semantically significant;
- operation results preserve all exact significant digits which fit, then
  reduce scale using round-to-nearest, ties-to-even;
- if no scale from 28 down to 0 yields an in-range rounded result, the
  operation overflows; and
- no NaN, infinity, signed-zero distinction, exponent payload, or
  implementation-specific encoding is observable.

This is a 128-bit storage type with VB/.NET-compatible 96-bit coefficient
semantics, rather than IEEE decimal128. ABI representation remains a foreign
interface concern and must not be inferred from the value contract.

## 9. `Date` contract

`Date` is a timezone-neutral proleptic-Gregorian value with:

- year `0001` through `9999`;
- month, day, hour `00..23`, minute and second `00..59`; and
- a nanosecond fraction `0..999999999`.

Every value therefore has one-nanosecond language resolution even if a host
clock or file system is coarser. Leap seconds, timezone offsets, daylight
saving rules, and locale are not part of the core value. Equality and ordering
compare the complete fields chronologically. Storage layout is private and may
differ by target, but all conforming implementations preserve the value and
canonical string form exactly.

Core `Date` supports comparison only. It does not support `+`, `-`, numeric
conversion, or Boolean conversion. Date intervals, calendar arithmetic,
elapsed-time arithmetic, host timezones, and VB serial dates are explicit
standard-library facilities. This follows the already approved separation
from numeric serial dates rather than VB6's implicit date arithmetic.

## 10. `IntPtr` and `UIntPtr` contract

`IntPtr` and `UIntPtr` contain exactly the signed or unsigned integer range of
the compilation target's data-pointer width. They are scalar numbers, not
references and not dereferenceable addresses. Their width is a compile-time
target property and is never selected from the host running the compiler.

They support checked integral arithmetic, integer division, modulus, bitwise
operators, equality, ordering, and invariant numeric conversion under the
rules above. No operation implicitly dereferences them, grants memory access,
or turns them into managed identity. Conversion to or from a foreign address
is available only through the explicit ABI facilities. `UIntPtr` subtraction
which would be negative is checked underflow.

## 11. Constant expressions

Constant folding uses these exact type and failure rules; it may not use the
compiler host's default integer width, floating parser, locale, date type, or
overflow behavior. An operation that would record `Err` at runtime is a
compile-time error in a required constant expression. IEEE NaN and infinity
remain valid floating constants when produced by an otherwise valid folded
operation.

## 12. Genuine closure choices

Most rules above are direct VB defaults or consequences of already approved
UBE rules. Three details are true language/architecture choices and should be
confirmed before promotion:

1. **Integer literal suffixes.** Remove the unsupported VB.NET suffixes `S`,
   `I`, `L`, `US`, `UI`, and `UL` from the EBNF, or add the corresponding
   scalar types. The recommendation is removal: UBE already has `%`, `&`, and
   `^` for its three signed fixed widths and has no unsigned fixed-width types.
2. **Decimal format.** Adopt the proposed VB/.NET-compatible 96-bit
   coefficient and scale 0..28, or redefine the existing “128-bit Decimal” as
   IEEE decimal128 (34 digits and a much larger exponent range). These are not
   interchangeable at ABI or arithmetic boundaries. The recommendation is the
   VB-compatible contract above.
3. **Mixed pointer arithmetic.** The proposal promotes range-incompatible
   `IntPtr`/`UIntPtr` mixtures to `Decimal` to keep results independent of
   target width. The stricter alternative is to reject those mixed operators
   and require an explicit conversion. Rejecting them is simpler for systems
   code; decimal promotion is more consistent with the approved broad numeric
   conversion matrix.
4. **Custom datatype equality.** The proposal permits recursive semantic `=`
   and `<>` when every field is comparable. Classic VB did not provide this as
   a general UDT operator. Rejecting all custom-datatype comparison would be
   simpler, but field equality is natural for UBE value types and avoids raw
   padding comparison.

The `Date` departure from VB serial-number arithmetic is not reopened here:
it follows the already approved prohibition on implicit numeric/date
conversion. Likewise, making `+` numeric-only follows UBE's static typing and
leaves unambiguous string concatenation to `&`.
