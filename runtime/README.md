# Runtime development

Native worker runtime source, runtime regression tests and profiling helpers
live here. Obsolete one-time authoring transformations have been removed;
the canonical sources and reproducible tests below are the maintained inputs.

The canonical native worker runtime is [bootstrap/NativeThreadRuntime.bas](bootstrap/NativeThreadRuntime.bas).
The bootstrap project includes that module directly. `bootstrap/tools/runtime-text.ps1`
extracts its reviewed text into the production `compiler/llvm/windows-runtime.ll`
asset alongside the existing memory, file and process runtime definitions.

Run `powershell -NoProfile -File runtime/tests/threads/check.ps1` for the native
lifecycle gate. It exercises the production asset at O0/O2 with real workers,
simultaneous waiters, per-thread failures including Err zero, cooperative
stop-wait interruption, nested workers whose IDs are ignored, root completion,
disposal refusal while active, retained-handle retry, injected allocation/start/
wait/close failures, and a changed-oracle negative control. Evidence is retained
in the printed temporary directory.

Generated-launcher probes cover normal Main return with stale Err, fresh FAIL
with both nonzero and zero Err, and a native wait fault while a worker is held
behind a barrier. Drain retries observation while source workers remain active;
it preserves root Err and reports retained cleanup failure after they finish.
Restoring the previous early-return branch fails the prescribed regression
observation before the harness safely joins and releases the remaining worker.

`bootstrap/tests/native-intrinsics/check.ps1` separately executes wrappers
emitted by actual UBE code and checks both binders' thread signature refusals.
These gates do not by themselves qualify source `CallNew` capture lowering or
concurrent compilation. Their acceptance requirements are recorded in
[compiler/CONCURRENCY.md](../compiler/CONCURRENCY.md).

The Windows boundary uses `CreateThread` with an 8 MiB reserved stack and a
publication gate before the worker reads its capture. Multiple waits borrow
the same handle; closing requires zero borrowers and observed native completion.
No registry or storage lock is held across UBE calls or a native wait/close.
These choices follow the documented [CreateThread flags](https://learn.microsoft.com/en-us/windows/win32/api/processthreadsapi/nf-processthreadsapi-createthread),
[pending-wait handle lifetime](https://learn.microsoft.com/en-us/windows/win32/api/synchapi/nf-synchapi-waitforsingleobject),
and [CloseHandle ownership](https://learn.microsoft.com/en-us/windows/win32/api/handleapi/nf-handleapi-closehandle).
