# Bounded signed integer algorithms

Status: concrete ordinary-UBE API contract for the approved compiler semantic
consumer. Native test candidates qualify the algorithm/64-bit prerequisite;
the production module and maintained library gate must pass before consumption.
This adds no intrinsic, machine representation, language literal grammar or
compiler phase API. All operations use the established signed 64-bit LongLong.

The concrete need is checked decimal decoding and constant arithmetic without
host conversions, overflow, simulated Err or allocation. The source-built
bootstrap now passes 793 assertions, including checked 64-bit machine arithmetic.
The independently tested candidate passes both stages at
`../bootstrap/out/signed-integer/012a408b55124308a703f9f888c4d8fb/report.json`:
79 reused boundary cases, 44 additional operator cases, 169 ordered comparisons,
43 decimal spans, two old-Err seeds, measured 0/1/8/64/1024/16384 digit work,
actual zero/exact/above root admission and scalar work at a fully occupied
one-million-record root registry. Those test-only names/metrics are not a
production API. UBE-driven shared-input probes and maintained qualification
remain separate obligations.

## Decimal span

`TryDecodeDecimalInteger(ByRef Bytes() As Byte, ByVal FirstByte As Long,
ByVal ByteCount As Long, ByVal Negative As Boolean, ByVal Minimum As LongLong,
ByVal Maximum As LongLong, ByRef Result As LongLong,
ByRef Failure As Long) As Boolean`

Borrow an immutable zero-based byte array for this call. FirstByte/ByteCount
select exactly one ASCII digit span. Leading zeroes are allowed. Signs,
whitespace, separators, suffixes, embedded zeros, Unicode digits and trailing
characters are not part of this generic digit format. The caller supplies the
sign separately. Empty spans are format failures; invalid bounds/span arithmetic
are domain failures. FirstByte=array length with ByteCount=0 is a valid empty
span; it does not permit reading beyond the array.

Minimum/Maximum are inclusive and may be any ordered signed-64 interval. Decode
the mathematical signed value and require that it lies in that interval.
Negative zero is zero. Negative accumulation accepts a signed minimum without
first constructing its unrepresentable positive magnitude. Check before each
multiply/subtract; do not inherit machine overflow or an unchecked conversion.
The first observed format/range failure stops processing; later bytes are not
scanned to replace it with a different error category.

Success returns True, replaces Result and sets Failure=0. Failure returns False
and preserves Result. Failure classes are:

| Value | Meaning |
| --- | --- |
| 1 | Invalid caller domain: span or ordered range |
| 2 | Empty span or a read byte that is not an ASCII digit |
| 3 | Mathematical value cannot fit the caller's range |
| 5 | Managed/root admission failed |

The caller initializes Failure=5 before entering managed code, including before
resolving a managed field as an argument. Entry can fail before the body runs.
The implementation re-seeds 5 before a fallible managed read. Domain/format/
range failures and success preserve earlier Err, including Err 7. Actual managed
admission failure retains its runtime Err 7; never infer the result from Err.
Result/Failure outputs must be distinct and may not alias the input storage.

## Scalar operations

`TryEvaluateInteger(ByVal Operation As Long, ByVal Left As LongLong,
ByVal Right As LongLong, ByVal Minimum As LongLong, ByVal Maximum As LongLong,
ByRef Result As LongLong, ByRef Failure As Long) As Boolean`

The caller chooses an inclusive range containing zero: Minimum<=0<=Maximum.
Both operands must already fit it for binary operations. Unary operations
validate Left and ignore Right. These are reusable numeric operation identities,
not compiler syntax-node or intrinsic-role IDs:

| Operation | Meaning |
| --- | --- |
| 1 | Add |
| 2 | Subtract |
| 3 | Multiply |
| 4 | Integer division |
| 5 | Remainder |
| 6 | Negate Left |
| 7 | Identity Left |
| 8 | Bitwise Not Left |
| 9 | Bitwise And |
| 10 | Bitwise Or |
| 11 | Bitwise Xor |
| 12 | Bitwise Eqv |
| 13 | Bitwise Imp |

Check representability before performing arithmetic. Division truncates toward
zero and remainder has the dividend's sign. Minimum divided by -1 fails when
the result is outside Maximum; remainder by -1 is zero, including signed minima.
Bitwise operations use signed-64 values and check the resulting caller range.
This facility never chooses Byte promotion, language operand/result types,
Boolean representation, destination context or constant-expression eligibility.
Identity can check a final integer conversion into a zero-anchored range.

Success replaces Result, sets Failure=0 and returns True. Failure preserves
Result and returns False: 1 for operation/range domain, 3 for an out-of-range
operand/result, 4 for division/remainder by zero. All outcomes preserve Err.
This scalar-only function does not require a managed root and cannot allocate.
Result/Failure outputs must be distinct. There is no global mutable evaluator.

`CompareIntegers(ByVal Left As LongLong, ByVal Right As LongLong) As Long`
returns exactly -1, 0 or 1 for less/equal/greater. It is total on signed-64 inputs,
allocates/retains nothing, requires no managed root and preserves Err.

## Ownership, work and qualification

Every mutable output belongs to the caller. Input bytes remain alive and
immutable throughout decoding; no reference is retained. Independent calls and
simultaneous reads of a shared immutable byte owner are reentrant/thread-safe.
Language/target rules and diagnostic messages remain compiler-owned. No source
payload, array, catalog, string or intermediate numeric object is copied.

Scalar operations and comparison have bounded work independent of values.
Decoding is linear in bytes actually read with constant scalar workspace and
no input-controlled recursion. Successful decoding reads every supplied digit
exactly once; failure reads at most the validated span. Native acceptance counts
actual byte accesses and checked-machine calls, allocations/copied bytes and
root peaks. Preserve the prior output at actual zero/below/exact/above root
admission, exercise old Err 7/77 and prove later recovery. Scalar work must still
succeed while the real root registry is full.

The candidate preset permits at most 16 additional decoder roots and zero for
scalar operations/comparison; zero allocator calls/payload copies; at most
8*actual-byte-reads+8 checked-machine calls per decode, eight per scalar
evaluation and one per comparison. Removing test-only metrics from the public
API does not remove this actual-observer requirement. Compare complete native
values/status/Err and independently authored byte spans through both accepted
source-built stages; preserve identical raw LLVM and reject deliberately wrong
expected values/counters. Four actual UBE workers must share a retained immutable
input owner with private results and unchanged bytes. A compiler build or a
round trip through the same candidate is insufficient qualification.
