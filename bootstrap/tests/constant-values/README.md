# Exact typed constant acceptance

Run from the repository root with an already built bootstrap:

```powershell
rtk proxy powershell -NoProfile -File bootstrap/tests/constant-values/check.ps1 -BootstrapExe <UBE-Bootstrap.exe>
```

The gate compiles the checked-in `compiler/src/ConstantValues.bas` and its
lexical dependencies. It calls the emitted procedures with runtime-fed values
and retained source tokens. Ninety-seven independently authored vectors check
decimal signed minima/maxima, contextual widening and authoritative `%`, `&`,
`^` suffixes, unsupported radix/floating spellings, typed overflow before any
destination conversion, unary signs/Not, And/Or, comparisons, and conversions
between Boolean, Byte, Integer, Long and LongLong. Each vector checks fresh
success, Boolean status, exact value/type/reason, and preservation of Err 77.
Rejected inputs must preserve both output value and type. Malformed token
spans/kinds are rejected without changing Err. Source arrays must be zero-based:
positive and negative nonzero lower bounds produce controlled FAIL with Err 9,
preserve outputs, and never reinterpret a different byte as the token start.

The successful cohort returns zero at O0 and O2. A volatile input changes the
first literal from `0` to `1`; both builds must then return exactly 1, proving
the expected-value assertions detect a runtime mismatch. Child processes have
deadlines, and native images must have the Windows x64 PE machine value.

Only the test assertion driver's `main` uses `optnone`; opaque test API
wrappers use `noinline`. This prevents the ninety-seven assertions themselves
from producing an oversized optimized stack frame requiring the unavailable
CRT stack probe. The production compiler procedures remain unchanged and are
optimized at the selected level. This gate does not prove expression-tree
binding, runtime language arithmetic, or the complete compiler pipeline.
Separate O0/O2 assembly checks compile the unchanged production-only IR and
assert that it contains no `__chkstk` dependency.

The constant API uses `SyntaxTokens` type/operator codes and exact LongLong
payloads. `TryLiteral`, `TryUnary`, `TryBinary` and `TryConvert` publish outputs
only on True. Reason 1 means unsupported spelling/domain/operator, 2 means
range/overflow, and 3 means invalid scalar representation or input span/type.
Ordinary rejection preserves Err; unexpected helper FAIL propagates to the
calling semantic pass. Literal negation is supplied separately so a directly
negated signed minimum needs no invalid positive intermediate.
