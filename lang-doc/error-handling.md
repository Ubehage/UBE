# UBE failure and continuation contract

**Status:** owner-approved core behavior, 2026-11-10; implementation pending.

This contract supersedes earlier descriptions of recoverable language failure
as a usable neutral result inside an expression. Unresolved boundary details
remain tracked in `../project-docs/Error-Handling.md`; they must not be inferred
from VB6 host behavior.

## Failure is separate from the value

A procedure call completes successfully with its declared result, or returns
FAIL. FAIL is a fresh internal call outcome, not a source-language keyword,
string, Variant tag, zero, False, empty string or Nothing. Subs can fail too.
No successful result is available from a failed call. Compiler-generated
control flow must check the fresh outcome before consuming a result.

Err records the error information for the current thread. A successful call
does not clear it and does not become a failed call because an older error
remains. A new error replaces the complete record. Err.Clear and valid Resume
statements clear it; procedure return and changing handler mode do not.

## Explicit raise terminates the raising procedure

Err.Raise records the error, immediately exits the procedure containing that
call, and returns FAIL to its caller. Code following Err.Raise in that procedure
does not execute. It does not enter that procedure's own handler instead of
returning; handling the failed call belongs to the caller.

For example, using a parameter name that is not a reserved word:

```vb
Function Foo(ByVal Value As Long) As Long
    Err.Raise 5
    Print "You will never see this."
End Function
```

An earlier assignment to the Function result does not turn this failure into a
successful return. Err.Raise remains a legal operation in a reusable procedure;
its presence alone does not make every declaration of an error path invalid.

## The caller handles the failed statement

The default is the continuation behavior of On Error Resume Next. On receiving
FAIL, the caller abandons the rest of the statement containing the failed call
and continues with the next statement. Remaining operands and calls in that
statement are not evaluated; an assignment whose value has not been obtained
does not commit. The caller itself need not return FAIL merely because one of
its statements failed. To report failure to its own caller, it raises an error.

An enabled On Error GoTo handler in the caller receives control instead of
default continuation. Explicit On Error Resume Next selects the default
statement-skipping behavior. On Error GoTo 0 disables the label handler and
restores default continuation. These operations do not clear Err.

For a call whose failure depends on runtime input:

```vb
Count = 25
Count = ReadCount(InputText) + 10
Print Count
```

If ReadCount fails and no label handler is enabled, Count remains 25, the
addition is not performed, and Print executes. No neutral zero is substituted
to make Count become 10. The new error remains available through Err.

Recoverable language-operation failures, including checked conversion and
arithmetic failures, likewise abandon the containing statement according to
its error mode. Neutral initialization of storage is still permitted; it is
not a successful failure-result value. A failed declaration initializer leaves
the already established variable at its neutral initial value.

Side effects completed before failure remain completed. Statement skipping is
not a transaction and does not imply rollback of earlier calls or ByRef writes.
Each operation retains any specific preservation guarantee in its own contract,
such as preserving an existing array when replacement allocation fails.

## Failure while a handler is running

Owner decision: a call that returns FAIL while an error handler is already
executing must not recursively enter that handler. Abandon the failed statement
and continue with the next statement inside the handler, without automatic
propagation out of the procedure or an error dialog. Silence does not suppress
Err: the new error replaces the earlier record under the ordinary rules.

This concerns a failure received from an operation or called procedure. An
explicit Err.Raise executed by the handler itself retains the separately
approved immediate-exit behavior. The saved resume location must not be
overwritten merely by a failed call skipped during handler execution.

## Cleanup before raising belongs to the procedure

Before Err.Raise, the procedure must explicitly release user-owned resources
that it needs to release: files, sockets, native handles, manually acquired
locks, registrations and similar resources. Neither Err.Raise nor the caller
automatically runs that procedure's application cleanup. Cleanup statements
placed after Err.Raise are unreachable and cannot fulfill this responsibility.

This does not remove compiler-owned lifetime obligations. Exiting a procedure
must still retire its stack frame, managed roots and temporaries safely, and
honor existing structured SyncLock exit rules. Releasing a managed reference
does not imply closing a user-owned file or native resource. No new automatic
resource tracking, Finally mechanism or user cleanup callback is introduced.

An error during explicit cleanup is subject to the same error rules. Whether
and how the procedure preserves an earlier error while attempting cleanup is
its responsibility; it must not depend on a stale Err value as a fresh status.

## Compile-time and fatal failures

Provably invalid operations receive compile-time diagnostics rather than being
deferred to runtime. Runtime examples must use genuinely runtime-dependent
input. Exact interprocedural diagnostic analysis limits remain to be specified;
this rule does not require solving arbitrary program behavior at compile time.

Recoverable failures never automatically display a dialog or terminate a
process merely because a handler is absent. When safe continuation or safe
error reporting is impossible, the existing controlled fatal-failure contract
applies; continuing with corrupt state is forbidden.

## Scope of this decision

This settles Err.Raise, fresh FAIL status, default statement continuation,
caller label handling, assignment preservation and cleanup responsibility.
Full Err member signatures, explicit Error statement equivalence,
special control-statement resume targets,
Try-style record-only APIs and cross-thread/foreign lifecycle boundaries still
require the detailed decisions listed in the project review. They must not
silently weaken the approved behavior above.

No grammar change is required: Err.Raise uses the existing member-call syntax.
FAIL describes internal execution status, not an additional source token.
