# Adaptive String-result functions

**Status:** owner-proposed language addition, 2026-11-10; declaration syntax
and detailed context rules pending reconciliation with the normative grammar.
No compiler support is claimed.

## Owner's intended behavior

- One function implementation always returns String on success.
- Calling it with a supported type suffix explicitly selects the call's
  expression type, converting the successful String result as needed.
- Calling it without any type suffix adapts that successful String result to the type
  expected by the caller through the ordinary checked conversion rules.
- When no expected type is available, the unsuffixed call produces a Variant
  containing the String. Its text is not guessed to be numeric or a date.

Adaptive describes the call result, not a dynamically changing implementation
return type. No second algorithm, type-name dispatch or hard-coded Mid/Left
compiler implementation is needed. Failure is still FAIL, never a String or
Variant containing a failure marker.

## Proposed declaration form

Use `Adaptive` as a contextual modifier in a Function declaration, retaining
explicit parameter types and `As String` under UBE's strict declaration rules:

```vb
Public Adaptive Function Mid(ByVal Value As Variant, _
                             ByVal Position As LongLong, _
                             ByVal Length As LongLong) As String
    ' One String-producing implementation.
End Function
```

This is a proposed declaration shape, not a final Mid signature: optional
Length behavior and the library's broad-input declaration mechanism are
separate contracts. `Value` avoids the reserved word Input. Adaptive alone
does not permit arrays or custom datatypes as text input or change parameter
passing rules. The established broad-input checks still apply.

The proposed modifier is contextual rather than a new globally reserved word.
It is meaningful only for functions returning String. Inside the function,
the result variable remains String regardless of the caller's context.

## Call examples

The owner extended the proposal to all existing UBE identifier type suffixes:

| Suffix | Call result type | Adaptation from implementation result |
|---|---|---|
| `$` | String | Keep the returned String. |
| `%` | Integer | Checked conversion to signed 16-bit integer. |
| `&` | Long | Checked conversion to signed 32-bit integer. |
| `^` | LongLong | Checked conversion to signed 64-bit integer. |
| `!` | Single | Checked conversion to binary32. |
| `#` | Double | Checked conversion to binary64. |
| `@` | Currency | Checked conversion to fixed-point Currency. |

An explicit suffix takes precedence over the surrounding expected type when
determining the call expression's type. Ordinary conversion from that typed
expression to its eventual destination still applies. For example, assigning
Mid%(Text, 1, 5) to a Long still requires the extracted text to fit Integer;
the wider destination cannot erase the explicitly requested narrow conversion.
Suffixes identify the same Adaptive declaration, not separate overloads or
implementations. No new suffix is introduced for Boolean, Date, Decimal,
IntPtr, UIntPtr or Variant.

Owner-confirmed conversion order:

```vb
Dim a As Integer
a = Mid&(1234567, 1, 2)
```

The text-input conversion supplies "1234567". The shared implementation
returns String "12". The explicit & suffix converts that result to Long 12.
Only then does assignment convert Long 12 to Integer 12. The Integer
destination must not replace the explicitly requested Long result type.

Both conversions retain their own rounding, range checks and failure behavior.
If suffix conversion fails, destination conversion and assignment do not run.
If destination conversion fails, the destination remains unchanged. The same
ordering applies to narrowing and widening destinations. For example, a Long
destination cannot rescue an out-of-range Integer requested by an explicit %.

Optimization may combine or remove physical conversion instructions only when
it proves that the defined sequence has identical observable behavior,
including intermediate rounding, range failures, Err effects and evaluation
order. It must not reinterpret an explicit suffix as a hint or replace the
programmer's chosen conversion sequence merely because another seems simpler.

| Call context | Intended successful result |
|---|---|
| `Dim Text As String = Mid$("12345", 2, 3)` | String "234". |
| `Dim Count As Long = Mid("12345", 2, 3)` | String "234" converted to Long 234 at the call site. |
| `Dim Value As Variant = Mid("12345", 2, 3)` | Variant with a String payload "234", not Long 234. |
| Unsuffixed call without a known expected type | Variant containing the returned String. |

A `$` call's expression type stays String; any surrounding assignment or
parameter conversion still follows ordinary UBE rules. The suffix is not a
ban on later conversion. Conversely, an unsuffixed call needs no intermediate
Variant allocation when the compiler already knows a concrete destination.

For example, Mid&("12345", 2, 3) produces Long 234 after the shared String
implementation returns "234". An explicit suffix lets the compiler select a
concrete conversion without runtime destination-type discovery. It is not a
guaranteed speed advantage over an unsuffixed call with an equally known
expected type. Constant folding, inlining and removal of intermediate storage
are permitted only when ordinary evaluation, range checks and failure behavior
are preserved; no performance result is claimed before measurement.

Call the implementation exactly once. Adapt only after it succeeds. A failed
call or failed result conversion abandons the containing statement or enters
its enabled handler under `error-handling.md`; an unfinished assignment does
not commit. Illegal known conversions receive compile-time diagnostics under
the existing rules. Adaptive does not make ordinary library calls legal in
required constant expressions or require executing arbitrary functions during
compilation.

## Definition work remaining before grammar adoption

- Enumerate expected-type contexts: direct assignment/initializers, ByVal
  arguments, procedure results, conditions and nested operator expressions.
  Define where context stops and when Variant is used; do not infer new
  arithmetic promotion rules or overload resolution.
- Preserve exact writable-storage requirements for ByRef. Adapting a returned
  value must not fabricate an alias to caller storage.
- Specify modifier order and combinations with Inline, ForceInline, Static,
  Intrinsic and Export, and whether interface/property declarations participate.
- Reconcile suffix rules: all seven existing type suffixes and the unsuffixed
  call identify the same Adaptive declaration; only result adaptation differs.
  This is a scoped exception to ordinary declaration/suffix type agreement.
  Specify lexer disambiguation against operators such as & and ^, retaining
  ordinary infix expressions and the existing literal-suffix rules.
- Specify metadata for separately compiled callers so adaptation does not
  depend on textual name or access to an implementation body.
- Synchronize specification, EBNF, public manual and grammar-word inventory
  once these declaration/context details are settled.

Acceptance must cover one implementation, exactly-once evaluation, String
results inside the body, all expected-type contexts, Variant fallback,
conversion FAIL, invalid inputs, suffix identity and separate compilation.
