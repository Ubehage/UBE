# Independent scalar arithmetic boundary expectations

Status: **future native oracles, not executed executable results**. The source
snippets below are independent cases; place each inside its own valid native
MODULE `Function Main() As Long`, with a suitable return/observer, rather than
combining cases that overwrite `Err`. The authoritative rules are the bounded
`SEMANTIC-CONTRACT.md` types, literals, operators and assignments sections and
`lang-doc/language-spec.md` sections 4, 9 and 14. `Byte` is unsigned 8-bit,
`Integer` signed 16-bit, and `Long` signed 32-bit. Integer operations promote
Byte to Integer and perform checked arithmetic in the selected result type
before destination conversion. Runtime-dependent failures yield neutral zero
and record the current thread's `Err`; a later successful operation does not
clear it. An actual same-thread observer is required; a zero result alone is
not proof of the error. The general normative arithmetic error number has not
been fixed by this review, so no particular numeric `Err` is invented here.

For each runtime row start with a clear error state, assert the entire value and
whether `Err` stays clear or becomes nonzero, then separately repeat with a
preseeded error followed by a successful operation to test its preservation.
The observer must run on the generated operation's own thread, not replace the
operation. Known-invalid rows must instead be rejected before native tool
invocation; they must not execute, set a simulated runtime error or replace an
existing output artifact.

| Case | UBE body statements | Expected observation |
| --- | --- | --- |
| Byte upper bound | `Dim x As Byte = 255` | Successful initialization: x = 255, no new Err. |
| Byte promotion | `Dim a As Byte = 200` / `Dim b As Byte = 100` / `Dim x As Integer = a + b` | 200 + 100 = 300 in promoted Integer; x = 300, no new Err. |
| Byte unary promotion | `Dim a As Byte = 200` / `Dim x As Integer = -a` | x = -200 in promoted Integer, no new Err. |
| Byte dynamic upper failure | `Dim a As Byte = 255` / `Dim x As Byte = a + 1` | Integer intermediate 256 succeeds; conversion to Byte fails; x = 0 and Err becomes nonzero. |
| Byte dynamic lower failure | `Dim a As Byte = 0` / `Dim x As Byte = a - 1` | Integer intermediate -1 succeeds; conversion to Byte fails; x = 0 and Err becomes nonzero. |
| Byte known range | `Dim x As Byte = 256` | Compile-time ConstantRange / UBE1410; no runtime result. |
| Byte known folded expression | `Dim x As Byte = 200 + 100 - 100` | Fold promoted Integer arithmetic to 200; x = 200, no new Err. |
| Integer bounds | `Dim lo As Integer = -32768` / `Dim hi As Integer = 32767` | lo = -32768 and hi = 32767, no new Err. Unsuffixed signed minimum uses the approved signed-literal rule. |
| Integer dynamic addition | `Dim hi As Integer = 32767` / `Dim one As Integer = 1` / `Dim x As Integer = hi + one` | Selected Integer addition cannot hold 32768; x = 0 and Err becomes nonzero. |
| Integer dynamic negation | `Dim lo As Integer = -32768` / `Dim x As Integer = -lo` | Selected Integer negation cannot hold 32768; x = 0 and Err becomes nonzero. |
| Integer known operation overflow | `Dim x As Integer = 32767% + 1%` | Compile-time ConstantRange / UBE1410; explicit Integer operands cannot silently widen. |
| Long bounds | `Dim lo As Long = -2147483648` / `Dim hi As Long = 2147483647` | lo = -2147483648 and hi = 2147483647, no new Err. |
| Long dynamic addition | `Dim hi As Long = 2147483647` / `Dim one As Long = 1` / `Dim x As Long = hi + one` | Selected Long addition cannot hold 2147483648; x = 0 and Err becomes nonzero. |
| Long dynamic negation | `Dim lo As Long = -2147483648` / `Dim x As Long = -lo` | Selected Long negation cannot hold 2147483648; x = 0 and Err becomes nonzero. |
| Long known operation overflow | `Dim x As LongLong = 2147483647& + 1&` | Compile-time ConstantRange / UBE1410. The wider destination does not widen explicit Long operands. |
| Division zero, known | `Dim x As Long = 9 \ 0` | Compile-time ConstantDivisionByZero / UBE1411; no runtime result. |
| Division zero, dynamic | `Dim d As Long = 0` / `Dim x As Long = 9 \ d` | x = 0 and Err becomes nonzero. |
| Long division overflow, dynamic | `Dim lo As Long = -2147483648` / `Dim d As Long = -1` / `Dim x As Long = lo \ d` | Mathematical quotient 2147483648 does not fit Long; x = 0 and Err becomes nonzero, without a native trap or LLVM poison. |

Each `/` above separates statements; `\` is the literal UBE integer-division
operator. To distinguish the signs independently, use variables in separate
runtime cases and assert both quotient and remainder; all four successful cases
leave a clear `Err` clear:

| Dividend `a` | Divisor `b` | `a \ b` | `a Mod b` |
| --- | --- | --- | --- |
| 17 | 5 | 3 | 2 |
| 17 | -5 | -3 | 2 |
| -17 | 5 | -3 | -2 |
| -17 | -5 | 3 | -2 |

`division-signs/DivisionSigns.UBE` implements these four runtime-variable
rows. It expects process status 69; statuses 91 through 94 identify a failed
row. The additional admission script accepted this fixture at jobs 1 and 4,
but its native execution, clear-Err observation and negative controls remain
unexecuted. The result does not by itself prove the error state stayed clear.

The hand arithmetic was independently checked with JavaScript integer arithmetic
and quotient truncation (`Math.trunc(a / b)`, remainder `a - quotient * b`);
all magnitudes used in that check are below 2^53 and therefore exact. The
following isolated diagnostic-only files were additionally checked with the
current local compiler SHA-256
`80955A6E4CF5F4249C70C8EA130C4D0CD97AA07FB7EE847F24838F507A6CD241`:

```powershell
rtk proxy bootstrap/out/v3/ube.exe --check bootstrap/out/arithmetic-oracle-review/byte-runtime.bas
rtk proxy bootstrap/out/v3/ube.exe --check bootstrap/out/arithmetic-oracle-review/byte-known.bas
rtk proxy bootstrap/out/v3/ube.exe --check bootstrap/out/arithmetic-oracle-review/int-runtime.bas
rtk proxy bootstrap/out/v3/ube.exe --check bootstrap/out/arithmetic-oracle-review/int-known.bas
rtk proxy bootstrap/out/v3/ube.exe --check bootstrap/out/arithmetic-oracle-review/long-min-runtime.bas
rtk proxy bootstrap/out/v3/ube.exe --check bootstrap/out/arithmetic-oracle-review/divide-known.bas
```

The three `*-runtime` samples exited 0 without output; `byte-known` and
`int-known` exited 1 with UBE1410, and `divide-known` exited 1 with UBE1411.
The files under `bootstrap/out` are diagnostic scratch, not maintained source
fixtures or a fresh native build. These six checks establish only local checker
admission/rejection, not target arithmetic, correct runtime `Err`, source-built
stage equivalence, absence of LLVM undefined behavior or preservation of an old
artifact. The unprobed rows remain independent expectations to be turned into
maintained fixtures and tested through both selected compiler stages.
