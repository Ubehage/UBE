# Native aggregate ABI oracle: review draft

This defines future checks, not executed results and not a foreign export ABI.
The authority is `lang-doc/language-spec.md` section 4.1 and the adopted
`std-lib/NATIVE-TYPE-PROPOSAL.md`. The historical bootstrap evidence in
`std-lib/tests/native-type/NATIVE-EVIDENCE.md` measured these representations
for that proof; it does not qualify fresh v3 output.

| Native representation | Required one-component LLVM value | Target size / alignment | Independent test values |
| --- | --- | --- | --- |
| Byte | `{ i8 }` | 1 / 1 | 0, 1, 127, 128, 255 |
| Integer | `{ i16 }` | 2 / 2 | -32768, -12345, 0, 12345, 32767 |
| Long | `{ i32 }` | 4 / 4 | -2147483648, -123456789, 0, 123456789, 2147483647 |

For each row and each supported source-built compiler stage, compile the
ordinary UBE pack, copy, exact-type equality, ByVal parameter/result and ByRef
mutation cases. Use the documented accepted signed-minimum expressions instead
of deferred suffixed-minimum syntax. Inspect the emitted LLVM with an independent
LLVM-aware checker against the table: verify the relevant literal or identified
aggregate has exactly one
component of the stated integer width, actual target data layout gives the
listed size and alignment, and the producer and consumer signatures implement
the adopted aggregate rule. The checker must identify declarations through a
manifest generated for the test or other reviewed stable association; it may
not assume production symbol spelling or merely search for an unrelated type.
Run LLVM's verifier on the same module and record its identity and invocation.

At execution, use distinct values on both sides of each boundary. ByVal mutate
the callee's local copy and verify the caller retains the original; return the
second value and verify its payload; ByRef replace the original and verify the
caller sees the replacement. Same-type equality and inequality must distinguish
the original and replacement. For the existing `native-widths` program the
independent result is 47, with 99 indicating a failed comparison; the Byte
program expects 7. Add extrema and remaining modes as separate observed cases.
The `additional/native-extrema/NativeExtrema.UBE` fixture expects exit 73:
Integer minimum survives pack, ByVal echo and unpack; a copied Long maximum
survives replacement of the original with Long minimum. Exit 99 indicates a
wrong value. The additional admission script accepted it at jobs 1 and 4.
This source-level expectation is unexecuted and does not establish layout or ABI;
the independent module inspection and negative controls above remain required.
`additional/native-signed-boundaries/NativeSignedBoundaries.UBE` expects exit
255: each of the Integer and Long minimum and maximum values passes through a
ByVal argument and function result, then each original is replaced ByRef with
the opposite extreme. The eight checks contribute distinct powers of two, so a
single failed comparison removes its corresponding bit. Both stage CLIs passed
the additional admission suite at jobs 1 and 4, 78 checks per stage, using
`rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/additional/check-admission.ps1 -Compiler <stage>/ube.exe`.
Future native runs must assert 255 and independently mutate each expected value;
frontend admission does not execute the fixture or establish its ABI behavior.
`additional/native-neutral/NativeNeutral.UBE` expects exit 74 when uninitialized
Integer- and Long-represented native locals unpack to zero; 99 indicates an
incorrect value. The admission script accepted it at jobs 1 and 4. Its native
result is unexecuted. `additional/native-byte-neutral/NativeByteNeutral.UBE`
separately expects exit 75 when an uninitialized Byte-represented native local
unpacks to zero; exit 99 indicates a wrong value. Both fixtures passed local
frontend admission at jobs 1 and 4. Their native results remain unexecuted; a
source-level zero does not establish aggregate layout.
`additional/native-byte-extrema/NativeByteExtrema.UBE` expects exit 77: a
Byte-represented native value of 255 survives ByVal echo and copy, while a
ByRef replacement changes the original to 0. Exit 99 indicates an incorrect
value. Both local frontend admission checks passed; native execution and ABI
layout remain unverified.
`additional/native-byval-copy/NativeByValCopy.UBE` expects exit 79: the callee
replaces its ByVal Byte-represented argument with 0 and returns that value, while
the caller's original remains 255. Exit 99 indicates an incorrect value or
alias. Both stage-built CLIs accepted the project at jobs 1 and 4; this is not
native execution or proof of the aggregate calling convention. A future control
must make the callee alias the caller and demonstrate rejection.

`additional/native-many-arguments/NativeManyArguments.UBE` expects exit 55:
five distinct Byte-backed native values contribute 1, 4, 9, 16 and 25. Both
source-built stage CLIs accepted it at jobs 1 and 4, as part of 102 admission
checks per stage. A future native run must observe the result and reject changed
argument associations. Use a separately preserved caller/callee boundary with
runtime values to investigate argument placement beyond the first four Windows
x64 argument positions; inspect the actual lowered call rather than assuming a
particular LLVM aggregate mapping. The ordinary optimized fixture may inline
and fold the call, and its admission does not prove any physical ABI behavior.
`additional/check-native-many-graph.ps1` also checked the retained call target,
five source-ordered argument spans and parameter associations using both
targeted stage observers at jobs 1 and 4. It rejected a changed association for
each argument. Run it with `-Observer <targeted-stage-observer>`; this checks
frontend graph records, not lowering or runtime behavior.

The separate hand-authored `native-many-caller.ll` and `native-many-callee.ll`
probe uses volatile inputs and separately compiled O2 objects. Its linked call
returned the expected weighted result, 55; a wrong expected value returned the
failure status. The harness checked the caller relocation and the linked call
and target. This command returned 0:

```powershell
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/verifier/check-native-many.ps1 -Clang 'C:\Program Files\LLVM\bin\clang.exe' -Objdump 'C:\Program Files\LLVM\bin\llvm-objdump.exe' -OutputDirectory bootstrap/out/native-many
```

The harness was also run with a verifier-valid control that swaps the first
and fifth actual arguments while retaining the expected result of 55. The
control exited with the expected failure status, and the ordinary case passed.
It tests one concrete association error in the host probe, not every possible
argument permutation or a UBE lowering.

The harness was then extended to check the linked disassembly for the callee's
four register reads, the caller's fifth-argument stack store and the callee's
corresponding stack read. It passed and rejected an altered stack-offset
observation. The checked disassembly for that run is retained at
`bootstrap/out/native-many/b3d6b22dfcfb4a7099d13c5f18e63747/linked-disassembly.txt`.
This is one hand-written call and one exact toolchain observation; it does not
qualify UBE-generated signatures, other aggregate widths or alternative valid
instruction sequences. The future test must inspect its own output rather than
requiring this particular disassembly spelling.

A separate hand-authored LLVM host probe now exercises one-component i8, i16
and i32 aggregate arguments/results and pointer mutations across separately
compiled caller and callee objects. Inputs are volatile loads; on the current
Windows x86-64 host the linked program returned 0 for the specified values.
The comparator also checked six caller-object call relocations and rejected a
wrong-call observation and a wrong expected runtime value. Command:
`rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/verifier/check-native-aggregate.ps1 -Clang "C:\Program Files\LLVM\bin\clang.exe" -Objdump "C:\Program Files\LLVM\bin\llvm-objdump.exe" -OutputDirectory bootstrap/out/native-aggregate`.
The same script was extended to inspect the linked program's `main` and all six
named callees. It found the six calls and targets and rejected a changed
linked-call observation; the full script passed again. This checks the
hand-authored LLVM pair, object relocations and these linked call targets. The
caller was then extended with target-evaluated `getelementptr` size and field
offset expressions. Its execution checked the hand-written aggregate sizes and
alignments as 1/1, 2/2 and 4/4; a wrong 16-bit alignment expectation returned
failure. The same script passed again. The probe was then extended with three
separately compiled ByVal copy operations: each returns a changed copy, while
the caller's original still has its previous value before the ByRef tests. The
nine object relocations and nine linked call targets were checked, and a wrong
caller-copy expectation was rejected. The script passed again. These
observations do not qualify layout
of future UBE-emitted types, comprehensively verify physical register handling,
prove UBE lowering, or establish a public C ABI. The broader checks below remain
required.

For the latest hand-authored probe, the caller source, callee source and harness
SHA-256 values were respectively
`B772A0F6045D1985FD66E293798A1BF5FE860C711CCABEAA33E07C0EAA8B229D`,
`F755AD9B2CC91D14F33AB2E61B02E3C1410086934C1C81F8829436CF597E1252`, and
`1F164A483CE3B5C1C18B3CEF6F69486BFA4C84EC25250AA85601BF2F58EF609C`.
The output cohort `bootstrap/out/native-aggregate/c9e43b4c6a064026a76d644fd81380e6`
contained caller object, callee object and valid executable SHA-256 values
`C47C3457D7C7AD966F3DDA7634E6A1AB03E34A3A91F368714D177FB8EAD1DBF4`,
`3DC0B32CF797D2D92E47D7C3342164B419B53CF5EA3F2475AB0622D2C054EB25`, and
`1875D68DDD75ADF22BC415763A64AD8A341F6688264DC623E4E24AF7E1969394`.
In a separate Clang `-O2 -S -emit-llvm` emission of the same caller, the target
triple was `x86_64-w64-windows-gnu` and the reported data layout was
`e-m:w-p270:32:32-p271:32:32-p272:64:64-i64:64-i128:128-f80:128-n8:16:32:64-S128`.
That separate emission is supporting target information, not the raw module
generated by the future UBE compiler.
No implementation-provided formatter or pack/unpack implementation can be the
sole oracle for both producer and expected value. Inspect for an aggregate
conversion as well as the actual result, and check that pack/unpack do not invoke
allocation or a runtime constructor.

Probe failure controls by changing the expected payload width, size, alignment,
one expected native value and ByRef alias expectation individually; each must
be rejected. Ensure the type/target/layout observations belong to the exact
module and executable run, not another stage or the bootstrap proof. Report
source, raw LLVM, tool and executable hashes, target triple/data layout, build
and validation commands, results, and the negative controls. Compare the raw
LLVM between supported worker counts under the contract's determinism policy.
If physical target ABI lowering rewrites an aggregate into registers or hidden
parameters, verify it using the target's actual lowered caller and callee rather
than equating UBE internal ABI with C foreign ABI. C interoperability must not
be asserted without its separate contract.

An optimized whole-program result alone cannot establish that a physical call
boundary was exercised: inlining, constant propagation or dead-code removal may
erase it. Include separately compiled UBE caller and callee modules with runtime
inputs, and inspect the final linked call and its target-level argument/result
handling. Establish that the measured call remains present before accepting its
result as ABI evidence. Exercise each width and call mode across that boundary,
including a ByRef mutation visible to the caller. If the selected production
pipeline cannot preserve such a boundary, use a separately documented test-only
build that preserves the production signatures and target ABI, and also run the
normal optimized build for its independent behavioral result. Record precisely
which configuration supports each claim; the preserved-boundary test does not
by itself prove the normal optimizer preserves program behavior.

As a negative control, deliberately mismatch one caller/callee signature or
argument/result expectation in the test harness and require the appropriate
structural or runtime comparison to reject it. Do not execute malformed LLVM or
rely on undefined behavior as the negative control: construct a verifier-valid
mismatch in the independent comparison, or mutate the expected signature/value.
