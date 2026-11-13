# Owned process primitives

Run from the repository root with a freshly built bootstrap:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File bootstrap/tests/process-primitives/check.ps1 -BootstrapExe <UBE-Bootstrap.exe>
```

The gate emits the ordinary UBE probe and builds the same LLVM at O0 and O2. Each executable checks 124 assertions. Independently compiled native children check the exact UTF-16 command line and working directory, NUL standard input, root exit code, and exact combined standard output/error bytes. No command shell interprets arguments. A child that launches a persistent descendant proves that root exit alone does not satisfy completion; tree termination must drain the job before release succeeds.

Target wrappers inject failures into job creation/configuration, input opening, log duplication, both attribute-list initialization calls, handle-list construction, process creation, job assignment, thread resume, wait, exit-code observation, job accounting, both termination paths, and each of five native close positions. Counters observe real successful acquisitions/releases and require zero remaining native handles and attribute lists after every recovery. An allocation observer denies both allocation attempts, checks recovery, and requires zero live allocations after context disposal. Other assertions cover cross-resource token rejection, overlapping wait outputs, sticky Err, invalid bounds, missing application, running-close refusal, and failed-start cleanup.

`TryStart` accepts nonempty explicit application and directory paths bounded to 4096 UTF-8 bytes. The command is strict UTF-8 bounded to 131072 bytes and 32766 UTF-16 units before its terminator. Embedded NUL is invalid. The implementation uses a bounded 4096-byte attribute-list buffer and refuses a larger OS requirement. Inputs are caller-owned arrays; the native command buffer is privately writable. Only the private inheritable NUL input and duplicate log handle appear in the explicit process handle list. The caller's log owner remains independent.

`TryStart` requires an initially zero process token. Invalid input or allocation failure leaves it zero; OS setup failure can return a nonzero token owning partial setup. That token must be terminated, drained and closed. Assignment to a kill-on-close job occurs while the root is suspended, before it can execute. A failed assignment retains the suspended root for explicit termination.

`TryWait` accepts 0 through 5000 milliseconds. State 0 means incomplete and preserves ExitCode; State 1 requires both observed root exit and an empty job and publishes the signed 32-bit exit-code bits. Job accounting can lag root signaling, so callers poll under their own deadline. Failed waits preserve both output values. Successful calls preserve an older Err while clearing the explicit Failure output.

`TryTerminate` requests termination and retains ownership. `TryClose` independently observes completion, refuses running owners, closes every releasable handle, and retains each unsuccessful close for retry. Only complete release clears the token. A failed-start owner without a root is already complete for cleanup purposes. File operations reject process owners, and process operations reject file owners.

Deadline, cancellation, log-size monitoring and compiler diagnostics belong to ordinary UBE callers. Log-size polling detects overflow; it is not a hard disk-write cap. This focused gate qualifies the primitive boundary, not complete compiler self-hosting or concurrent host-request behavior.
