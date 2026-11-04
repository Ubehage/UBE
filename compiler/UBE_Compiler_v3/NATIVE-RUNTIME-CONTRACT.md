# Native scalar runtime support and observation

This selects the private error-state boundary and its test observer for the
First checked native executable contract. It does not add language syntax, a
public Err API, an installed runtime or an implemented backend. Stack admission
and its recovery reserve are reviewed separately in `NATIVE-STACK-REVIEW.md`.

## Selected support ownership

Keep arithmetic/control/evaluation policy in the compiler and ordinary library
algorithms in UBECore. The only error-state substrate needed by this subset is
native thread-local storage and bounded recording/observation of that state.
Use the semantics of the existing `bootstrap/runtime/bootstrap_runtime.c`
helpers, with the following private C ABI on the selected Windows target:

| Symbol | Contract |
| --- | --- |
| `ube_err_set(int32_t number, const char *description, const char *source)` | Update this thread's number and fixed text fields, increment the unsigned revision and skip zero on wrap; no heap allocation |
| `ube_err_number(void) -> int32_t` | Read this thread's number without changing state |
| `ube_err_clear(void)` | Explicitly clear the record while advancing its nonzero revision; never called implicitly after successful program operations |
| `ube_err_set_stack_exhausted(void)` | Specialized recording of Err 28 in the same record; fixed text, no allocation, no external/helper calls in the qualified machine-code path |

The last helper is part of the shared-support implementation dependency; its
focused implementation evidence is in `ERROR-SUPPORT-EVIDENCE.md`.
It must record the same number/revision/text state as the general setter with
28, `out of stack space`, and `UBE.Runtime`. Its purpose is a bounded recovery
path, not a second error store. Derive its actual stack footprint from the
compiled and linked code; the ordinary setter's allocation-free property does
not establish a bound for its `strlen`/`memcpy` callees.

Preserve the existing fixed record: signed 32-bit number, unsigned 64-bit
revision, 512-byte description and 256-byte source buffers, with native target
alignment and initial zero state per thread. This layout is private substrate
state, not a foreign or source-language ABI. General-setter callers in this
subset provide null or trusted NUL-terminated constant UTF-8 text. Do not pass
unbounded user buffers: the pre-extraction setter bounded the destination copy
but used `strlen` on the complete input. Generated text must fit the buffers,
including its terminator. A successful operation preserves the complete existing error information and
calls neither setter nor clear. Recording a new error replaces all visible error
fields; omitted description or source text becomes empty rather than retaining
older text. Err.Clear and the language-defined Resume behavior clear the recorded
information; changing On Error mode or returning from a procedure does not.
Public Err/trapping/Resume syntax remains outside this bounded native subset. Lowering still owns the neutral result and required argument effects.
The extracted general setter must also have a closed, bounded low-stack path:
replace its CRT-dependent text copying within the shared implementation with
bounded recording that preserves these fields, and reject generated external
calls in that path. Otherwise ordinary arithmetic failure could exhaust the
reserve even though the specialized Err 28 path fits. This is an implementation
requirement; the extracted implementation's bounded path is checked separately
from future generated-program integration.

The selected implementation dependency is a focused extraction into one shared
error-state source unit under `bootstrap/runtime/`, used both by the existing
bootstrap runtime and the bounded native output. Move the state/helpers rather
than copying a second implementation. The native output links that unit and
its required platform/CRT closure, not the entire bootstrap runtime. Do not
attach library exports, GC, FLS/event/monitor state or managed-string accessors
to this unit. Actual source/object hashes, private declarations and retained
symbol/import inventory must be recorded when it is implemented. The extracted
`bootstrap/runtime/error_support.c` now exists; focused host qualification and
remaining integration obligations are recorded in `ERROR-SUPPORT-EVIDENCE.md`.

This remains a bounded bootstrap exception within the existing linked-substrate
architecture, not a new runtime subsystem. Its removal condition is replacement
by UBE/compiler-emitted native TLS/error support after the same state, isolation,
allocation-failure, copying and stack-accounting gates pass. Preserve existing
bootstrap callers and rerun their applicable native-TLS/error gates when moving
the common implementation. No source algorithm is moved from UBE into C.

Compile this temporary support with the selected Clang Windows target and
native TLS. Reject an emulated-TLS allocation path; GCC's emulated TLS is not a
substitute. Link only the required support objects. Function/data sections and
dead-section removal are useful implementation tools but not proof that the
retained dependency set is minimal. Explicitly inventory it before publication
qualification; compiler-generated checked integer operations need not call the
bootstrap C arithmetic routines.

## Selected test observer

The test build substitutes only the platform process adapter. It invokes the
same runtime setup, dependency/module initialization and generated language Main
on that same native thread. It reads `ube_err_number` immediately after Main
returns, before cleanup, formatting or other work can change state. For Sub Main,
record result zero; for Function Main, record its full signed 32-bit result.
The ordinary executable remains the independent process-exit/value control.

Write the observation to a test-owned channel distinct from program stdout:
exact ASCII `result<TAB><signed-decimal><TAB>err<TAB><signed-decimal><LF>`.
The adapter's process status is zero only when the test transport completed;
it is not the program's Main result. The harness separately compares the tuple
and the ordinary executable's full Windows exit value. Missing, duplicate,
malformed, truncated or extra records fail the observation. Do not expose this
transport or observer entry through normal UBE source or the public build CLI.

The harness may explicitly seed or clear Err before running the ordinary
startup sequence. Startup itself must not silently clear that seeded state.
Verify that the actual helpers set/read/clear and preserve independent state
on two native test threads in both orders and with overlapping execution.
These native test threads do not claim source-language threading support.
Reject a comparator that reads another thread's state and a bridge whose error
setter uses the wrong number.

For intermediate operation or call observations, insert a test-only checkpoint
immediately afterward on the same thread, capturing the result and error before
later program work. Buffer its scalar observation before formatting. It must
not set an error on behalf of the operation, skip arguments, enter a refused
callee, change module initialization or move the checkpoint past another error.
Compare ordinary and observed generated operations/control flow independently;
observer stack consumption must be included when exercising a real stack guard.
Use the existing confirmed guard seam for the separate argument-effects oracle.
Checkpoint mode is a separate test invocation with exactly one selected static
checkpoint and one expected execution. It emits only
`checkpoint<TAB><case-id><TAB><type><TAB><value><TAB>err<TAB><signed-decimal><LF>`,
not the final-Main record. The hand-authored case fixes the ASCII case-id,
resolved source span/type and expected observation. Type is `Byte`, `Integer`,
`Long`, `LongLong`, `Boolean`, `Void`, or `Native:<canonical-declaration-id>`.
Integer and native-representation values use full-width decimal with no leading
plus/zeros, Boolean uses `True`/`False`, and Void uses `-`. Err is signed decimal.
A repeated or missing checkpoint fails rather than silently choosing the last
iteration. Continue the program normally after capturing the scalar observation;
format only after it returns. The ordinary run independently checks Main's exit.
No public On Error/Err syntax or permanent program instrumentation is added.

## Existing evidence and remaining acceptance

The existing thread-local error helpers and hand-authored LLVM bridge have
host evidence in `tests/native-executable/ERROR-ORACLES.md`. A focused explicit
support-link audit also demonstrates that section GC of the unmodified whole
runtime retains unrelated exported support. Thus that recipe is rejected as
the minimal-support implementation; it is not accepted merely because values
and Err observations pass. Exact command and retained results are recorded in
the error oracle.

After the common error unit exists, require an error-only retained-symbol
inventory (plus the separately enumerated platform/CRT closure), no unexpected
exports or emulated TLS, and both Full/None builds. Independently compare all
record fields/revision for the specialized Err 28 setter against the general
setter, including wrap, clear/preseeded state and thread isolation. Inspect
machine code and relocations to reject any introduced helper call in its
bounded path. The future native builder must then pass the actual source
program error, startup, call-effects and negative controls from
`tests/native-executable/ERROR-ORACLES.md`. Host bridge execution does not
qualify generated UBE operations or their observer integration.
