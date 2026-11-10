# UBE error-handling contract review

**Status:** core decisions approved; remaining boundary details under review.
**Owner request:** 2026-11-10, define error behavior throughout the project
before rebuilding the compiler and UBECore.

This review separates existing requirements from proposed clarifications.
Choices awaiting an owner answer must not be implemented as settled semantics.
The approved core is now normative in `../lang-doc/error-handling.md`.
The language, conversion, managed-memory, threading and foreign-ABI documents
have been reconciled with the approved core below. Public-manual reconciliation
is tracked separately. No executable conformance is claimed by this document.

## Reconciliation audit — 2026-11-10

- Conversion, checked arithmetic, array access and Variant extraction failures
  report FAIL rather than supplying zero, Nothing or another neutral value.
  In particular, an unsuccessful assignment does not overwrite its destination.
- Neutral initialization, successful Empty conversion, fixed-string padding,
  ordinary timeout/cancellation and legitimate zero/False results are retained.
- CallNew and ordinary public thread/synchronization API errors report FAIL;
  successful timeout/cancellation statuses remain distinct from failure.
- Explicit bootstrap TryResize/TryCopy/CopyBytes and Error.Set contracts retain
  their record-only Boolean status. Their status is not inferred from Err and
  is not silently promoted to language FAIL. Public wrapper behavior must be
  specified independently.
- Safely reportable stack exhaustion refuses the next call with Err 28/FAIL;
  text promising general native unwinding was removed. Compiler-owned lifetime
  cleanup and explicit user-resource cleanup remain distinct obligations.
- Foreign status wrappers must consume a fresh outward outcome, not stale Err.

The following are still decisions, not accidental implementation defaults:

1. Default resume targets for failures in compound control headers such as If,
   For, Select Case and SyncLock. A failed Boolean conversion is not False.
2. Exact return/diagnostic behavior for worker entry, event dispatch, raw native
   callbacks, UI-thread routing and module startup/finalization boundaries.
3. Complete Err signatures/codes, Error statement equivalence, and any new
   Try-style APIs beyond the explicitly documented record-only primitives.

Documentation review does not establish runtime conformance. The parent work
item supplies the first executable acceptance gate.

## Existing baseline

The current authorities are `../lang-doc/language-spec.md` section 9,
`../lang-doc/conversion-table.md`, `../lang-doc/managed-memory.md`,
`../lang-doc/threading.md`, `../lang-doc/foreign-abi.md`, and `../IDE/DESIGN.md`.

- Provably invalid conversions and arithmetic receive compile-time diagnostics.
- Recoverable language failures record thread-local Err and report FAIL without
  a usable value. Default continuation skips the failed statement. Absence of a
  handler is not permission to terminate or show UI.
- Err.Raise immediately exits the raising procedure; the caller handles FAIL.
  The raising procedure must perform its explicit resource cleanup beforehand.
- Successful operations preserve Err. A new failure replaces the entire record.
  Err.Clear and valid Resume clear it; procedure return and handler-mode changes
  do not.
- On Error GoTo selects a procedure-local handler. On Error Resume Next skips
  the failed statement. Resume statements leave a handler and clear Err.
- Allocation failure collects and retries once. Unrecoverable inability to
  preserve memory safety follows a bounded, noninteractive fatal path.
- Cancellation and timeout are not errors unless an individual operation
  encounters a separate failure.
- Files and other external resources require explicit user cleanup. Managed
  memory and compiler-owned temporaries follow their defined lifetimes.
- No exception or unwinding state crosses a foreign ABI boundary.
- Compiler or debuggee failure must not destroy the IDE's unsaved documents.

## Distinguish the four outcomes

| Outcome | Meaning | Existing requirement / proposed clarification |
|---|---|---|
| Success | The operation produced its defined result, including an ordinary zero/False | Preserve previous Err. |
| Normal non-success | Timeout, cancellation, end of enumeration, or a documented no-match | Use an explicit documented status; do not infer an error from zero. |
| Recoverable failure | The operation cannot fulfill its contract but execution remains safe | Publish a new Err and use the selected language control-flow rule. |
| Fatal failure | Safe continuation or safe error reporting is impossible | Bounded diagnostic where possible, minimal safe cleanup, controlled termination of the affected process. |

Approved distinction: a fresh operation status and the sticky Err record
are separate things. Never implement `operation failed` as `Err.Number <> 0`
after an arbitrary call. An earlier error can remain after many successes;
two successive failures can have identical error numbers; user code can clear
Err while handling a failure. Neither number comparison nor a before/after
snapshot is a substitute for a fresh outcome.

This separation applies equally to generated code, UBECore, foreign wrappers,
startup, finalizers, worker completion and compiler tools. It does not require
exposing a new public result type or changing ordinary UBE call syntax.

## Owner-approved decisions

### Default continuation inside an expression

For runtime input that cannot convert to Long:

```vb
Result = CLng(InputText) + 10
```

- Approved: abandon the statement, leaving Result unchanged. No zero is
  substituted and the addition is not performed. This supersedes the earlier
  neutral-result continuation wording.

The rule must also cover receiver evaluation, array indices, argument
conversion, assignments, loop conditions and short-circuit expressions. An
invalid storage location must never become a write through a fabricated address.

### Caller handlers

Err.Raise records the error and exits its containing procedure immediately,
returning FAIL. Its caller branches to an enabled On Error GoTo handler or
skips the failed call statement by default. Earlier side effects remain;
unfinished assignments do not commit. A caller that continues after a failed
statement does not itself automatically return FAIL. Local errors within an
already active handler now skip the failed statement and continue within that
handler without re-entry or automatic propagation. Special boundaries still
need detailed rules.

User-owned resource cleanup must happen before Err.Raise. No application
cleanup code after it runs. Compiler-owned stack, root and temporary lifetimes
still end safely under the existing lifetime contracts.

Do not implement caller behavior merely by testing Err at procedure return.

## Remaining decisions to settle with concrete examples

| Case | Proposed rule for review |
|---|---|
| Failure in a statement under Resume Next | Abandon the rest of that statement; preserve effects already completed; continue at its next executable statement. |
| Scalar assignment | Approved: store only after successful RHS evaluation and conversion; FAIL skips the commit. |
| Invalid array write | Record failure; never modify an unrelated element or fabricate a valid index. |
| Compound control header | Define the precise default continuation target; never treat a failed condition as a successful False or zero. |
| Failed allocation/resize | Preserve the destination where the operation promises it; release only unpublished partial work. |
| Two potential failures in one expression | Approved: the first failure abandons the statement; a later operand is not evaluated. Separate later statements may record newer errors. |
| Error while already running a handler | Approved: a received FAIL skips the failed statement and continues silently in the handler; update Err but do not re-enter or automatically propagate. Explicit Err.Raise still exits its containing procedure. |
| Resume retry | Reevaluate the failed statement, including its side effects; no transactional undo. Cross-call retries must name the caller's call statement. |
| Resume without an active failure | Diagnose when statically provable; otherwise report a controlled language error without a retry loop. |
| Err.Clear inside a handler | Clear the visible record without losing the saved resume location or silently ending handler execution. |
| Explicit Error / Err.Raise | Err.Raise exit-and-FAIL behavior is approved. Define legal numbers, complete signatures and Error statement equivalence before implementation. |
| Error.Set bootstrap primitive | Preserve its already documented record-only contract; it is not a hidden Raise operation. |
| Try-style API | Fresh status must be documented independently of Err; define whether a False result is normal non-success or a language failure for that API. The name Try alone decides nothing. |
| Resource cleanup fails after another failure | Retain the primary failure for the operation's outward report; define secondary diagnostics without accidental overwriting. Explicit user operations still obey normal last-error rules. |
| Callback / event handler | Define failure transfer separately from the event subscription and dispatch order; never run a caller's handler on a different thread. |
| Worker failure | Keep worker Err separate from creator/waiter Err; waiting successfully is not itself a failure. Define any completion error reporting explicitly. |
| Foreign call | Map a fresh outward failure to ABI status; do not fail because of stale Err. Never unwind through foreign frames. |
| Initialization | Distinguish handled recoverable errors from failure to establish a valid initialized module; stale Err alone cannot cancel startup. |
| Finalization/shutdown | Attempt remaining safe cleanup after a cleanup error; do not resurrect objects or create new work to escape termination. |

## Error record and diagnostics

Before implementing Err, define the exact public fields and their types,
read/write permissions, neutral values and replacement rules. Number,
Description and Source must have an explicit contract; VB6's HelpFile,
HelpContext, Erl and LastDllError must not be assumed to inherit host behavior.

Proposed requirements:

- Stable machine-readable codes; descriptions do not control program logic.
- Source location and operation identity remain available without requiring
  full debug information or unbounded string allocation.
- First publication can record at least a code using preallocated thread state.
- A new record never retains an unrelated old description or source.
- Error formatting must not recursively replace the error it is describing.
- Tool diagnostics and the generated program's Err are different interfaces.
  A compiler input error is a build diagnostic, not a successful compilation
  accompanied by a hidden Err value.

Existing numeric commitments include Err 5 for documented invalid bootstrap
arguments, Err 7 for exhausted allocation retry, Err 9 for documented invalid
array spans, and Err 28 for a safely refused stack-exhausting call. A complete
versioned code catalogue remains to be specified; do not assign numbers ad hoc.

## Project-wide obligations

| Component | Required observable behavior |
|---|---|
| Compiler frontend | Bounded diagnostics for malformed source; no native crash; no executable advertised as successfully built after a compile failure. |
| Build driver | Check each child process's fresh completion status; preserve prior valid outputs until replacement succeeds; report failed tool and actionable diagnostic. |
| LLVM lowering | Check overflow/division/index/storage conditions before unsafe instructions; preserve evaluation and error ordering under optimization. |
| UBECore | Document each operation's result, error code, mutation guarantees, allocation and thread ownership; no hidden dialogs or process termination for recoverable failures. |
| Target adapters | Validate handles/spans and translate OS failure into a defined UBE result; capture OS status before subsequent calls overwrite it. |
| Foreign ABI | Defined status and output-publication rules; stale/invalid handles fail safely; no language control transfer through foreign frames. |
| IDE | Show actionable errors without losing edits; isolate compiler/debugger/debuggee processes; failed saves preserve previous files and recovery state. |
| Bootstrap | Model target semantics explicitly; VB6 host On Error and host integer behavior are not UBE semantics. |
| Tests and release | Assert result, Err, control-flow trace and mutations; process survival alone is insufficient. |

## Acceptance cases required before implementation is called conforming

Use runtime input to prevent constant folding in runtime cases. Every relevant
case must run with optimization disabled and enabled and with both executable
and library entry paths where applicable.

| Case | Assertions |
|---|---|
| Known bad constant | Compile diagnostic; no runtime deferral. |
| Runtime bad conversion | FAIL, exact new Err, statement skipped or handler selected; no usable result or unfinished assignment. |
| Successful zero/False | Correct value; no fresh failure; prior Err preserved. |
| Two identical failures | Two distinct control-flow events even if Err.Number is unchanged. |
| Successful call with stale Err | No spurious handler, failed startup or foreign error status. |
| Failure midway through RHS | Exact evaluation trace, destination value and remaining calls. |
| Argument failure | Exact source-order trace and whether the callee executes. |
| Invalid receiver/index | No invalid access or unrelated mutation. |
| All handler modes | Exact branch target, executed statements and Err retention/clearing. |
| Nested calls and active handler failure | Assert caller statement skipping, enabled handler selection, and no re-entry when a running handler receives FAIL. |
| Retry | Repeated side effects are visible; no implicit rollback. |
| Failed resize/copy | Destination unchanged where promised; no leaked partial allocation. |
| Allocation and stack exhaustion | Bounded reporting; collection retry count; callee admission and cleanup. |
| Cancellation/timeout | Normal status; Err unchanged absent a separate failure. |
| Worker and UI dispatch | Thread isolation and correct logical caller error delivery. |
| Export/callback | Stable status; output untouched on failure where promised; no foreign unwind. |
| Startup/finalization | Correct admitted work and cleanup order, independent of stale Err. |
| Compiler/IDE failure | Assert diagnostic, process exit, preserved output/document and recovery data. |

These are acceptance obligations, not passing test results. Freeze the expected
values and traces after the open semantic choices are approved.
