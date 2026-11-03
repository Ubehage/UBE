# Runtime error oracle: review draft

## Error-support selection and retained-link audit

`../../NATIVE-RUNTIME-CONTRACT.md` selects the existing native TLS error-state
semantics, a shared minimal error-unit extraction, and separate final-Main and
typed-checkpoint observer records. The extracted unit and its closed recording
paths are implementation dependencies, not existing artifacts. The observer
must use the state actually set by generated operations, not a test-only shadow.

The maintained host audit now links the existing whole bootstrap runtime and a
hand-authored three-width LLVM bridge through the recorded explicit CRT/archive
cohort. Command:

```powershell
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/verifier/check-linked-error-support.ps1 -SourceReport bootstrap/out/explicit-link-inputs/318209f12b5b4f0282acf596c47e6386/report.json -OutputDirectory bootstrap/out/linked-error-support
```

Observational mode returned 0, retaining report
`bootstrap/out/linked-error-support/f9fdcfd73ce6416096538c7517e6135f/report.json`.
The good executable returned 0: signed minima `Mod -1` preserved seeded Err 77
for Integer/Long/LongLong; zero divisors produced neutral zero and Err 11;
clear produced zero; overlapping native workers retained independent state in
both launch orders while the main thread retained 99. A bridge mutated from
Err 11 to 12 and a comparator expecting another thread's 99 each returned 1.

The minimality result was **false**. With function/data sections and
`--gc-sections`, 28 defined `ube_` symbols survived, 24 outside the error-only
allowlist. Four explicit `ube_library_*` exports kept unrelated library/GC
support live. The no-GC control retained 301 UBE symbols, 297 outside the
allowlist, and was rejected by the same comparator. Symbol counts concern UBE
names, not the full CRT/OS dependency closure.

The same command with `-RequireMinimal` returned 1 as required for that failure,
after writing
`bootstrap/out/linked-error-support/a8148ba056704c9b9c223548adf66be8/report.json`.
It is not a passing minimal-runtime gate. The source script SHA-256 is
`07F34810D6D6C4CA3B30D02C5F2F863F60F47CD78E69DDBF65FAEB8EBD5D8317`.
Reports record input/source/tool/generated-object identities, exact commands,
environment, maps, symbols, imports/exports and disassembly. The harness's
before/after source hashes establish this test cohort; they are not a proposed
compiler source-change check. Transitive header identities are not completely
inventoried. No fresh-v3 generation, Full/None equivalence, stack reserve or
production process/publication boundary is proved by this host-only audit.

After shared error-unit extraction, the implementation gate must exercise that
actual unit and require minimality, including the reviewed specialized setter
and separately recorded platform/CRT closure. Do not weaken the allowlist to
accept the current unrelated exports. Qualify the observer formats and source
program error/startup/call controls independently.

## Independent generated-program obligations

These are independent future tests, not results. The authoritative rules are
`lang-doc/language-spec.md` sections 9 and 14 and `lang-doc/conversion-table.md`.
For a runtime-dependent checked failure, the operation returns its neutral
result and updates the current thread's Err; a later success does not clear it.
A known failure is a compile-time diagnostic instead. The general specification
identifies these semantics, but this review did not find an authoritative
language-wide numeric mapping for these arithmetic errors. The bootstrap runtime
and library compatibility inventory alone do not establish a normative mapping.

The first-target contract selects Err 6 for checked integral overflow and
out-of-range integral narrowing, and Err 11 for integral division or remainder
by zero. The existing v2 checked arithmetic and narrowing contracts specify
those same numbers, consistent with the project's VB6-compatible default. This
is a bounded target decision, not a finalized language-wide mapping. Test the
actual same-thread number against the selected value; require a wrong-nonzero-number negative control so that a
test accepting any error cannot satisfy the exact-number check. The nonzero
observations in the table below are necessary but do not by themselves satisfy
that stronger check.

The following independent boundary matrix specifies dynamic conversions between
the first target's ordinary integral widths. Each source is a variable of the
indicated type, assigned after initialization so the conversion under test is
not a known failing constant. For each row, test all four values separately.
The two endpoints must convert to the same mathematical value and preserve a
preseeded Err; each adjacent out-of-range value must produce the destination's
zero and set Err 6. Observe each operation immediately on its native thread so a
later error cannot mask a missing update. Also test a deliberately wrong Err
and a deliberately wrong endpoint expectation to prove comparator sensitivity.

| Source to destination | Valid lower, valid upper | Below lower, above upper |
| --- | --- | --- |
| Integer to Byte | 0, 255 | -1, 256 |
| Long to Byte | 0, 255 | -1, 256 |
| LongLong to Byte | 0, 255 | -1, 256 |
| Long to Integer | -32768, 32767 | -32769, 32768 |
| LongLong to Integer | -32768, 32767 | -32769, 32768 |
| LongLong to Long | -2147483648, 2147483647 | -2147483649, 2147483648 |

`additional/narrowing-boundaries/NarrowingBoundaries.UBE` now supplies all 24
value cases through six typed functions. Its independently expected Main result
is 90; a failed value comparison returns 99. Both source-built stage CLIs passed
the additional admission suite at jobs 1 and 4 (72 checks each). The separate
`check-narrowing-graph.ps1` comparator passed with both 25f targeted observers,
checking the six return-assignment conversion facts and rejecting 18 source,
destination and target mutations. Run it as `rtk proxy powershell -NoProfile
-File compiler/UBE_Compiler_v3/tests/native-executable/additional/check-narrowing-graph.ps1
-Observer <observer-path>` using the observer paths in `NATIVE-LOWERING-REVIEW.md`.
The graph comparison does not independently establish each parameter's identity
or verify every call argument. Neither admission nor graph observation executes
the program. The combined Main also cannot observe Err after each conversion;
individually controlled cases and the same-thread Err adapter remain required.
Separately cover supported widening, identity, Boolean and native-value
conversions; this matrix does not claim to cover them.

As a host-only reference, `verifier/narrowing-reference.c` calls the existing
bootstrap `ube_checked_narrow_i64` helper with the 12 distinct destination
boundary values (the source-width rows share some values). It observes the
returned value and actual bootstrap Err immediately, with both clear and seeded
Err. The following command passed at O0 and O2, and each of three independently
wrong expectations (error number, valid value and retained Err) returned the
required failure status at both optimization levels:

```powershell
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/verifier/check-narrowing-reference.ps1 -Clang "C:\Program Files\LLVM\bin\clang.exe" -OutputDirectory bootstrap/out/narrowing-reference
```

The first test-script attempt incorrectly expanded a compiler argument into
characters; the script was corrected before the passing run. This tests the
existing bootstrap helper and the comparator controls, not source-width
lowering, generated UBE code, the future runtime ABI or every conversion value.

As a host-only observer experiment, `verifier/runtime-error-observer.c` links
the current bootstrap runtime directly. Two native threads seed distinct error
numbers and synchronize before arithmetic: one performs runtime division by
zero and observes 11, the other performs signed-64 minimum `Mod -1` and observes
its original 32; both values are zero. The main thread's separate 77 remains
unchanged and explicit clear gives zero. The normal test returned 0; a build
with `WRONG_THREAD_EXPECTATION` returned 1. Both were compiled with
`rtk proxy "C:\Program Files\LLVM\bin\clang.exe" --target=x86_64-w64-windows-gnu -std=c17 -O2 -ffunction-sections -fdata-sections -Wall -Wextra -Werror compiler/UBE_Compiler_v3/tests/native-executable/verifier/runtime-error-observer.c bootstrap/runtime/bootstrap_runtime.c "-Wl,--gc-sections" -o bootstrap/out/runtime-error-normal.exe`,
adding `-DWRONG_THREAD_EXPECTATION` and using a different output for the
negative control. Run each executable directly and compare exit 0 or 1. The
first command attempt needed the linker argument quoted for PowerShell; the
quoted builds passed. This tests the current bootstrap C runtime only, not
fresh-v3 generated bodies, the future runtime selection or the proposed
language-wide error mapping.

The experiment was then made deterministic: the division-by-zero thread must
finish after recording its error while the remainder thread is still waiting;
only then may the remainder thread run and check its own preserved value. The
same normal and wrong-thread-expectation builds were rebuilt and returned 0
and 1 respectively. This verifies that one order in the bootstrap runtime; it
does not establish all thread schedules or future generated behavior.

The probe now also accepts `reverse`, which completes the remainder thread
before allowing the division-by-zero thread to run. After rebuilding, both
`rtk proxy bootstrap/out/runtime-error-normal.exe` and the same command with
`reverse` returned 0; both corresponding `runtime-error-negative.exe` runs
returned 1. These are two controlled orders, not all concurrent schedules.

`verifier/runtime-error-bridge.ll` adds a hand-authored guarded LLVM remainder
operation that writes to the actual bootstrap error store on a zero divisor and
preserves it for signed-64 minimum `Mod -1`. The same two-thread observer calls
that LLVM function on one thread and a bootstrap division helper on the other.
`rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/verifier/check-runtime-bridge.ps1 -Clang "C:\Program Files\LLVM\bin\clang.exe" -OutputDirectory bootstrap/out/runtime-bridge`
compiled the LLVM function separately at O0 and O2, verified it, and ran both
controlled thread orders. All four correct runs returned 0; a separately
compiled mutation that incorrectly sets Err on minimum `Mod -1` returned 1 in
all four combinations. This joins hand-authored LLVM and the current bootstrap
error store in one host test; it does not establish fresh-v3 emission or select
the production runtime ABI.

The bridge now includes 16- and 32-bit signed remainder functions alongside
the 64-bit function. In both controlled thread orders and at O0/O2, the
observer checks each width's minimum `Mod -1` preserves seeded Err and each
zero divisor records 11. The same script separately mutates each width to set
Err incorrectly in its minimum/-1 branch; all twelve mutated runs (three widths,
two optimizations and two orders) returned 1, and the four correct runs returned
0. This remains hand-authored LLVM linked to the bootstrap runtime, not
fresh-v3 output or a final language-wide error mapping.

The bridge comparator now independently changes each zero-divisor branch to
record 12 instead of 11, in addition to the three minimum/-1 mutations. The
same command passed again: four unmodified runs returned 0, and all 24 mutated
runs (six independent mutations, two optimizations and two thread orders)
returned 1. These controls show the observer distinguishes the tested nonzero
error numbers; they do not qualify production emission.

The bridge observer additionally checks `-17 Mod 5 = -2`, `17 Mod -5 = 2`,
and `-17 Mod -5 = -2` for all three widths while retaining the seeded error.
For each width, a separate mutation substitutes unsigned remainder for signed
remainder. The same script returned 0: four unmodified runs passed and all 36
mutated runs (nine variants, two optimization levels and two controlled orders)
returned 1. This remains a finite hand-authored host test, not an exhaustive
arithmetic proof or fresh-v3 execution.

`verifier/check-i16-exhaustive.ps1` separately drives the hand-written i16
LLVM remainder function against every signed 16-bit dividend. For each it
compares eight nonzero divisors (`-32768`, `-255`, `-7`, `-1`, `1`, `7`,
`255`, `32767`) against a wider C calculation and requires a preseeded Err to
remain 73; it also checks a zero divisor returns zero and records Err 11. O0
and O2 bridge builds passed all 589,824 operand cases each. A deliberately
wrong expectation for minimum `Mod -1` failed at both levels. Command:
`rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/verifier/check-i16-exhaustive.ps1 -Clang "C:\Program Files\LLVM\bin\clang.exe" -OutputDirectory bootstrap/out/i16-exhaustive`.
The divisor set is representative rather than exhaustive, and the probe uses
hand-written LLVM plus the bootstrap runtime, not fresh-v3 output.

`verifier/check-wide-boundaries.ps1` checks the same hand-written bridge with
11 boundary/representative dividends and nine divisors for each of i32 and i64,
including minimum/-1 and zero. The i32 expected remainder uses a wider C type;
the i64 reference guards zero and minimum/-1 before applying C remainder. It
checks seeded Err preservation or Err 11 for each case. Both O0 and O2 builds
passed 198 cases each, and a wrong i64 minimum/-1 expectation failed at both
levels. Command: `rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/verifier/check-wide-boundaries.ps1 -Clang "C:\Program Files\LLVM\bin\clang.exe" -OutputDirectory bootstrap/out/wide-boundaries`.
These finite samples do not establish every 32/64-bit combination or fresh-v3
lowering.

An additional event-controlled `overlap` mode now keeps both workers alive
after their first arithmetic operation. Once both have recorded their distinct
results, the main thread confirms its own Err, releases both workers, and each
worker rereads its own Err. The same bridge script passed at O0/O2 in both
ordered modes and this overlap mode: six correct runs returned 0 and all 54
mutated runs returned 1. The synchronization establishes this one overlapping
state, not every possible interleaving or future runtime integration.

With the optional `-Objdump C:\Users\Ubehage\Documents\WinLibs\mingw64\bin\objdump.exe`,
the same bridge script also built the C observer and bootstrap runtime at O2
with and without debug information, linking the same O2 hand-authored LLVM
object. Both executables passed the forward, reverse and overlap checks; the
fixture's C debug records appeared only in the debug build. The command was the
bridge command above with that additional `-Objdump` argument, and returned 0.
This checks the observed values and thread state of these host builds; it does
not provide UBE-source debug metadata, prove debug mapping for the LLVM bridge,
or establish general debug/no-debug equivalence.

`verifier/check-debug-runtime-bridge.ps1` separately compiles a guarded C
remainder bridge to LLVM at O2 with and without debug information, verifies and
compiles each module, then links each to the same bootstrap-runtime observer.
Both passed forward, reverse and overlapping-thread checks; a debug build
mutated to set Err for minimum `Mod -1` failed all three. The debug LLVM had
`FullDebug` and location records. The initial no-debug comparator incorrectly
assumed `-g0` removes every compile-unit node; Clang 23.1.3 instead emitted a
`NoDebug` compile unit without location records. The comparator was corrected
to check those observed distinctions before the passing run. Command:
`rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/verifier/check-debug-runtime-bridge.ps1 -Clang "C:\Program Files\LLVM\bin\clang.exe" -Objdump "C:\Users\Ubehage\Documents\WinLibs\mingw64\bin\objdump.exe" -OutputDirectory bootstrap/out/debug-runtime-bridge`.
This is C-generated LLVM and bootstrap runtime behavior; it is not UBE-emitted
debug information or a general equivalence proof.

The script was subsequently extended to inspect decoded lines in the linked
artifact. The debug build contained rows for the three macro invocation lines
17, 18 and 19; the no-debug build did not contain the tested line, and a wrong
line expectation was rejected. The updated command above passed along with the
behavior and mutated-debug checks. These rows identify macro invocation lines;
they do not establish statement-level UBE mappings or an operational debugger.

The linked-line comparison now also reads disassembly symbol boundaries and
requires a line-17, line-18 and line-19 row inside the respective i16, i32 and
i64 function ranges. Swapping the first two expected line assignments is
rejected. The same debug/plain script returned 0 after this change. This is a
coarse function-range association for this C macro fixture, not proof that every
instruction or source statement has an accurate mapping.

The observer must query the same thread and actual error store used by generated
operations after Main returns and before any cleanup that could change Err. It
reports both the complete signed Long Main result and error number through a
test channel separate from UBE program stdout. The ordinary build and observed
build must use the same generated bodies; compare their raw bodies or an
equivalent independently checked representation. The observer's own set/read/
clear and thread-isolation controls must pass before accepting program results.
The observer must not replace the operation, set an error on its behalf, or
infer failure solely from a zero value.

| Program or controlled setup | Expected independent observation |
| --- | --- |
| `neutral/Neutral.UBE` | Main 17; starting with cleared Err, runtime `42 \ zero` returns zero and leaves Err 11. |
| `overflow/Overflow.UBE` | Main 37; Long maximum plus runtime 1 returns zero and records Err 6; subsequent successful `failed + 7` is 7 and retains the error. |
| `additional/multiply-overflow/MultiplyOverflow.UBE` | Main 81; dynamic Long multiplication `46341 * 46341` yields neutral zero and records Err, while the later in-range `46340 * 46340` yields 2147395600 and retains that Err. Observe Err independently; Main alone cannot prove it. |
| `additional/subtraction-extrema/SubtractionExtrema.UBE` | Main 87; dynamic `Long` minimum minus 1 and maximum minus -1 each yield zero, while minimum minus -1 yields -2147483647 and maximum minus 1 yields 2147483646. Starting with clear Err, observe nonzero Err independently after Main. Also run separately controlled variants with only one failing subtraction each and observe Err after that operation: the combined case alone cannot prove that both failures set it. Successful boundary operations must retain a preseeded Err. |
| `additional/division-overflow/DivisionOverflow.UBE` | Main 82; dynamic Long minimum divided by -1 yields neutral zero and records Err without a native division trap or LLVM poison. The subsequent division by 1 returns Long minimum and retains Err. Observe Err independently; Main alone cannot prove it. |
| `additional/negate-minimum/NegateMinimum.UBE` | Main 84; dynamically negating Long minimum yields neutral zero and records Err; the later successful addition yields 7 and retains Err. Observe Err independently; Main alone cannot prove it. |
| `conversion/Conversion.UBE` | Main 43; dynamic 40000 to Integer yields zero and sets Err 6; successful Boolean conversions retain it. |
| `additional/initializer-self/InitializerSelf.UBE` | Main 97; `number` starts at neutral zero before its initializer reads it, so the initializer yields 5. Runtime division by zero initializes `failed` to zero; the later assignment uses the same storage and makes it 7. Observe the same-thread Err independently: it is 11 and the successful assignment does not clear it. Controls that seed `number` with 1 instead of zero, omit the later assignment, or alter the expected Err must be rejected. |
| Successful-only control: `Dim divisor As Long = 2` / `Dim result As Long = 42 \ divisor` | Runtime result 21 and initially clear Err remains clear. |
| Preseed a distinct positive Err, then execute a successful checked operation | Correct value and the same preseeded Err; this proves success does not clear stale state. |
| `additional/error-replace-division/ErrorReplaceDivision.UBE` and `additional/error-replace-overflow/ErrorReplaceOverflow.UBE` | From clear Err, expect Main 88 then Err 11 for overflow followed by division by zero, and Main 89 then Err 6 for the reverse order. Both failing expressions yield zero. The two orders distinguish the final error from a stale earlier one; independently run each failure by itself to prove it records its own error. Swap the two expected final numbers as negative controls. |
| Execute the failing operation on a worker and an independent success on another | First thread records an error; second retains its independently preseeded state. The test adapter must use actual thread-local runtime state. |
| Known `42 \ 0`, known Long overflow and known narrowing beyond Integer | Compile-time rejection with the applicable semantic diagnostic, no tool invocation and no final artifact change. |
| Runtime signed minimum divided by -1, and negation of the signed minimum | Each produces neutral zero and an error without target trap or LLVM poison; construct the minimum with the admitted expression spelling. |
| `additional/remainder-minimum/RemainderMinimum.UBE` | Main 83; `Long` minimum `Mod -1` returns zero successfully. With initially clear Err it stays clear; with a distinct preseeded Err it stays unchanged. Observe Err separately, and do not execute LLVM `srem` with this operand pair. |
| `additional/remainder-integer-min/RemainderIntegerMin.UBE` and `additional/remainder-longlong-min/RemainderLongLongMin.UBE` | Main 85 and 86 respectively; each signed minimum `Mod -1` returns zero successfully. With initially clear Err it stays clear; with a distinct preseeded Err it stays unchanged. Observe Err separately and avoid executing `srem` with either exceptional pair. |
| Module scalar initializer divides by a runtime zero, then a later initializer and Main run | The failing operation yields neutral zero and records Err; the later initializer and Main execute, observe the defined values and leave the error intact after successful operations. Separately exercise an actual failure to complete module initialization and its unwind; do not equate it with this recoverable expression failure. |
| `additional/initializer-cycle/InitializerCycle.UBE` | Build successfully with a warning for the detectable initialization cycle. At runtime observe both initializer dependencies and no entry to Main; the mutual wait may continue until the test harness stops the contained program. A finite timeout alone does not prove an infinite wait or a runtime error. The IDE must be able to present the warning. UBE1514's format and direct-fixture location are selected in `NATIVE-BUILD-DIAGNOSTICS.md` and `diagnostics.json`; analysis limits and IDE transport remain unqualified. Test user recursion and its stack limit separately from the mere presence of a reference cycle. |
| `additional/reference-initializer-error/ReferenceInitializerError.UBE` | The referenced library initializes `divisor` to 0, `failed` to neutral 0 after division by zero, and `later` to 7. The executable then initializes `result` to 8 and Main returns 8; the same-thread Err remains 11. Aborting on the recoverable arithmetic error fails to reach Main. A root-first hand-written host model returns 1 because it prezeros storage and does not perform the owner-confirmed on-access initialization; do not assert 1 as a UBE result. The adapter must run ordinary startup on the observed thread; a deliberately skipped initializer must fail the comparison. |
| Deep recursion through and beyond the reviewed runtime safety boundary | For a qualified recoverable pre-call refusal, observe Err 28 on the same thread, a neutral call result, no callee entry and the specified prior argument effects; a following successful operation preserves Err. Also test a separately injected condition where safe recovery cannot be established: require the documented controlled noninteractive failure path, with no native stack overflow, corrupted memory or leaked resources. Shallow recursion still returns 15. The recoverable behavior is owner-confirmed; the real guard and unsafe-recovery path are unqualified. |
| `additional/stack-call-effects/StackCallEffects.UBE`, with a test seam refusing only the call to `Work` after evaluating its argument | Without refusal, Main returns 118: `Argument` runs once, `Work` enters once and returns 8. With confirmed refusal, Main returns 100: `Argument` ran once, `Work` did not enter and its neutral result is 0. Independently observe same-thread Err 28 immediately after the refused call and after the successful operations in Main; test both clear and preseeded Err. Reject controls that skip argument evaluation, enter `Work`, return a nonzero neutral result or set a different error. The seam controls the guard's decision and must not emulate the call or its error behavior. Both stage CLIs admitted the fixture at jobs 1 and 4; none of these runtime observations has run. |
| Short-circuit false `AndAlso` / true `OrElse` with a runtime-failing RHS | RHS is statically checked but not executed; with initially clear Err it remains clear. An eager Boolean operation with the same RHS does execute it. |

`additional/check-stack-call-graph.ps1` separately checks that `Work(Argument())`
retains the correct two declaration targets, the nested call as its argument
child, and the association with `Work`'s parameter. Both targeted stage
observers listed in `NATIVE-LOWERING-REVIEW.md` passed and rejected four
independent target, child and parameter mutations. This is graph evidence; it
does not execute either call or the proposed refusal path.

The host-only `verifier/stack-error-reference.c` implements this one call
scenario in C and uses the existing bootstrap Err store. It checks normal and
refused calls with clear and seeded Err, then checks that a successful checked
addition preserves the resulting error. The command below returned 0: O0 and O2
passed, and each rejected four separately built controls changing the error,
callee entry, neutral result or argument evaluation.

```powershell
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/verifier/check-stack-error-reference.ps1 -Clang 'C:\Program Files\LLVM\bin\clang.exe' -OutputDirectory bootstrap/out/stack-error-reference
```

This checks a hand-written reference and the existing bootstrap error store;
it does not execute the UBE fixture, exercise a real stack guard or qualify a
fresh-v3 runtime ABI. The owner has since confirmed the recoverable Err 28 behavior.

The related `verifier/stack-error-live.c` joins the test-only frame-aware guard
and existing bootstrap Err store. On separate small-stack worker runs with clear
and seeded Err, it checks one argument evaluation per attempted call, no extra
callee entry at refusal, a neutral result, Err 28, all entered frames unwound,
and preservation of that error across a successful checked addition. The main
thread's seeded Err remains independent. The following command returned 0 at
O0 and O2, with and without debug information, and rejected separately built
wrong-error and wrong-result controls in all four configurations. It checked
that the debug executables contain a `.debug_info` section:

```powershell
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/verifier/check-stack-error-live.ps1 -Clang 'C:\Program Files\LLVM\bin\clang.exe' -Readobj 'C:\Program Files\LLVM\bin\llvm-readobj.exe' -OutputDirectory bootstrap/out/stack-error-live
```

This executes a hand-written C test and bootstrap runtime, not UBE lowering.
Its fixed frame and margin, host stack behavior, lack of injected memory-pressure
failures and test-only control flow do not qualify a production guard or ABI.
The debug-section check does not establish correct source locations.

The recursion boundary needs more than one self-recursive example. Exercise
mutual recursion and calls with different numbers of live locals and arguments,
with work after each recursive call so tail-call elimination cannot remove the
frames being tested. Check the documented boundary and one call beyond it for
each applicable shape, with optimization and debug settings used by the first
target. A call-count limit alone is not evidence of stack safety: frame sizes,
runtime support calls and the stack space already in use can differ. The
implementation must establish that its chosen guard leaves enough stack for
the failure path and unwind on each supported entry/thread configuration, or
reject a configuration it cannot support safely. Observe a normal controlled
failure and cleanup, not merely a nonzero process status; a stack-overflow
exception or forced termination fails this oracle. These are future acceptance
checks, not a proposed universal language recursion limit.

Also test a finite tail-recursive function separately from the frame-consuming
cases. Check its ordinary result and same-thread Err with Full and None debug
information at the supported optimization level. Inspect or instrument the
actual emitted path before claiming that a recursive frame was consumed: an
optimizer may reuse a frame or turn a tail call into a loop. The test must not
require Err 28 merely at a chosen source-level call count. If an injected,
confirmed pre-call refusal is exercised on a path that retains a call, verify
its argument effects, neutral result and Err independently. This does not set
a cross-optimization recursion limit or establish how the future guard works.
`additional/tail-recursion/TailRecursion.UBE` and its `NoDebug` variant each
expect Main to return 7 after 12 recursive steps. With an independently
preseeded Err, observe that successful execution preserves it on the same
thread. Both semantic stages admitted both projects at jobs 1 and 4 as part of
106 checks per stage; no native result, Err observation or tail-call
transformation has yet been measured.

For the proposed unrecoverable path, use a test seam that reports the precise
unsafe-to-recover condition while still leaving enough stack for the test to
observe the disposition. Require status 1, one complete fixed diagnostic on
stderr when that stream is available, no modal interaction and no user-code
marker after the failure. Close stderr in a separate run and require a bounded
exit with status 1 rather than a retry loop or crash. A normal `Main` returning
1 is a separate control and must not be classified as this failure from the
status alone. This is a proposed target disposition; neither a concrete message
nor a qualified recovery/fatal boundary is established by this test design.
Also fill an inherited stderr pipe and hold its reader without draining: require
bounded exit and check the parent's pipe mode remains unchanged. If the selected
scheme can write only part of a message, require its documented best-effort
disposition rather than treating partial output as a complete diagnostic.

`verifier/check-stack-fatal.ps1` tests a host-only disposition stub at O0 and
O2. With stderr open it checks one fixed diagnostic, empty stdout and status 1;
with the child closing its stderr handle it checks bounded exit 1 and empty
captured streams. An ordinary status-1 return produces no diagnostic. The
command below returned 0 for all six cases:

```powershell
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/verifier/check-stack-fatal.ps1 -Clang 'C:\Program Files\LLVM\bin\clang.exe' -OutputDirectory bootstrap/out/stack-fatal
```

The same command now fills an inherited stderr pipe before launching the stub.
At both optimization levels the child remained blocked in its synchronous
write until the test harness drained the pipe, then exited 1. This is an adverse
control: the stub does not meet a bounded-termination requirement for a full
pipe. The stub runs with ordinary available stack and does not reproduce actual
exhaustion, a broken pipe or a UBE-generated runtime failure. Its wording is
test data, not a selected public diagnostic, and it does not establish that the
fatal path is safe under the conditions in which a future runtime would need it.
The command now also tries setting the inherited pipe to `PIPE_NOWAIT`. With the
pipe full, setup failed with Windows error 231 at O0 and O2. With an empty pipe,
setup succeeded and the child exited, but the parent observed its inherited
write handle's mode had changed. This is one host experiment, not proof of all
pipe implementations. Microsoft documents that
[`SetNamedPipeHandleState`](https://learn.microsoft.com/en-us/windows/win32/api/namedpipeapi/nf-namedpipeapi-setnamedpipehandlestate)
also accepts anonymous pipe handles, and that a nonblocking byte-pipe
[`WriteFile`](https://learn.microsoft.com/en-us/windows/win32/api/fileapi/nf-fileapi-writefile)
can write only part of a message. A candidate must handle setup failure and
partial output, and must not silently alter a caller's inherited handle state.
The test also tries a separate writer thread with a bounded wait followed by
`TerminateProcess` on the test process. On this host, at O0 and O2 it exited
with status 1 while the stderr pipe was still full and the parent's pipe mode
was unchanged; the empty-pipe control captured the message. The writer signaled
readiness just before its write, so scheduling means this does not prove the
write had entered the kernel before termination. The thread is created in the
test failure path, not under actual exhaustion. Microsoft states that
[`TerminateProcess`](https://learn.microsoft.com/en-us/windows/win32/api/processthreadsapi/nf-processthreadsapi-terminateprocess)
requests cancellation of pending I/O but process exit waits for that I/O to
complete or cancel, and DLL state can be compromised; it is not a universal
bounded-exit or cleanup guarantee. This experiment does not select it for UBE.
Another test mode waits for its dedicated writer, requests
`CancelSynchronousIo` after that writer remains pending, and requires the
writer to finish with `ERROR_OPERATION_ABORTED` before exiting through
`ExitProcess`. With the pipe still full, the parent observed status 1 and an
unchanged pipe mode at O0 and O2. This establishes cancellation of the tested
write on this host. Microsoft notes that [some I/O operations cannot be
cancelled and drivers need not support cancellation](https://learn.microsoft.com/en-us/windows/win32/fileio/canceling-pending-i-o-operations);
the test creates its writer under ordinary stack conditions and does not qualify
the failure, scheduling, resource-exhaustion or cleanup cases needed for UBE.

The same harness now includes a prestarted-writer control: the test creates a
writer thread and waits for its readiness before signaling the simulated fatal
condition. With a full pipe, both O0 and O2 runs returned status 1 within the
harness deadline, left the pipe full and did not change its inherited mode;
with a draining stderr the fixed test message was captured. The command above
was rerun with `-OutputDirectory bootstrap/out/stack-fatal-prestarted` and
returned 0. This moves test thread creation before the simulated failure; it
does not prove that creating a permanent writer is suitable for UBE, that the
writer had entered the blocked kernel call, or that `TerminateProcess`,
signaling and waiting are safe and bounded under actual stack exhaustion.
The earlier termination and pending-I/O limitations still apply.

The test-only `verifier/stack-frame-probe.c` puts an explicit guard call inside
a function with an 8192-byte local frame. This command compiled it for the
selected Windows target at O0 and O2, inspected the object relocations, and
returned 0 after observing `___chkstk_ms` before `recursion_guard` in both
objects and rejecting two changed-order comparator controls:

```powershell
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/verifier/check-stack-frame.ps1 -Clang 'C:\Program Files\LLVM\bin\clang.exe' -Objdump 'C:\Program Files\LLVM\bin\llvm-objdump.exe' -OutputDirectory bootstrap/out/stack-frame
```

The observation shows that this compiler can probe the callee's frame before
executing its source-level guard. Placing the only safety check inside such a
callee therefore cannot be assumed to protect that frame allocation. The probe
does not deliberately overflow a stack, select a guard strategy, measure all
frames or establish behavior of UBE-generated code.
The probe additionally contains a separate caller that checks the same guard
before calling the large-frame callee and performs work after the call. The
script now inspects its object relocations: at both O0 and O2 the caller's guard
call precedes a retained call to the callee, and two changed-order caller
controls were rejected. Rerunning the command above returned 0. This shows a
possible call ordering for this test, not that the guard measures available
stack, covers every call or reserves enough space for failure handling.
The same command now also links a test driver. For both optimization levels it
checks that a refusing caller guard returns before the callee observes its
frame, and that an allowing guard reaches the callee and returns the expected
value. An independently built always-allow mutation fails the refusing-guard
assertion at both levels. This verifies the test guard's branch behavior only;
the guard still does not inspect stack capacity or cover UBE-generated calls.

The installed Clang also supports [`-fstack-usage`](https://clang.llvm.org/docs/ClangCommandLineReference.html).
`verifier/check-stack-usage.ps1` compiles the same test source to LLVM IR and
then compiles that IR to a Windows object with the option. The command below
returned 0: its sidecar reported 8232 static bytes for `guarded_callee` and
40 for `guarded_caller`, and a control swapping their names was rejected.

```powershell
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/verifier/check-stack-usage.ps1 -Clang 'C:\Program Files\LLVM\bin\clang.exe' -OutputDirectory bootstrap/out/stack-usage
```

This identifies a possible source of target frame measurements for the exact
test object. It is not an upper bound for an entire call chain, runtime helpers,
exception handling or an optimized UBE program; it does not show how a guard
would know final frame sizes before those frames are entered. The format,
completeness, object association and behavior with dynamic frames, debug modes,
link-time optimization and the selected production toolchain remain to be
qualified before using the report for safety.
The same command now also compiles a separate test-only variable-length frame
through LLVM IR. Its report says `8 dynamic`, and a control that substitutes
`static` is rejected. The number alone is therefore not a bound on that
function's runtime frame. Dynamic arrays are outside the first UBE subset;
this is a tool-format counterexample that any future report consumer must
classify, not evidence that the first compiler will emit dynamic frames.
Separately, `check-guard-size.ps1` compiles an otherwise identical test function
through LLVM IR with and without a call to a guard. On this host the reported
static frame changed from 0 bytes to 40 bytes; an equal-size comparator control
was rejected. The following command returned 0:

```powershell
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/verifier/check-guard-size.ps1 -Clang 'C:\Program Files\LLVM\bin\clang.exe' -OutputDirectory bootstrap/out/guard-size
```

This one example shows why frame measurements from an uninstrumented object
cannot be assumed to bound a different instrumented object. It does not provide
a general way to derive or safely stabilize the final frame sizes.

### Own-frame reports and complete call footprint

The earlier linked-metadata experiments below used the raw static stack-usage
number. That number is not the complete call footprint for the measured target.
The test-only `stack-call-footprint.c` captures RSP after the same function's
prologue in two ordinary recursive activations. Post-call volatile work prevents
this particular call from becoming a tail call. Its harness compiles C to LLVM,
then the actual LLVM to an object with the selected O2 verifier options and
`-fstack-usage`. It independently sums the fixture's `ALLOC_SMALL`/`ALLOC_LARGE`
and `PUSH_NONVOL` unwind operations and compares that allocation with the static
report. Other unwind forms fail this narrow fixture checker rather than being
silently ignored. A separate metadata object supplies the expected call bytes
without recompiling the measured object.

This command returned 0 for both fixed local-array sizes, with and without
DWARF 4 debug information:

```powershell
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/verifier/check-stack-call-footprint.ps1 -Clang 'C:\Program Files\LLVM\bin\clang.exe' -Readobj 'C:\Program Files\LLVM\bin\llvm-readobj.exe' -OutputDirectory bootstrap/out/stack-call-footprint
```

| Local array | Static report and unwind allocation | Observed RSP difference between activations | Omitted-return control |
| --- | --- | --- | --- |
| 32 bytes | 88 bytes | 96 bytes | Supplying 88 returned 1; supplying 96 returned 0. |
| 8192 bytes | 8248 bytes | 8256 bytes | Supplying 8248 returned 1; supplying 8256 returned 0. |

All eight executions entered and unwound exactly two activations. The four
omitted-return controls were deliberately rejected. Debug and non-debug results
matched. Exact script/source/tool and measured-object hashes are in
`bootstrap/out/stack-call-footprint/23cc1fc388bf4d2187542ba0763ea70f/report.json`.
This establishes the extra eight bytes for these call shapes; it does not bound
stack-probe internals, other helpers, dynamic frames, tail calls or UBE output.
The unwind records and usage reports come from the same compiler; the separate
live RSP observation supplies the call-footprint comparison.

The two live linked-guard harnesses now supply own-frame size plus eight as the
call footprint and retain own-frame size separately in their output. Their
following reruns returned 0:

```powershell
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/verifier/check-stack-linked-guard.ps1 -Clang 'C:\Program Files\LLVM\bin\clang.exe' -Readobj 'C:\Program Files\LLVM\bin\llvm-readobj.exe' -OutputDirectory bootstrap/out/stack-call-footprint-linked
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/verifier/check-stack-committed-error.ps1 -Clang 'C:\Program Files\LLVM\bin\clang.exe' -Readobj 'C:\Program Files\LLVM\bin\llvm-readobj.exe' -OutputDirectory bootstrap/out/stack-call-footprint-errors -CompareRegions
```

The linked-guard test accepted and checked 8288 call bytes at O0 and 8272 at O2,
with matching Full/None results. Those runs unwound 23 frames. Its deliberately
understated metadata 1 was rejected by the object/image comparator but still
linked as an adverse runtime control, entering and unwinding 24 frames.
The committed-error test passed all 16 optimization/debug/control combinations:
normal Err 28 and neutral return checks, rejected wrong error/result controls,
and refusal of the 16 MiB metadata request before callee entry. Its partial
helper total now includes one return address per counted function and measured
880 bytes at O0 and 464 at O2 with region comparison. These partial sums do not
justify the experimental 64 KiB reserve or include all runtime/OS paths.

The historical measurements below remain observations of the earlier raw-frame
experiments. They must not be read as a complete per-call stack bound.

`verifier/check-stack-metadata.ps1` explores one possible way around that
measurement cycle. The test compiles an instrumented caller and callee from
LLVM IR to an object, reads the callee's static `-fstack-usage` entry, and links
that measured number from a separate test-owned data object without recompiling
the measured object. The following command returned 0 at O0 and O2. Both
reports gave 8248 bytes; the linked test accepted that number, rejected a
one-byte-wrong value, and confirmed the measured object's hash did not change.

```powershell
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/verifier/check-stack-metadata.ps1 -Clang 'C:\Program Files\LLVM\bin\clang.exe' -OutputDirectory bootstrap/out/stack-metadata
```

This shows only that the test can pass a measured number into already-generated
code when linking without LTO. The test guard compares the number with an
expectation; it does not measure stack or implement UBE's recursion policy. The
report-to-function association, every call and entry path, dynamic frames,
runtime/helper frames, failures, final-link transformations, integrity of the
linked data and stack-commit behavior still need qualification. It is a review
candidate, not a selected backend architecture or a production safety proof.

`verifier/check-stack-linked-guard.ps1` combines that linking technique with
the test-only frame-aware guard. It compiles the instrumented recursive object,
links either its reported size or the deliberately understated value 1, and
checks the object hash remains unchanged. The command below returned 0. With
reported sizes 8280 (O0) and 8264 (O2), the test unwound 23 frames. With the
incorrect value 1, the same test also returned success but entered 24 frames at
both optimization levels. The actual frames were only the controlled 8 KiB
test frames; this does not deliberately cause an overflow.

```powershell
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/verifier/check-stack-linked-guard.ps1 -Clang 'C:\Program Files\LLVM\bin\clang.exe' -Readobj 'C:\Program Files\LLVM\bin\llvm-readobj.exe' -OutputDirectory bootstrap/out/stack-guard
```

This adverse control shows that the runtime guard alone does not detect
understated metadata. Any proposal using linked frame sizes needs an independent
prepublication check binding each complete static report to the exact object,
function and linked metadata; deliberately reduce a size and require that
check to reject it. Even correct metadata does not resolve stack commitment,
runtime/helper frames or the remaining safety obligations above.

The same command now compiles the test metadata into a separate COFF object,
uses `llvm-readobj` to locate its one `required_frame` symbol and section, reads
the eight stored bytes independently, and compares them with the static size
reported for `descend`. The comparator accepted 8280 and 8264 and rejected 1
at O0 and O2; the harness deliberately linked both to retain the runtime adverse
control. The comparison and subsequent runtime observations passed. The script
was then extended to locate `required_frame` independently in each linked test
image and compare those bytes with both the metadata object and the frame report.
Rerunning the command accepted the correct object/image pairs and rejected the
understated pairs at both optimization levels; it deliberately ran all pairs to
retain the adverse runtime observation. This is a specific one-symbol host test,
not a general COFF parser or proof that the inspected image is later published.
It does not establish provenance of an arbitrary report, complete call coverage
or production publication safety.
The command now also repeats both metadata cases with and without Clang `-g` at
each optimization level, verifies a `.debug_info` section exists in each debug
image, and compares each debug run's output with its non-debug counterpart.
All eight cases passed on this host with the same respective 23- or 24-frame
observations. Section presence is not proof that debug locations are correct;
this C-derived test neither qualifies UBE debug information nor establishes
behavior for other generated programs.
`verifier/check-stack-debug.ps1` then inspected the linked O0 and O2 debug
images from that command with GNU objdump. It independently located the source
declaration of `descend`, checked its DWARF declaration line and matched its
DWARF low address to the linked `descend` symbol. Both images passed, and each
rejected a changed address and a changed line control. For example:

```powershell
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/verifier/check-stack-debug.ps1 -Objdump objdump -Executable bootstrap/out/stack-guard/linked-guard-2-True-False.exe
```

This adds one source/function/address association for a C-derived test. It does
not check statement ranges, local variables, every debug location or UBE output.

The host-only `verifier/stack-limits.c` calls Windows
[`GetCurrentThreadStackLimits`](https://learn.microsoft.com/en-us/windows/win32/api/processthreadsapi/nf-processthreadsapi-getcurrentthreadstacklimits)
on the main thread and a separate test thread requested with a 128 KiB stack
reservation. This command returned 0 after finding each local address within
its thread's reported limits and rejecting a wrong-bounds control:

```powershell
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/verifier/check-stack-limits.ps1 -Clang 'C:\Program Files\LLVM\bin\clang.exe' -OutputDirectory bootstrap/out/stack-limits
```

The API documents allocated thread-stack boundaries and requires Windows 8 or
later; it also notes execution can occur on a different stack. The two observed
addresses do not establish available writable stack, guard-page behavior, frame
sizes, an unwind reserve or safety of another thread or fiber. The separate
[`SetThreadStackGuarantee`](https://learn.microsoft.com/en-us/windows/win32/api/processthreadsapi/nf-processthreadsapi-setthreadstackguarantee)
concerns space during stack-overflow exception handling, not a pre-call proof
that a proposed frame fits. Neither API nor an exception-recovery strategy has
been selected for UBE.

The same worker now records bounds before and during a test function with a
48 KiB volatile local array. The comparator requires the deeper local address
to be at least 48 KiB below the earlier one, so an optimizer shrinking the
array cannot satisfy the test. Rerunning the command above returned 0 and
reported the worker's lower bound unchanged in this run. An initial version
using constant indexes was optimized to a much smaller frame; it was corrected
before this passing observation. The result is one stack-growth observation,
not proof that reported limits remain fixed or that the whole interval is
committed and writable.
The probe now also calls `VirtualQuery` on the worker's reported lower-bound
address. The command returned 0 and reported that page as reserved, not committed,
on this run. It is therefore incorrect to infer from these observed boundaries
alone that every byte down to the lower limit is presently writable. This result
is specific to the tested host, worker and moment. The project documents
dependency-minimal portability but the reviewed files do not establish a
minimum Windows release; requiring this Windows 8 API would need a supported-OS
decision or a qualified alternative, not a silent new compatibility promise.

The host-only `verifier/check-stack-commit.ps1` links the stack-limits test with
the selected local linker asked for a 262144-byte reserve and equal initial
commit. It verifies both PE header fields, rejects a wrong-header control, and
runs the executable. This command returned 0; `VirtualQuery` still reported
the page at the main thread's lower reported boundary as reserved on this run.

```powershell
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/verifier/check-stack-commit.ps1 -Clang 'C:\Program Files\LLVM\bin\clang.exe' -Readobj 'C:\Program Files\LLVM\bin\llvm-readobj.exe' -OutputDirectory bootstrap/out/stack-commit
```

This tests header settings and one queried boundary page, not every page in
the stack or behavior under allocation failure. It does not select a linker
flag, stack size, startup policy or safety reserve for UBE.
The probe now walks the reported main-thread interval using `VirtualQuery` and
accounts for reserved, committed, guard and other regions. The default-header
run observed 1019904 reserved, 16384 committed and 12288 guarded bytes; the
equal-256-KiB reserve/commit-header run observed 774144 reserved, 262144
committed and 12288 guarded bytes. Each observed interval totaled 1048576
bytes. Both commands above returned 0, including their wrong-value controls.
The region walk is not an atomic snapshot and these figures describe one run
on this host. In particular, the requested PE header values are not themselves
proof of the actual runtime interval or of safe behavior under memory pressure.

`verifier/check-stack-guard.ps1` exercises a test-only pre-call check using the
reported lower limit and a 64 KiB margin on a worker requested with a 256 KiB
stack reservation. The recursive function keeps an 8 KiB volatile frame live;
it verifies that successive frame addresses are separated by at least 8 KiB and
does work while unwinding. The following command returned 0. At O0 and O2 the
guard refused after 24 frames and all 24 unwound; an always-refuse control
stopped before the first frame at both settings.

```powershell
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/verifier/check-stack-guard.ps1 -Clang 'C:\Program Files\LLVM\bin\clang.exe' -OutputDirectory bootstrap/out/stack-guard
```

The 64 KiB margin is a test parameter, not a production limit or a proof of
available committed memory. The test does not establish behavior under memory
pressure, different frames, threads or fibers, asynchronous stack use, or a
UBE-generated unwind/error path. It does not select this guard for UBE.
The script was then expanded to compile 8, 16 and 32 KiB live-frame variants at
both optimization levels. Rerunning the same command returned 0: the guard
refused after 24, 12 and 6 frames respectively, all frames unwound, and each
always-refuse control stopped before entry. The observed address spacing was
checked in each case. These are three controlled equal-frame shapes, not proof
for arbitrary or mixed frames; in particular a callee frame larger than the
fixed margin would invalidate any assumption based only on that margin.
The same command now also runs mutually recursive test functions with 8 KiB
and 32 KiB frames. At O0 and O2 it observed five of each, a controlled refusal,
and ten unwinds; the always-refuse control entered neither function. It checks
successive local-address spacing against the preceding frame size. The first
attempt incorrectly compared that spacing to the newly entered frame size and
failed; the corrected comparator produced the observations above. This is one
mixed call pattern and still does not qualify the fixed margin for production.
The equal-frame probe now records a specific counterexample without entering an
unsafe large function: for every tested frame size and optimization, the guard
returned success at least once when the caller's frame address was less than
128 KiB above the reported lower boundary. A hypothetical next frame of 128 KiB
could not fit below that caller address within the reported interval, yet the
fixed 64 KiB guard allowed a call. The actual next calls remained the smaller
test frames and unwound normally. Rerunning the command above returned 0 with
all six counterexamples observed. This eliminates that fixed-margin-only scheme
for arbitrary frame sizes; the test does not run a stack-overflowing call or
establish a complete guard for other configurations.

A separate host-only `stack-guard-aware.c` compares the requested next-frame
size and a test reserve against the measured distance using subtraction after
range checks. It tests exact fit, one byte short and an overflowing-sized
request; then it permits small test frames while observing at least one refusal
for a hypothetical larger frame. This command returned 0 at O0 and O2: each
run unwound 23 actual 8 KiB frames, and a control that ignores the next-frame
size was rejected at both settings.

```powershell
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/verifier/check-stack-aware.ps1 -Clang 'C:\Program Files\LLVM\bin\clang.exe' -OutputDirectory bootstrap/out/stack-guard
```

This checks the arithmetic and one host execution, not a production stack-safety
solution. In particular it assumes a supplied next-frame size and a 64 KiB
reserve; it does not establish how to obtain sound final sizes before calls,
handle dynamic stack use, cover every entry point or guarantee memory commitment.
The same command now also tests a conservative variant that uses only the
`VirtualQuery` committed read/write region containing the guard's marker and
links with equal 256 KiB stack reserve/commit header fields. In the observed O0
and O2 runs, it safely refused before entering recursion: its marker had about
2.7–3.0 KiB below it in that region, less than the test's 64 KiB reserve. A
separate walk of the reported worker interval counted 262144 committed bytes
and 12288 guarded bytes. The guard measured only the queried suffix of that
region, not all committed space below the marker. The later page-walk experiment
below exposes this limitation. It does not prove a committed-space scheme is
generally safe or usable. The ordinary
reserved-bound variant and wrong-frame controls also passed when rerun.
The same command with `-CommitThread` requests the test thread's initial commit
rather than interpreting its size argument as a reservation. On this host, the
reserved-bound variant then unwound 118 frames at both optimization levels;
the committed-region variant still refused before recursion, with roughly
2.1–2.8 KiB below its marker in the queried region. The harness returned 0 for
both modes and rejected the wrong-frame controls. The first attempt had a 64-frame test cap and
failed before reaching the larger stack's guard; the cap was raised to 192 for
the reported run. These are controlled observations, not a selected thread
creation policy or proof that changing the request is safe in other contexts.

The harness also checks Clang's static stack-usage reports for the guard,
region observer, and worker. In the latest runs their reported frames were
136, 136, and 56 bytes at O0, and 120, 168, and 40 bytes at O2, respectively.
Both thread-size modes passed that check. These per-function figures exclude
called functions and do not establish a complete stack bound; they show that
the early refusal was not explained by a large frame in those three functions.

The trace subsequently showed why that control was excessively conservative:
`VirtualQuery` at the marker returned a base at the marker's own page, while a
walk from the lower stack limit reported a larger committed region ending at
the same top. Microsoft documents that the query rounds its supplied address
down to a page boundary and scans subsequent pages, so this result must not be
interpreted as the start of all preceding contiguous committed memory. See
[VirtualQuery](https://learn.microsoft.com/en-us/windows/win32/api/memoryapi/nf-memoryapi-virtualquery).

The test-only `COMMITTED_PAGE_WALK` variant checks pages downwards from the
marker, stopping before a non-writable, guarded, uncommitted or different
allocation page, with a 4096-page cap. On this host, at O0 and O2 for both
thread-size interpretations, it observed 64 committed pages, refused the
hypothetical larger frame, and entered and unwound 23 actual 8 KiB frames.
The missing-frame arithmetic controls were rejected. Command:

```powershell
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/verifier/check-stack-committed-walk.ps1 -Clang 'C:\Program Files\LLVM\bin\clang.exe' -OutputDirectory bootstrap/out/stack-committed-walk
```

This corrects the earlier interpretation, not the complete stack-safety problem.
The page observations are not atomic; the probe assumes its supplied frame and
reserve, uses Windows stack-limit APIs, and does not qualify all call paths,
memory-pressure or asynchronous exceptions. It does not implement a UBE guard.

The two committed-page experiments now use the same test-only page walker.
`check-stack-page-boundary.ps1` allocates eight ordinary test pages, sets one
to no access and another to read/write with `PAGE_GUARD`, and independently
checks their reported protection. At O0 and O2 the walker stopped above the
guard, refused a starting point on the guard, and, after its removal, stopped
above the no-access page. A version with the intermediate guard check disabled
failed the same assertions. The live recursion and error tests were rerun after
the shared-walker change and passed again. Command:

```powershell
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/verifier/check-stack-page-boundary.ps1 -Clang 'C:\Program Files\LLVM\bin\clang.exe' -OutputDirectory bootstrap/out/stack-page-boundary
```

The artificial pages are not a thread stack, and this tests only the specified
protection boundaries on one host. It does not prove the page state cannot change
after observation or establish the required recovery reserve.
The same test was extended to decommit a page, verify the walk stops above it
and rejects starting on it, and check an explicit lower bound and an invalid
bound. It also deliberately changes a previously counted page to no access
after the walk and verifies the new protection: the earlier observation can
become stale. The same command passed both optimization settings and rejected
the guard-omission controls. This sequential artificial-page control does not
establish how or whether another actor can change a real UBE stack page.

An independent review identified repeated page scanning as a work-bound risk.
`check-stack-page-work.ps1` runs the same walker repeatedly over an artificial
contiguous writable allocation. The 16- and 32-walk cases performed 136 and
528 `VirtualQuery` calls, respectively; this is the triangular count for the
tested sequence, not an elapsed-time measurement or a claim about every real
stack. A test-only forward scan using `VirtualQuery` region lengths made 16
and 32 calls on the same contiguous cases. Both O0 and O2 comparisons passed:

```powershell
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/verifier/check-stack-page-work.ps1 -Clang 'C:\Program Files\LLVM\bin\clang.exe' -OutputDirectory bootstrap/out/stack-page-work
```

The harness also alternates read/write and read-only pages in the artificial
allocation and checks 16 writable starting points. In that constructed case the
backward page walker made 31 queries, while the forward region scan made 256:
the latter repeatedly traversed earlier regions even though the immediately
preceding read-only page bounded the usable run. Both walkers returned the same
expected floor for every start. This is a counterexample to assuming the region
scan is always cheaper; it does not show that actual Windows thread stacks are
fragmented this way or predict their runtime cost.

The artificial boundary test also compared the page and region floor at its
guarded, no-access and decommitted boundaries, and rejected separate mutations
omitting the guard check in each walker. In the live error experiment,
`-CompareRegions` checked that both approaches found the same floor before
each call; all four debug/plain O0/O2 cases and eight wrong-error/result
controls passed. The output included selected helper-frame sums of 832 bytes
at O0 and 440 at O2; as above, these exclude other call paths and external
functions. Command:

```powershell
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/verifier/check-stack-committed-error.ps1 -Clang 'C:\Program Files\LLVM\bin\clang.exe' -Readobj 'C:\Program Files\LLVM\bin\llvm-readobj.exe' -OutputDirectory bootstrap/out/stack-region-compare -CompareRegions
```

The region scan is a test candidate, not a selected implementation: a highly
fragmented range can still require many region queries, the scan has a 4096
region cap, the observations can become stale, and neither these tests nor the
static frame sums prove a safe reserve or bound all runtime call paths.

`check-stack-committed-error.ps1` combines the downward committed-page check
with the test-only live error observer. For each O0/O2 and debug/plain build,
it compiles the guarded recursive function, reads its static stack-usage
report, places that value in a separately compiled object, and compares the
value in both that object and the linked executable with the report. The
measured recursive object is hashed before and after linking. The four good
runs checked argument counts, refusal, neutral return, complete unwind, the
bootstrap thread-local Err value 28, retention through a successful checked
addition, and isolation from the main thread's Err. Eight wrong-error or
wrong-result variants returned the expected failure. The observed reported
frames were 8280 bytes at O0 and 8264 bytes at O2. Command:

```powershell
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/verifier/check-stack-committed-error.ps1 -Clang 'C:\Program Files\LLVM\bin\clang.exe' -Readobj 'C:\Program Files\LLVM\bin\llvm-readobj.exe' -OutputDirectory bootstrap/out/stack-committed-error
```

The harness now also compiles and hashes the exact bootstrap runtime object it
links, checks static reports for the guard and error-setter functions, and
adds the reported helper frames (including the page walker and text copier
when separately reported). On the passing rerun that selected sum was 584
bytes at O0 and 440 bytes at O2, below the experimental 64 KiB reserve. It is
not a complete call-chain bound: compiler inlining changes which frames are
listed, and Windows APIs, C library calls and other possible paths are not
measured by this sum. The corresponding run used the command above with
`-OutputDirectory bootstrap/out/stack-committed-error-accounting`.

The combined harness now includes an overlarge-frame control suggested by the
independent review. It links a separately compiled 16777216-byte frame value
while retaining the ordinary call guard. Its test-only worker expects the first
call to be refused after one argument evaluation, with no callee entry, neutral
result and Err 28; the main thread's independent Err remains unchanged. The
harness verifies the deliberately different value in the metadata object and
linked image. All four O0/O2 debug/plain controls passed alongside the correct
metadata and wrong-error/result cases using the command above with
`-OutputDirectory bootstrap/out/stack-oversized-control -CompareRegions`.
The control changes the worker's expected outcome as well as the metadata, and
is evidence for these compiled test cases rather than a general proof that all
generated guards consume the correct metadata.

This is C test code using the bootstrap error store, not generated UBE. The
64 KiB reserve is an experimental assumption, and these checks do not bound
all guard/helper frames, asynchronous changes, dynamic stack use or all call
paths. The object and image data comparisons do not prove a general linkage
scheme. The owner has confirmed the recoverable Err 28 refusal behavior; the guard remains unqualified.

An independent review found that an unreliable query does not establish enough
reserve to set Err. The test-only live probe now distinguishes that condition
from a successful low-space observation. With an injected failed query, the
test harness observes a sentinel, no callee entry and unchanged clear or seeded
Err; it does not claim that this sentinel is the production failure behavior.
At O0 and O2 the following command returned 0, and the normal combined
committed-page/error matrix was rerun successfully afterward:

```powershell
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/verifier/check-stack-query-failure.ps1 -Clang 'C:\Program Files\LLVM\bin\clang.exe' -OutputDirectory bootstrap/out/stack-query-failure
```

The failure is injected at the test guard's query boundary, not an actual OS
failure. This test does not implement or qualify the separately proposed
unrecoverable path, and does not establish a safe reserve in that condition.

The additional admission script, including `subtraction-extrema`, passed 60
checks per compiler at jobs 1 and 4 with both `stage1/ube.exe` and
`stage2/ube.exe` from `bootstrap/out/semantic-cli/e5b3d482d7fd46539e190ea70d20ecef`:
`rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/additional/check-admission.ps1 -Compiler <stage>/ube.exe`.
This establishes frontend admission only; the native result and independent
error observations remain unexecuted.

With `reference-initializer-error` included, the additional frontend admission
script passed 70 checks per source-built stage at jobs 1 and 4. This does not
execute either initializer, verify dependency order or observe Err.

As a host-only check of the expected referenced-library error case,
`verifier/check-initializer-error.ps1` links separate hand-written LLVM library
and executable initializer functions to the bootstrap checked arithmetic and
error store. At O0 and O2, library-first initialization observed result 8 and
Err 11; the root-first control observed result 1 and Err 11. A wrong expected
result failed at both levels. Command:
`rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/verifier/check-initializer-error.ps1 -Clang "C:\Program Files\LLVM\bin\clang.exe" -OutputDirectory bootstrap/out/initializer-error-probe`.
This is a hand-authored host model and observer, not execution of the UBE
project or proof of its future initialization order.

With `initializer-self` added, the same additional admission script passed 66
checks per stage at jobs 1 and 4. This is frontend admission only; the native
result, storage behavior, error observation and controls have not been run.

After adding the two error-replacement projects, the same admission script
passed 64 checks for each of those two compiler stages, again at jobs 1 and 4.
The result does not execute either project or observe Err.

Include a negative observer control for each result: change the expected Main
value, expected clear/nonzero/preserved state, or thread identity and require
the comparator to fail. Use at least one worker-count pair and both qualified
source-built compiler stages for each applicable actual native program; report
raw LLVM, tool and executable identities, exact process result and observer
output. Thread-specific tests may use a test adapter only where the bounded UBE
subset cannot express a thread; they must still execute the generated operation
and real runtime error store on the measured thread. These tests do not authorize
new public error APIs, error numbers, thread syntax or runtime architecture.

`additional/initializer-error/InitializerError.UBE` supplies the recoverable
initializer case: expect Main 67, failed value 0, later value 7 and nonzero Err
observed on the same thread after Main. The Main result alone cannot prove Err.
The local `bootstrap/out/v3/ube.exe --check` command accepted this manifest at
jobs 1 and 4, both exit 0 with no output. This establishes frontend admission
only; no native executable or Err observer was run for this fixture.

`additional/error-order/ErrorOrder.UBE` tests left-to-right evaluation through
a recoverable failure. `Mark(1)` runs before division by runtime zero; that
division yields zero and records Err; `Mark(2)` then runs and the addition
yields 2. Expect trace 12, Main 68 and nonzero same-thread Err after Main.
Exit 99 detects incorrect trace or value but does not observe Err. The local
checker accepted the fixture at jobs 1 and 4, both exit 0 with no output; the
native and independent Err observations remain unexecuted. A negative control
that swaps evaluation order must be rejected by the result oracle.

The additional admission script accepted `multiply-overflow/MultiplyOverflow.UBE`
at jobs 1 and 4 on both stage-built CLIs from cohort
`bootstrap/out/semantic-cli/e5b3d482d7fd46539e190ea70d20ecef`. Each command
`rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/additional/check-admission.ps1 -Compiler bootstrap/out/semantic-cli/e5b3d482d7fd46539e190ea70d20ecef/stage1/ube.exe`
and its `stage2/ube.exe` counterpart passed 48 checks. This establishes source
admission only, not the proposed result, error state or generated native code.

After adding `division-overflow/DivisionOverflow.UBE`, rerunning the same two
stage-specific additional-admission commands passed 50 checks per stage,
including jobs 1 and 4 for the new project. Its signed-division result and Err
remain future native observations; frontend admission cannot establish them.

After adding the remainder-minimum project, the additional admission script
passed 52 checks on each stage-built CLI at jobs 1 and 4. This does not decide
the runtime error-state behavior or establish any native behavior.
Adding `negate-minimum/NegateMinimum.UBE` brought the same admission run to
54 passing checks per stage, including jobs 1 and 4 for the new project. Its
native result and Err observation remain untested.
After the owner extended the rule to all signed integer sizes, the two additional
Integer and LongLong remainder-minimum projects were added. The same admission
script passed 58 checks per stage, including jobs 1 and 4 for each new project.
Their native values and clear/preseeded Err observations remain untested.

`additional/argument-error/ArgumentError.UBE` expects trace 12, result 20,
Main 72 and nonzero same-thread Err. The first written named argument runs
`Mark(1)`, then its division returns neutral zero; the second runs `Mark(2)`;
association passes 2 as `first` and 0 as `second`. The local admission script
accepted it at jobs 1 and 4. Native value, Err and deliberately wrong-order
controls remain unexecuted, and exit 99 cannot independently prove Err.

`additional/longlong-overflow/LongLongOverflow.UBE` expects Main 78 and nonzero
same-thread Err: adding one to LongLong maximum returns neutral zero, then a
successful addition produces 7 without clearing the error. Exit 99 indicates
a wrong value but cannot independently establish Err. The additional frontend
admission script accepted it at jobs 1 and 4; native behavior, Err and the
negative observer controls remain unexecuted.
