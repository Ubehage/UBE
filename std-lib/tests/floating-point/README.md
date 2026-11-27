# Exact floating-point tests

Run `check.ps1 -CompilerExe <UBE.exe>` to compile and execute the ordinary UBE
parser at O0 and O2. The test oracle uses independent arbitrary-precision
rational division and ties-to-even rounding; production uses no host numeric
parsing, formatting, or floating-point arithmetic.

`BinaryFloat.TryParse(Bytes, Start, Count, BitWidth, Bits)` accepts a counted
UTF-8 span and BitWidth 32 or 64. It returns the IEEE encoding in LongLong;
binary32 uses only the low 32 bits. Numeric signs, decimal points, E/e exponents,
and surrounding Unicode White_Space follow InvariantNumbers. Named nonfinite
values including `NaN`, `Infinity`, and `-Infinity` are rejected with Err 13.
Numeric suffixes and hexadecimal/octal forms are not accepted. A source-literal
caller must remove its already validated type suffix.

Output is published only on success. Success preserves an earlier Err record.
Invalid span/width arguments record Err 5, malformed input Err 13, and finite
values outside the finite mathematical range Err 6, even when rounding could
produce the largest finite value. Underflow rounds to a subnormal or signed zero.
These Boolean operations record errors; language wrappers must propagate FAIL.

The scanner validates all input bytes, including enormous exponents and suffixes.
The algorithm compares arbitrarily long decimal input with exact dyadic
boundaries. Its 1100-byte scratch bounds the decimal expansion of a binary64
midpoint, not the input length. Binary search locates adjacent representable
encodings; one exact midpoint comparison implements nearest/even rounding.

The gate covers 97 numeric/malformed fixtures plus counted subspans, malformed
UTF-8, invalid ranges/width, subnormal ties, maximum finite values, rounding
overflow, signed zero, rejected nonfinite names, 1500 fractional digits, saturated
exponents, and deterministic random 40-digit inputs. It asserts unchanged
outputs on failure and stale Err preservation, and rejects a deliberately
changed expected observation at both optimization levels.

This gate qualifies byte parsing only. It does not qualify managed String
wrappers, compiler literal/constant integration, arithmetic or formatting.

## Constant arithmetic

Run `arithmetic.ps1 -CompilerExe <UBE.exe>` for the separate BinaryFloatMath
gate. Its oracle decodes inputs into arbitrary-precision rational values,
performs exact arithmetic, then independently rounds to the target encoding.
It checks 608 operations and 152 comparisons at O0/O2, plus invalid API calls
and changed-oracle negative controls. Cases include both signs of zero,
rejected nonfinite inputs, cancellation, subnormals, half-ULP ties, overflow,
widely separated operands, and deterministic random encodings. Successful
finite results preserve an earlier Err. Division by zero fails with Err 11;
nonfinite inputs and rounded overflow fail with Err 6, preserving output.

`TryBinary(LeftBits, RightBits, BitWidth, Operation, Result)` expects operands
already converted to their common width. Operations 1, 2, 3, and 4 select
addition, subtraction, multiplication, and division. `TryCompare` returns
Order -1/0/1 and a false Unordered flag; nonfinite input is rejected with Err 6.
Invalid arguments leave outputs unchanged and record Err 5.

Addition/subtraction use an exact bit vector covering the binary64 exponent
span; multiplication accumulates an exact 106-bit product. Division generates
60 quotient bits and retains whether the exact remainder is nonzero. A shared
BinaryFloatValues arithmetic packer performs the sole rounding and rejects
nonfinite rounded results. The implementation has no host floating
point or mutable global state. Exponentiation is outside this gate.

## Shortest round-trip formatting

Run `formatting.ps1 -CompilerExe <UBE.exe>` for BinaryFloatText. An independent
BigInteger rational oracle derives each value's exact rounding interval from
its adjacent IEEE encodings. For increasing decimal precision it calculates
the full admissible integer coefficient range; the first nonempty range
proves coefficient minimality. It chooses the nearest admissible coefficient,
ties to even, and compares the complete expected byte spelling. The largest
finite value's upper interval is clipped to its exact value because parsing
uses checked conversion.

Canonical output minimizes significant decimal digits, then chooses the
shorter fixed or normalized scientific spelling, preferring fixed on a tie.
Fixed fractions retain a leading zero. Scientific output uses uppercase E
without an unnecessary positive sign or exponent zeroes. This convention
does not minimize character count across every legal spelling: for example,
unnormalized `123E3` and leading-point `.5` are not canonical candidates.
Negative zero is `-0`; nonfinite bit patterns fail with Err 6.

The 86-case gate covers both widths, normal/subnormal and binade boundaries,
maximum finite, signed zero, rejected infinities/NaN payloads, ordinary decimals
and deterministic random encodings. Finite outputs also pass the
independently qualified parser round trip. Tests assert exact append offsets,
stale Err preservation, unchanged destination and Used on invalid input or
insufficient space, and rejection of nonzero-lower-bound byte storage.
Negative Used records Err 5; invalid capacity/storage records Err 9, matching
ByteText's existing counted-buffer conventions.

The gate runs at O0/O2, includes a changed expected text negative control, and
separately times exact text assertions with parser calls removed. Production
formatting expands its two exact rounding boundaries once and compares decimal
candidates directly, avoiding a complete binary-search parse for each candidate.

## Binary64 exponentiation

`power.ps1 -CompilerExe <UBE.exe>` runs the independently generated
`power-oracle.ps1` fixtures against BinaryFloatPower. The oracle compares
exact rational powers of candidate values and rounding midpoints with exact
rational powers of the base; it uses no logarithm or exponential algorithm.
Its 143 algebraic cases cover positive bases from minimum subnormal through
maximum finite, near-one values, signed integral exponents and fractional
exponents with denominators 2, 4, 8 and 16. A separate directed-squaring oracle
provides 24 near-one cases with exponents +/-2^52, +/-2^53 and +/-2^63; each
reference is certified again at doubled precision. Thirteen additional cases assert
zero, negative-base domains, nonfinite rejection and very large exponents.
The gate also checks the Evaluate wrapper's FAIL propagation and destination
preservation, stale Err, O0/O2 and changed-oracle negative controls.

`TryPower(BaseBits, PowerBits, Bits)` returns correctly rounded finite binary64
bits or records failure without changing Bits. Both input encodings must be
finite. Zero to zero is one; zero to a negative exponent and a negative base
with fractional exponent fail with Err 5. Nonfinite inputs and overflow fail
with Err 6. Underflow may produce a signed subnormal or zero. `Evaluate` is
the ordinary library wrapper which raises FAIL when TryPower returns False.

The production evaluator uses base-256 integer limbs and directed fixed-point
bounds with P fractional bits, initially 64. It normalizes a positive base as
`m * 2^k`, where `1 <= m < 2`, and evaluates logarithms through the positive
atanh series with argument `(m-1)/(m+1) <= 1/3`; the same formula gives ln(2).
Taking `N = ceil(P/3)` terms leaves a positive tail less than `9^-N`, hence
less than or equal to `2^-P`. Each lower operation truncates downward and each
upper operation rounds upward; one final upper unit covers the omitted tail.

After multiplying by the exact dyadic exponent, reduction uses an integer n
and encloses `r = abs(y*ln(x)) - n*ln(2)` in `[0,1]`. If the interval is too
wide to establish this range, precision increases. For `exp(r)`, N=P/2 terms
after one leave tail below `3/(N+1)! < 2^-P` for even P>=16. A directed
reciprocal handles a negative logarithmic product. The final power-of-two
scale is exact. An answer is accepted only if both interval endpoints round
to identical binary64 bits. Otherwise precision doubles; allocation failure
or checked precision-index exhaustion reports a resource failure, never a
fabricated rounded answer.

Exact dyadic results receive a separate fast path. Reducing the exponent's
dyadic denominator and checking repeated perfect square roots determines
whether a fractional power can be rational. Any exact binary rounding
midpoint has an odd significand no wider than 54 bits. Such small odd powers,
and powers of two, are computed exactly before interval evaluation. Remaining
results cannot coincide with a binary midpoint, so converging intervals can
eventually decide rounding. This prevents precision retries from continuing
indefinitely on an exact tie.

The gate additionally builds a temporary instrumented copy starting at 56
fractional bits, asserts that refinement occurred, and checks the same exact
fixtures. This instrumentation exists only in the temporary test artifact;
production has no counters or mutable global state. A separate temporary
wrapper rejects the first real workspace-allocation call deterministically.
At O0/O2 it asserts fresh FAIL, Err 7, unchanged destinations, and a successful
retry with the exact result and sticky Err. It does not depend on machine RAM
or the removed fixed heap quota.
The algebraic oracle
scope is explicit: these tests are not an exhaustive enumeration of all
binary64 operand pairs.
