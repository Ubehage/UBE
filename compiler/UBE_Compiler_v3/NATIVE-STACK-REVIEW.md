# Native call-stack safety: design and qualification

The first executable must handle recursive calls without an uncontrolled stack
overflow. The recoverable behavior below is owner-confirmed. The cached-floor
design and its reserve-derivation rule below are selected for this bounded
target, subject to the stated host and machine-code qualification. They are
not evidence that the compiler implements them or that any host is qualified.

## Observable behavior

When a qualified check can refuse a call while recovery is still safe, the
owner-confirmed behavior is to finish the language-defined argument
evaluation, skip the callee, return its neutral result where applicable, and
set the current thread's Err to 28. A successful later operation preserves
that error. [Visual Basic uses error 28 for out of stack space](https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/out-of-stack-space-error-28).
If the runtime cannot safely perform that recovery, it needs a separately
specified controlled noninteractive failure path; a native stack-overflow
exception, corruption or a modal dialog does not satisfy the contract.

For a failed startup scan, insufficient initial interval, or later condition
where recovery cannot be established, the selected disposition stops before
any further user code and exits the executable with status 1. It attempts a
fixed stderr message only when the selected reporting operation is established
to be bounded; if that cannot be established, the message is omitted. No
acknowledgement or modal interaction is used. An ordinary `Main` may also
return 1, so the status alone does not identify the cause. This disposition is
not triggered merely because no error handler is active.

The fatal path performs no generic stderr write and starts no diagnostic worker.
It requests termination of the current process with status 1 through
`TerminateProcess`; if that call returns failure, it uses `ExitProcess(1)` as
the last fallback and never resumes user code. Before the startup invariant is
established, the adapter instead returns status 1 through its ordinary entry
boundary without entering an initializer or Main. A diagnostic is attempted only
through an independently prequalified nonblocking capability; otherwise it is
omitted. The initial scalar target admits no source I/O or source-created
threads. Implementation acceptance inventories the retained startup and runtime
closure and checks for pending operations and unsafe extra calls.

The design makes no universal real-time operating-system termination promise.
Microsoft documents that `TerminateProcess` may wait for pending I/O, and the
controlled synchronous stderr probe blocked on a full pipe. Neither the OS call
alone nor the prestarted-writer experiment proves bounded termination for an
arbitrary host. Qualification must exercise the selected closure and report
its limits; an actual native stack-overflow exception is not automatically safe.

The proposed call outcome is separate from whether a particular guard works.
`tests/native-executable/additional/stack-call-effects` supplies independent
normal and refusal expectations; the future acceptance test must observe Err
on the same thread and confirm the guard seam was actually reached.

## What a candidate guard must establish

### Selected design: startup-established committed floor

Use the following design rather than a guessed fixed reserve around repeated OS
queries on a nearly exhausted stack:

1. At the first process-adapter entry, before dependency/module initialization
   or Main, establish the actual contiguous committed writable interval below
   the adapter's stack pointer. Cache its lower boundary in native TLS only
   after the complete query succeeds. Reserved/guarded/inaccessible pages do
   not count. A requested PE stack size is not evidence of this interval.
2. During admitted UBE execution, use the cached boundary and the actual
   post-argument stack pointer. Do not query `VirtualQuery`/`GetSystemInfo` on
   every call or count possible later guard-page growth. Preserve the boundary
   across ordinary calls, initializers, refusal and unwind. This first target
   excludes source threads, foreign entries and stack switching; each future
   such entry needs its own establishment and qualification.
3. Require the generated program/support not to decommit, reprotect, replace or
   switch this native stack. Qualification must establish the corresponding
   supported-host invariant; a query snapshot alone cannot prove continued
   writability. External modification of process memory is not an admitted
   source-language operation. Do not disguise an unproven invariant as a
   measured recovery reserve.
4. Guard every generated call, including initialization and first Main entry,
   after its specified argument effects but before the callee prologue. Use
   the complete fixed-frame footprint and checked subtraction described below.
   Bind frame data to the actual objects, then link separately generated data
   without recompiling those objects or enabling LTO. Unknown/dynamic frame
   usage cannot become an assumed zero. A circular initializer must enter its
   defined wait, not recursively re-enter until stack exhaustion.
5. Use the closed error-recording paths required by `NATIVE-RUNTIME-CONTRACT.md`.
   The current general setter calls `strlen`/`memcpy`; its own stack report is
   insufficient. Derive R from the maximum simultaneous machine-code footprint
   of all unguarded guard/error/neutral-return paths, including return addresses,
   spills, outgoing/shadow areas and prologue transients. Reject unexpected
   calls/relocations and verify both debug settings. This is a derivation rule,
   not adoption of the experimental 64-KiB margin.

This design removes repeated page queries from the hot guard and makes its
recovery closure inspectable. Its selection does not qualify the initial
adapter/query, the lifetime of the cached interval, metadata/entry accounting,
or the bounded termination path. Those are host and implementation gates. In
particular, termination and diagnostic I/O cannot be assumed stack-safe simply
because the hot guard is.

The independent controls for this design belong in `ERROR-ORACLES.md`:
observe exactly one successful startup scan and no page queries during recursive
calls; compare the cached floor with fresh queries at startup, deep execution
and after unwind; inject startup query/insufficient-interval failure and prove
no initializer/Main entered; compare Full/None behavior and reject understated
frame metadata or an extra helper call. A test that deliberately changes page
protection must expose the cache assumption, not be counted as ordinary safe
execution. Keep the failure/termination checks separate from successful refusal.

### Required properties

- Cover all admitted entries and call paths that may consume stack, including
  argument evaluation, initialization and any runtime/helper calls required to
  perform the check and report or unwind a failure. A check in the callee body
  can be too late: the host probe observed the callee's stack probe first.
- Account for the actual next frame and a justified reserve, rather than only
  call count or a fixed margin. A host test showed that its fixed-margin guard
  could approve a call even though a hypothetical larger frame would not fit.
- Establish what the host's reported stack limits mean. One host test saw the
  page at the reported lower bound as reserved rather than committed. Bounds
  alone do not guarantee that further pages can be committed under memory
  pressure. A later test walked backwards over committed writable pages and
  unwound 23 frames on this host; the earlier one-query guard had counted only
  the page suffix returned by `VirtualQuery`. This is a candidate observation,
  not a qualified guard. A follow-up C test combined page checking, a measured
  linked frame and the bootstrap Err observer in debug/plain builds; its limits
  and controls are recorded in `tests/native-executable/ERROR-ORACLES.md`.
  The simple per-page scan repeatedly rescans memory; an alternative region
  scan reduces queries in a contiguous synthetic case but remains unqualified
  for fragmented memory and production use.
  Do not silently make a new minimum-Windows-version promise.
- Bind frame measurements to the exact code and linked metadata if measurements
  are used. Guard insertion changed one test frame from 0 to 40 bytes; a separate
  data-object experiment avoided recompilation but also showed that understated
  metadata made its guard enter an extra frame. Dynamic stack-use reports cannot
  be treated as a static upper bound.
- Distinguish a function's own allocation from the complete call footprint.
  The current Clang x86-64 static report excludes the return address in the
  measured fixtures. A direct call used eight more bytes than the reported
  allocation. The experimental linked guards now add those eight bytes; a
  separate stack-pointer observer rejects the omitted-return-address control.
  Unwind allocation matching is a cross-check of the own-frame size, not proof
  that the report includes every transient helper or dynamic allocation.
- Keep behavior and observations correct with the selected optimization and
  both supported debug settings. The existing C-derived tests are not evidence
  of fresh-v3 code, correct UBE debug locations or a complete call graph.
  Tail-call optimization can eliminate the frame a source-level call would
  otherwise consume; test that case separately and do not infer a fixed
  recursion boundary from the number of source-level calls.

## Accounting terms for a pre-call guard

Use the actual caller stack pointer at a specified machine-code point, after
argument evaluation and any already-allocated outgoing area. A local variable's
address is not automatically that pointer. If a helper supplies the observation,
account for the relationship between its pointer and the caller's pointer after
the helper returns. Specify that relationship for the generated code; do not
infer it from source variable order.

For a fixed-frame ordinary x86-64 call, the footprint below that caller pointer
includes the eight-byte return address plus the callee's complete own frame.
Account separately for any additional call-site stack adjustment, realignment
or temporary use before reaching the callee body. The caller's already-reserved
shadow space must not be omitted from its frame or charged again as a new callee
allocation. [Microsoft's stack layout](https://learn.microsoft.com/en-us/cpp/build/stack-usage)
describes the caller parameter area and return address. The focused local
measurement is recorded in `tests/native-executable/ERROR-ORACLES.md`.

Let `A` be the established available committed writable bytes below the guard's
specified caller pointer, `C` the next call's complete peak entry footprint,
and `R` the reserve derived below. The admissibility
test is `C <= A` and `R <= A - C`, using checked unsigned quantities. This
subtraction form avoids overflow in `C + R`. It is a requirement on the
accounting, not a fixed numeric value for `R` or proof that a page-query snapshot
remains valid. Reaching the guard itself must already be safe under the
caller's invariant; the guard cannot retroactively reserve its own entry stack.

Derive `R` separately for each qualified optimized/debug configuration from
the maximum simultaneous footprint of the exact linked unguarded closure:
guard entry and check, the bounded general and stack-specific Err recording
paths, neutral-result handling, and refusal/return continuations. Account for
each live frame, return address, stack adjustment, alignment, already-reserved
outgoing area and transient prologue/helper peak at the machine-code points
where they coexist. Take the maximum over reachable paths; do not add unrelated
per-function maxima and call the sum an observed peak. The hot closure must not
invoke OS or C-library functions whose usage is unbounded by this analysis.
Derive its data from the retained non-LTO objects and separately linked metadata,
then compare the actual linked symbols and bytes. Unclassified or dynamic stack
usage is not zero: reject the candidate with UBE1506 and the selected candidate path
before publication if a complete bound cannot be established. This does not
defer an admitted source construct merely because a guessed analysis failed.

Establish the invariant at process-adapter entry before the first initializer:
the adapter must itself safely reach and complete the query using its actual
startup support closure, and the resulting committed interval must cover its
own live frames plus the derived reserve and the first call's footprint. A
successful PE header check alone is not evidence of that condition. Query
failure or an insufficient interval follows the separate startup failure
disposition above, not a fabricated recoverable Err 28. The cached floor and
reserve are per native thread; no admitted operation may mutate the checked
stack region or switch stacks while using the cached value. If the platform
cannot establish this invariant, the selected design is not qualified there.

The current probes establish a corrected own-frame/call-footprint distinction
and several refusal observations. They do not establish the derived `R`, all
entry paths, initial committed space, or a safe termination path. These remain
qualification requirements for the selected design, not measured guarantees.

## Qualification before use

Document the host and thread configurations, frame-size and reserve derivation,
guard placement, how the checked code and metadata remain associated through
linking, and the recoverable and unrecoverable paths. The implementation must
account for failure to obtain reliable limits or commit memory. Run the independent
recursion, argument-effects, error-state and fault controls in
`tests/native-executable/ERROR-ORACLES.md` against actual generated programs.
The host probes there are useful counterexamples and candidate evidence, not a
qualification of the selected design or any generated stack guard.

An unreliable stack-limit or page query is not the same observation as a
successful check that finds insufficient space: it does not establish the
reserve needed even to set Err. The test-only live probe now returns a distinct
sentinel to its harness for an injected query failure, without setting Err 28
or entering the callee. That sentinel is test instrumentation, not the specified
production fatal path. The selected path still requires qualification under its
stated no-pending-operation and host assumptions.
