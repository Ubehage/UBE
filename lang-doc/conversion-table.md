# UBE 1.0 conversion table

**Status:** normative UBE 1.0 contract
**Applies to:** implicit assignment, argument, return, and constant conversion

This table closes the conversion relationships approved in
`v3-language-definition.md`. “Checked” means a known-invalid constant is a
compile-time error, while a runtime-dependent failure records the current
thread's Err and returns FAIL. The containing statement is abandoned under the
default mode, or control transfers to its enabled handler. An unfinished
assignment does not overwrite its destination. See
[`error-handling.md`](error-handling.md), adopted on 2026-11-10.

Unsuffixed decimal integer literals first use the owner-confirmed destination
context/default Long-or-LongLong typing rule in `language-spec.md` section 4.
That includes destination context within arithmetic expressions. The conversion
matrix applies after literal/operator typing; it must not introduce a narrower
intermediate literal type that defeats that rule. Explicit suffixes still win.
If a literal exceeds a narrower destination context, use a wider integer type
that holds it; convert the calculated result to the destination afterward.
An ordinary scalar declaration initializer uses exactly the same assignment
conversion/error rules as a separate assignment after the declaration.
Literal-only integer arithmetic is reduced to a typed constant during
compilation before its destination conversion. A known-invalid final conversion
is rejected even in an ordinary variable initializer or assignment; it is not
deferred to runtime merely because the destination is a variable.

## Scalar matrix

| Source | Destination | Rule |
|---|---|---|
| Any numeric type | Any numeric type | Implicit, checked range, approved ties-to-even rounding. |
| Boolean | Any numeric type | `False` is 0; `True` is -1; checked for unsigned destinations. |
| Any numeric type | Boolean | Zero is `False`; nonzero is `True`; `NaN`/infinity fail. |
| Numeric or Boolean | String | Invariant canonical text. |
| String | Numeric or Boolean | Complete invariant parse; surrounding whitespace allowed. |
| Date | String | `YYYY-MM-DDTHH:MM:SS[.fraction]`. |
| String | Date | Complete invariant date/time parse. |
| Date | Numeric or Boolean | No implicit conversion. |
| Numeric or Boolean | Date | No implicit conversion. |
| Object/class/interface/form/control | String/numeric/Boolean/Date | No general implicit conversion. |
| Nothing | Compatible reference | `Set` assignment of the neutral reference. |
| Compatible reference | Object/interface/base contract | `Set` assignment retaining the same identity. |
| Incompatible reference types | Any reference destination | Compile-time error when known; checked `Variant` extraction otherwise. |

The numeric family is `Byte`, `Integer`, `Long`, `LongLong`, `IntPtr`,
`UIntPtr`, `Single`, `Double`, `Currency`, and `Decimal`. Pointer-sized integer
types are numbers, not dereferenceable addresses. Foreign pointer conversion
requires an explicit ABI facility.

## Floating special values

`NaN`, `Infinity`, and `-Infinity` survive `Single`/`Double` conversion and
convert to their invariant strings. String parsing accepts those spellings
case-insensitively. They fail conversion to integral, pointer-sized,
`Currency`, `Decimal`, `Date`, or `Boolean` destinations.

## Enums

An enum behaves as its `Long` or `LongLong` underlying type. It participates in
the numeric matrix, including checked assignment from arbitrary numeric values
and other enums. String conversion is numeric; it does not substitute a member
name.

## Fixed-length strings

Conversion into `String * n` truncates after `n` characters or right-pads with
spaces to exactly `n`. This requested resizing is successful and never records
`Err`. Conversion to a variable-length String retains all stored characters.

## Variant

Assignment into `Variant` preserves the exact source tag and payload. Whole
`Variant` assignment copies both. Extraction applies this table to the runtime
tag. A custom value requires the same declared type; an array requires the same
element type and rank; a reference requires a compatible destination and
`Set`.

`Empty` converts successfully to the requested neutral scalar/string/reference
value. `Null` remains `Null` only in `Variant`; fixed-type extraction fails.
An object payload never gains scalar conversion merely by being boxed.

## Arrays and custom datatypes

Arrays implicitly assign only to the same element type and rank and receive an
independent value copy with the source bounds. Custom datatypes implicitly
assign only to the same declared type and receive the approved semantic value
copy. No structural conversion occurs merely because layouts match.

## Any

`Any` is legal only in a foreign declaration parameter. It is not a variable,
field, result, array element, overload candidate, or implicit-conversion
destination. ABI lowering validates the actual argument against the foreign
declaration contract.

## Failure and conformance requirements

- Conversion never wraps, saturates, partially parses, or depends on locale
  unless an explicit library API says so.
- Successful conversion does not clear an earlier `Err`.
- Every permitted cell requires constant, runtime-success, runtime-failure,
  minimum, maximum, and one-past-boundary tests where meaningful.
- Every forbidden cell requires compile-time rejection, except a dynamically
  tagged `Variant` mismatch, which follows checked runtime failure.
