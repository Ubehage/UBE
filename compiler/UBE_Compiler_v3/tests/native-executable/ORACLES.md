# Native executable independent oracle draft

These hand-calculated cases specify future tests, not executed evidence. Each
snippet is the body of a native MODULE in a valid executable project. Add the
required native source header and identity, and use the existing project format.
Execute the actual fresh-v3-built program; a checker result or LLVM inspection
alone is insufficient. The test harness must preserve full 32-bit process status.

`additional/exit-min/ExitMin.UBE` expects signed Long -2147483648, represented
by Windows process status `0x80000000`; `additional/exit-max/ExitMax.UBE`
expects 2147483647, represented by `0x7FFFFFFF`. Observe all 32 bits through a
host process API and compare the bit patterns as well as signed interpretation;
do not infer either result from an eight-bit shell status. Both projects passed
local frontend admission at jobs 1 and 4. Their native results and controls
that alter one status bit remain unexecuted.

For the host observation mechanism only, `exit-status/check.ps1` builds a C
program calling Windows `ExitProcess` with those two bit patterns and reads
them with .NET `Process.ExitCode` reinterpreted as UInt32. The command
`rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/exit-status/check.ps1
-Clang "C:/Program Files/LLVM/bin/clang.exe" -OutputDirectory
bootstrap/out/native-exit-status` returned exit 0 and reported two observations
and two wrong-bit controls. This does not execute UBE-generated code or prove
the compiler's separate child-process status transport handles those values.
The exit-status probe script SHA-256 was
`A27AFB1F20D5DF29E588B23C07C4967893C95B41A4811E2BE770F125F49F9A21`, its
source was `DF952DC8387DCEB31FBB78899999C8DD3D619849BA040A3FEC1F28D62E1428F7`,
and the observed executable was
`78FEEFA81BFF2B0167FD2C22D3245F87ABED0E4C1BF30BB5CAD2E5A66DAA6828`. The
Clang executable was the same 23.1.3 binary identified by SHA-256
`F3425B2BFF01BC401C84AF6E5E180629182FAFC2EB35CF971A3E50C9CF13F263`.

`additional/initializer-order/InitializerOrder.UBE` expects exit 8: the first
module sets `first` to 3, then `second` to 7; the following module initializes
its result to 8. Declaration-order and module-order reversals produced 5 and 1
in the hand-written host model, which prezeros storage and does not implement
the owner-confirmed on-access module initialization rule. Do not treat those
values as UBE expectations. The local frontend admission
script accepted this project at jobs 1 and 4; native execution and deliberately
reversed initialization controls remain unexecuted. Dependency-before-root
initialization is separately specified by the existing `startup` fixture.

`additional/initializer-events/InitializerEvents.UBE` does not depend on
on-access initialization. Its first module initializes `State.events` to zero; the
next module records 1 then 2 in declaration order; the following module records
3. Main therefore returns 123. Two separately admitted source controls keep
`State` first: `InitializerEventsDeclarationsReversed.UBE` records 2, 1, 3 and
expects 213, while `InitializerEventsModulesReversed.UBE` records 3, 1, 2 and
expects 312. These are expected outcomes for three valid programs, not claims
that native execution has already been tested. A future compiler test must
execute each, compare full exit values, and independently reject swapped
expectations. Both local stage CLIs accepted all three at jobs 1 and 4 as part
of the 84-check additional admission suite.

`additional/initializer-early-access/InitializerEarlyAccess.UBE` specifies the
owner-confirmed on-access rule without lifecycle hooks. The manifest schedules
A before B. A's initializer reads `B.y`; B must first initialize `count` to 0,
call `InitializeValue` exactly once to set it to 1 and produce 7, then return
control so A's `x` becomes 8. When the normal schedule reaches B, B must not
initialize again. Main returns `8 * 10 + 1 = 81`. A compiler that uses a
neutral early value returns a different result, and a duplicate B initialization
changes the count. Both local stage CLIs accepted this fixture at jobs 1 and 4
as part of the 86-check additional admission suite. Its native result and
independent wrong-value/duplicate-initialization controls remain unexecuted.
When lifecycle hooks are supported, separately verify a defined
`Module_Initialize` runs before the early access returns; the current checker
defers such declarations rather than skipping them.

`additional/initializer-cycle/InitializerCycle.UBE` contains A's initializer
needing B, and B's initializer needing A before A has completed. The owner
confirmed that circular references are allowed and detectable cycles receive
a compiler warning, also available to the IDE. This fixture must build without
rejecting the cycle. At runtime B cannot read A before A finishes, so these
unconditional initializers remain waiting for one another until the program is
stopped. The exact warning code, text, source locations and detection limits
remain to be specified. Both local stage CLIs accepted it at jobs 1 and 4 as
part of the 88-check additional admission suite; this is frontend admission
only, not native execution or warning behavior.

The future native oracle must observe the compiler warning and a successful
build, then launch the executable in a contained test process. A passive test
observer must record A entry, B entry, the attempted read of unfinished A and
the runtime's wait decision, on the actual generated path. Throughout a
defined finite observation interval, observe that each initializer was entered
once, no unfinished read or initializer completed, Main was not entered, and
no stack or other runtime failure occurred. Track re-entry count and maximum
active initialization depth throughout, rather than taking only two snapshots.
The observer must not create the wait; do not require a specific OS wait
primitive or zero CPU. Then terminate the contained test process tree and
observe its exit and cleanup. A timeout alone is not proof of infinite waiting.
Reject deliberately recursive re-entry even if it survives the interval, a
stall before the wait, an omitted warning, an error solely for the cycle, an
unfinished read, or Main entry. Include acyclic early access and ordinary
same-module self-reference as successful controls. The existing `--check`
behavior is unchanged; this warning requirement applies to the future build
and IDE diagnostic surfaces.

`verifier/check-initializer-wait-reference.ps1` exercises the event comparator
and harness with a hand-written C trace generator. At O0 and O2 its early case
emitted A/B entry and completion events and result 81. Its waiting case emitted
A entry, B entry and a wait marker, stayed alive without another output line for
the harness interval, and was terminated with exit observed. Separate controls
that emitted a repeated A entry or stopped before the wait marker were rejected
by the sequence comparator; those child processes were also terminated and
observed. The command returned 0:

```powershell
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/verifier/check-initializer-wait-reference.ps1 -Clang 'C:\Program Files\LLVM\bin\clang.exe' -OutputDirectory bootstrap/out/initializer-wait-reference
```

This reference emits test events by hand and has no child processes of its own.
The marker precedes its OS wait, so it does not independently prove entry into
that wait. It neither implements nor verifies generated UBE initialization,
continuous depth tracking, warning output, arbitrary descendants or cleanup.

`additional/initializer-indirect-cycle/InitializerIndirectCycle.UBE` is a
second detectable case: A's initializer calls its own `ReadB` helper, the
helper reads `B.y`, and B's initializer reads `A.x` before A completes. The
future build must warn and remain nonfatal as for the direct case; the future
runtime observer must confirm the same mutual wait without treating a bounded
test timeout as proof of an infinite execution. A warning analysis that only
looks at directly written initializer expressions would miss this fixture.
The two source-built local CLIs accepted it at jobs 1 and 4 in the 90-check
additional admission suite; no future warning or native execution has run.

`additional/initializer-indirect-acyclic/InitializerIndirectAcyclic.UBE`
uses the same A-to-helper-to-B path but B never refers back to A. It is a
no-cycle warning control and expects Main 81: B initializes once and A reads
7 before adding 1. The future build must not warn that this fixture has a
circular initialization dependency. Both local stage CLIs admitted it at
jobs 1 and 4 in the 92-check additional suite; its native result and warning
behavior remain unexecuted.

`additional/initializer-early-call/InitializerEarlyCall.UBE` checks a call into
a not-yet-initialized module. B's initializer sets `y` to 7 and increments
`count` once; its called procedure then changes `y` to 9 and returns 4. A's
`x` is 4, and Main returns `4 * 100 + 9 * 10 + 1 = 491`. Calling B before its
initializer or repeating the initialization after the call changes the observed
result. The future native test must observe the full process status and B's
single initialization; the existing frontend admission is not execution.

`additional/initializer-unused-helper/InitializerUnusedHelper.UBE` has A read
B during initialization, while an uncalled B helper refers back to A. B's
initializer does not call that helper, so there is no initializer dependency
cycle and Main expects 8. This is a control against warning merely because an
unreachable procedure body contains a cross-reference. Both local stage CLIs
accepted both fixtures at jobs 1 and 4 as part of the 96-check additional
admission suite; no native result or warning has yet been observed.

`additional/reference-init-order/ReferenceInitOrder.UBE` combines both order
rules in one fixture. The library's `first` becomes 3 and `second` becomes 7;
the executable then initializes `result` to 8, so Main must return 8. If the
library declarations execute in reverse order, the hand-written host model
produces 5; if the executable initializes before the library, that model
produces 1. Both controls prezero all storage and do not implement on-access
module initialization. These model values are not approved UBE behavior. The
additional admission script passed 68 checks per source-built stage at jobs 1
and 4 with this fixture included. This is frontend admission only; none of the
native outcomes or order mutations has been executed.

To test cross-package order without assuming an early-read value, use a
test-only, preinitialized native event recorder at actual generated module
initializer entry points. For this fixture, record the referenced library's
`LibraryState` entry and then the executable's `App` entry, on the same thread
as ordinary startup; require that exact two-event sequence and Main result 8.
The recorder must observe rather than run or reorder initializers, and the
instrumented startup and operations must correspond to the ordinary build.
Independently swap the observed events and omit either event in comparator
controls; each must fail. Do not assert a UBE value for a deliberately
root-first execution by treating a not-yet-initialized module as zero.

`verifier/check-startup-sequence-control.ps1` tests only the event-comparison
idea with hand-written C: library/executable events were accepted as `LE`,
and the intentionally reversed `EL` control was rejected, at O0 and O2.
It returned 0 for this command:

```powershell
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/verifier/check-startup-sequence-control.ps1 -Clang 'C:\Program Files\LLVM\bin\clang.exe' -OutputDirectory bootstrap/out/startup-sequence-control
```

This is a host comparator control, not the required generated-startup observer
or evidence that a UBE executable ran.

As a host-only check of those hand-calculated expectations,
`verifier/check-initializer-order.ps1` compiles and links separate hand-written
LLVM library and executable modules. At both O0 and O2, the agreed order
returned 8, deliberately reversed library declarations returned 5, and
deliberately initializing the executable first returned 1. Command:
`rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/verifier/check-initializer-order.ps1 -Clang "C:\Program Files\LLVM\bin\clang.exe" -OutputDirectory bootstrap/out/initializer-order-probe`.
This checks these expected values and controls in a test-only host program; it
does not execute the UBE fixture or establish the future compiler's order.

For Boolean `And` and `Or`, independently observe every row with runtime
Boolean operands, including both operands' evaluation. The following values
are expected for both direct expressions and calls returning the operands:

| Left | Right | `And` | `Or` |
| --- | --- | --- | --- |
| False | False | False | False |
| False | True | False | True |
| True | False | False | True |
| True | True | True | True |

For each operator, have separate left and right functions increment separate
module counters and return the requested Boolean. After all four calls, each
counter must be 4, including the `False And ...` and `True Or ...` rows. Check
each result separately before returning a success sentinel; deliberately
invert an expected row and separately suppress a right-side increment to prove
the result and evaluation observers each reject a wrong implementation. These
are future test specifications; no such executable or negative control has
been run as a result of this addition.

The separate `additional/boolean-eager/BooleanEager.UBE` fixture implements
the call-observed rows and counters: expected exit 63, or 91/92 for an And/Or
failure. The local CLI accepted it with `--check` at jobs 1 and 4, both with
exit 0 and empty output. These checks establish frontend admission only; the
native result and negative controls remain unexecuted.

The separate `additional/nested-exit/NestedExit.UBE` fixture expects exit 64:
the outer loop runs three times, and each inner loop exits after two visits, for
six visits total. Exit 91 indicates the wrong inner-loop state and 92 indicates
the wrong final state. Its local `--check` admission passed at jobs 1 and 4,
both exit 0 with no output. Its native result remains unexecuted; a future
negative control must redirect the inner exit to the outer target and show that
the oracle rejects it.

`additional/call-effects/CallEffects.UBE` expects exit 70. Both ByRef
parameters alias the same variable: the first update changes 1 to 3, and the
second sees 3 and changes it to 6. A Function invoked as a statement has its
return value discarded but still increments the trace to 1. Exit 99 indicates
an incorrect alias or missing side effect. The additional admission script
accepted it with jobs 1 and 4; its native result and negative controls for
copying an alias or removing the discarded call remain unexecuted.

`additional/nested-arguments/NestedArguments.UBE` expects exit 71: written
argument order invokes Mark with 2, 1 and 3, giving trace 213. The inner
named association returns 12 and the outer association returns 42. Exit 99
signals a wrong trace or result. The additional admission script accepted the
fixture at jobs 1 and 4; native behavior and negative controls that change
evaluation order or association have not been executed.

`additional/optional-value/OptionalValue.UBE` expects exit 7: calls with both
defaults, an explicit first value, and an explicit second value contribute 1,
2 and 4 respectively. The default values include Integer minimum and Long
maximum; a wrong association or default contributes 100. The additional
admission script accepted it at jobs 1 and 4; native execution and negative
controls changing either default or association remain future work.

`additional/longlong-values/LongLongValues.UBE` expects exit 76: a value of
4294967296 survives a ByVal parameter and result, while a ByRef update changes
the original to 4294967297 without changing its copy. Exit 99 indicates a
wrong value. The additional admission script accepted the fixture at jobs 1 and
4; native execution and controls for truncation and aliasing remain untested.

`additional/comparison-boundaries/ComparisonBoundaries.UBE` expects exit 36.
For LongLong and Byte, each of the six comparison operators contributes one
point for a true case and one for a false case. Twelve further comparisons
exercise Integer and Long extrema. LongLong comparisons also distinguish
4294967296 from zero to expose accidental 32-bit truncation. Every point
depends on the expected branch, so any single wrong branch loses a point. This
is a hand-derived expectation, not an observed native result.

`additional/signed-comparisons/SignedComparisons.UBE` expects exit 24. For
each of Integer and Long, the minimum is less than the maximum, equal values
meet both inclusive comparisons, and unequal extrema differ. Each of the six
operators is tested once with a true result and once with a false result, giving
12 points per type. The test uses variables so the comparisons are runtime
operations. A deliberately unsigned ordering of the signed extrema must lose
points; both compiler stages admit the project at jobs 1 and 4, but no native
result or mutated lowering has been observed.

The separate test-only C reference gives 24 for signed fixed-width values at
both O0 and O2; an unsigned-order control gives 12 and is rejected by the
expected-result comparison. This checks the arithmetic of the reference, not
the UBE fixture or a native lowering:

```powershell
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/verifier/check-signed-comparison-reference.ps1 -Clang 'C:\Program Files\LLVM\bin\clang.exe' -OutputDirectory bootstrap/out/signed-comparison-reference
```

The separate host C reference `verifier/comparison-reference.c` reproduces the
36 mathematical comparisons with fixed-width C values. This command returned
0, observing score 36 at O0 and O2 and score 33 for a deliberately truncated
LongLong control at each optimization level:

```powershell
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/verifier/check-comparison-reference.ps1 -Clang 'C:\Program Files\LLVM\bin\clang.exe' -OutputDirectory bootstrap/out/comparison-reference
```

The reference exercises C and the comparator on this host. It is not execution
of the UBE fixture or independent proof that a UBE compiler implements these
comparisons correctly.

`additional/check-comparison-graph.ps1` separately checks the retained graph
for `wideBit = wideZero`: Boolean equality, two LongLong variable references,
their exact declaration identities and source spans. It rejected independent
operator, type, duplicate-identity and swapped-identity mutations. The same
script also checks the exact
retained Long and LongLong minimum/maximum values and 4294967296, with a wrong
value and type control for each. Both observers passed the expanded six checks
and 14 controls. This is graph evidence, not execution of the other comparisons
or native code.

The C bootstrap's single-source `--compile` path cannot directly execute this
fixture: it rejects the native source envelope and does not implement the
fixture's single-line If or Byte type. A disposable adaptation that removed the
envelope, expanded single-line If and changed Byte variables to Long still failed
at numeric-conversion lowering. It therefore supplies no execution result for
this oracle, and changing the fixture to fit it would not test the same types.
The local source-built v2 stage was also tried on a disposable envelope-free
adaptation with single-line If expanded. It rejected the LongLong minimum
initializer as out of range; spelling the minimum as a subtraction and using a
runtime subtraction from the adjacent value did not get past that initializer.
That older-stage attempt likewise provides no result for this fixture.

`additional/byte-bitwise/ByteBitwise.UBE` expects exit 80. With Byte operands
255 and 15, promotion to 16-bit Integer gives Not = -256, And = 15, Or = 255,
Xor = 240, Eqv = -241 and Imp = -241. Exit 99 signals a wrong result. Both
stage-built CLIs admitted the fixture at jobs 1 and 4; native behavior and a
control using an incorrect Byte-width complement remain unexecuted.

The separate `additional/single-line-if/SingleLineIf.UBE` fixture expects exit
7: the taken branches contribute 1, 2 and 4, while their alternatives and a
false no-Else branch contribute nothing. Local `--check` admission passed at
jobs 1 and 4, both exit 0 with no output. Native behavior is unexecuted. Future
controls must reverse each condition and also execute an untaken branch to
show that the result oracle detects branch-selection errors.

Concrete project inputs are under `fixtures/`: `empty` expects exit 0, `fold`
expects 30000, `signed` expects 23 (99 signals a wrong quotient or remainder),
and `alias` expects 2 (99 signals a failed direct alias). These values are
hand-calculated expectations; no native executable has yet been produced or run.
The existing local checker accepted all four projects with jobs 1 and 4: for each
manifest run `rtk proxy bootstrap/out/v3/ube.exe --check <manifest> --jobs N`.
All eight runs returned zero and no output. The checked local executable SHA-256
was `FFC471D1FC556D8B2B470057DF07497ADFE292DAF3ED20DC30276C2ABBC80EA5`.
Initially `Empty` was rejected as a project identifier; the fixture now uses
`EmptyApp`. This check proves only frontend admission by that local executable,
not expected native behavior or source-cohort requalification.

Three additional checked projects use the same command and executable identity,
each with jobs 1 and 4, all six runs returning zero and no output:

- `native/NativeApp.UBE` expects exit 7. It packs 7 through an explicit
  UBECore reference, copies the value, replaces the original with 9, tests
  inequality and unpacks the copy. Exit 99 signals failed inequality.
- `order/Order.UBE` expects exit 21. Named arguments occur in source order
  `second` then `first`: their side effects leave trace 21, while association
  produces value 12. A skipped right operand must not change trace to 99.
  Exit 98 indicates the combined condition failed.
- `neutral/Neutral.UBE` expects exit 17: the runtime-dependent `42 \ zero`
  produces 0, while exit 99 signals a nonneutral result. This does not observe
  Err and cannot alone verify the complete recoverable-error contract.

These are future native observations, not execution results. The order fixture
is complemented by `eager/Eager.UBE`, which expects 31 after both right operands
run for `False And Touch()` and `True Or Touch()`; 98 signals failure.
`optional/Optional.UBE` expects 3: the direct argument changes from 1 to 3,
the forced temporary cannot change it, and the final omitted ByRef default 10
plus amount 4 is observed in module storage as 14. Exit 99 indicates failure.
`overflow/Overflow.UBE` expects 37: runtime-dependent Long overflow yields 0,
then successful addition yields 7; 99 signals an incorrect result. Err itself
still needs independent observation after the failure and later success.

`conditions/Conditions.UBE` expects 41: numeric nonzero conditions run two
nested loops four times, then the ElseIf selects the matching branch. This is
a future execution expectation; its frontend admission does not establish its
semantic graph or lowering behavior.

Three more admitted projects specify these future observations:

- `conversion/Conversion.UBE` expects 43: converting runtime Long 40000 to
  Integer yields neutral zero; the independent nonzero-to-Boolean and True-to-
  Long conversions yield True and -1. Exit 99 signals a wrong value. An Err
  observer must separately confirm the failed narrowing and its persistence.
- `recursion/Recursion.UBE` expects 15: the recursive sum of 5 through 1
  uses the unassigned neutral Function result at the base-case Exit Function.
- `negative/Negative.UBE` expects signed Long -3, equivalently the full Windows
  process status `0xFFFFFFFD`; a low-byte-only observation cannot qualify it.

`native-widths/NativeWidths.UBE` expects 47: an Integer-backed value containing
-12345 crosses a direct-reference ByVal argument and Function result; a copy
of a Long-backed -123456789 survives while a ByRef call replaces the original
with 123456789. Exit 99 signals a failed comparison. The Byte fixture covers
the third adopted representation. These source observations do not prove the
required 1/1, 2/2 and 4/4 aggregate layouts or target calling convention;
those need a separate independent target-level ABI probe.

`bitwise/Bitwise.UBE` expects 53: for Long values 6 and 3, Not is -7,
And 2, Or 7, Xor 5, Eqv -6 and Imp -5. `comparisons/Comparisons.UBE`
expects 59 for the six stated signed comparisons. Each returns 99 if its
combined condition is false. `COVERAGE.md` records remaining cases rather than
inferring exhaustive operator coverage from these two examples.

`booleans/Booleans.UBE` expects 61: Boolean Not and every truth-table row of
Xor, Eqv and Imp, plus Boolean equality/inequality, must match their expected
values. `True OrElse` and `False AndAlso` skip `Touch`, while `False OrElse` and
`True AndAlso` call it, so the final trace is 2. Exit 99 signals a failed check.
This is an independently calculated expected result, not an executed program.

`startup/Startup.UBE` expects 10: the referenced library initializes its
module value to 7 before the executable module reads it and adds 3. A model
that reads a neutral value before initializing the library would yield 3, but
that does not follow the owner-confirmed on-access rule. No lifecycle hook is used. On 2026-11-02 the
owner confirmed scalar module declaration order during module initialization,
with referenced libraries before the executable; the language specification
now records that rule. This is still a future native result, not an executed test.

`additional/promotion/Promotion.UBE` expects 67: adding Byte values 200 and 100 produces
Integer 300, unary minus promotes Byte 200 to Integer -200, and 17 divided by
-5 yields quotient -3 and remainder 2. Exit 99 signals a failed comparison.
The operands are variables so this probes runtime operations, not just folding.
The local checker separately accepted this project at jobs 1 and 4 with exit 0
and empty output. It is outside the pinned 19-project fixture inventory and is
not included in the structured identity audit for cohort 25f.

`rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/check-fixture-admission.ps1`
passed 38 checks over its nineteen fixtures at jobs 1 and 4, with three comparator
negative controls. Its local checker SHA-256 was
`80955A6E4CF5F4249C70C8EA130C4D0CD97AA07FB7EE847F24838F507A6CD241`.
It checks only exit zero
and empty stdout/stderr; it does not evaluate native expectations or validate
the source-built cohort. The script's argument quoting is solely a fixture
admission helper and is not the future tool-handoff acceptance test.
`expected-results.json` separately records the nineteen hand-authored signed
exit values for a future runner. `rtk proxy powershell -NoProfile -File
compiler/UBE_Compiler_v3/tests/native-executable/check-result-definitions.ps1`
passed its schema, unique-ID/path, signed Long range and fixture membership
checks for all 19 projects. It does not evaluate the programs, check the
hand calculations or compare output from a compiler.
For the Err test, follow the neutral failing division with a runtime-dependent
successful arithmetic operation, then return normally. A same-thread entry
adapter reads the actual runtime error state immediately after Main and reports
it alongside the result. An initially clear state must become nonzero and remain
so after that success; a successful-only control must remain clear. Separately
prove observer set/clear and thread isolation. Exact numeric error codes require
an authoritative mapping before they can be asserted; do not derive one from
the bootstrap implementation. Observer validation cannot substitute a mock for
the generated operation or its actual error-state store.

| Case | UBE body | Expected observation |
| --- | --- | --- |
| Empty entry | `Sub Main()` / `End Sub` | Exit 0. |
| Default result | `Function Main() As Long` / `End Function` | Exit 0. |
| Literal folding and narrowing | `Function Main() As Long` / `Dim x As Integer = 40000 - 10000` / `Main = x` / `End Function` | Exit 30000; checked fact retains folded 30000 and source span. |
| Signed division | `Function Main() As Long` / `Dim x As Long = -17` / `Main = x \ 5` / `End Function` | Exit -3, observed as 32-bit `0xFFFFFFFD`. |
| Signed remainder | `Function Main() As Long` / `Dim x As Long = -17` / `Main = x Mod 5` / `End Function` | Exit -2, observed as `0xFFFFFFFE`. |
| Direct alias | `Sub SetValue(ByRef x As Long)` / `x = 9` / `End Sub` / `Function Main() As Long` / `Dim x As Long = 2` / `SetValue x` / `Main = x` / `End Function` | Exit 9. |
| Forced temporary | Same case, replace `SetValue x` with `SetValue (x)` | Exit 2; the write is discarded. |
| Branch and loop | `Function Main() As Long` / `Dim x As Long = 0` / `While x < 4` / `x = x + 1` / `Wend` / `If x = 4 Then` / `Main = 11` / `End If` / `End Function` | Exit 11. |

Each slash denotes a line break, except the literal backslash operator. Confirm
the exact admitted native envelope and call syntax against the checker before
turning these descriptions into runnable fixtures; a deferred or malformed
fixture cannot establish a backend result. Add independently calculated cases
for all supported operators, conversions, call/default/named argument modes,
short circuit and evaluation order, module/reference visibility, native
Pack/Unpack/copy/equality, neutral initialization, recursion, exits, overflow,
divide-by-zero and conversion errors. Include boundary values, both branches,
and negative controls that intentionally change an expected value. Observe
runtime Err through the reviewed adapter, including stale Err after success.

For every failure below, run with a preexisting final file containing known
non-executable sentinel bytes and separately with no final file. Compare the
final bytes/absence, enumerate owned sibling temporaries, and verify no process
or worker remains. Establish injected fault activation separately from the
compiler's diagnostic. Repeat where applicable for one and multiple workers.

| Fault | Required independent observation |
| --- | --- |
| Existing frontend error or unsupported valid input | Correct existing diagnostic/defer class; tool is never started; final unchanged. |
| Missing tool or process-start denial | Non-success and useful tool failure; final unchanged. |
| Tool returns nonzero after writing partial candidate | Non-success, partial candidate removed, final unchanged. |
| Tool returns success without candidate | Non-success, final unchanged. |
| Invalid emitted LLVM | LLVM validation rejects it; linker/publication not treated as success. |
| Write, flush, close, disk-full or replace failure | Non-success, final unchanged; real fault point was reached. |
| Cancel before launch, while child writes, and before replacement | Non-success; child and workers drained before cleanup; final unchanged. |
| Cleanup denial | Primary failure remains reported and cleanup failure observable; no false success. |
| Path with spaces and shell metacharacters | Exact child argument vector matches expected; no shell interpretation. |

Successful replacement must also be tested with and without an existing final
file. Run the candidate and verify expected result after replacement, then repeat
identical inputs across stages and worker counts to compare raw LLVM and results.
Use test-owned, stable source fixtures and independently check the bytes retained
by each build's actual intake. A deliberately changed retained byte must exclude
the run from the identical-input cohort or be rejected by the comparator. A
before/after pathname hash alone does not establish what a concurrent read saw;
the test does not require the production compiler to detect user edits.
The harness must include wrong-value, wrong-exit, tool-not-invoked and fault-not-
reached controls so that its own passing result has meaning.
