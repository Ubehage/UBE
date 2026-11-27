# Runtime development

Native worker runtime source, runtime regression tests and profiling helpers
live here. Obsolete one-time authoring transformations have been removed;
the canonical sources and reproducible tests below are the maintained inputs.

The current allocator grows to checked representation and operating-system
resource limits; the former fixed byte/block quotas are removed. Managed
snapshot and queue metadata grow together before record publication. Procedure
storage uses small bounded stack frames or checked heap frames, preserving
roots and controlled allocation failures. See [managed-memory.md](managed-memory.md)
and [the current compiler evidence](../compiler/FLOATING-POINT.md).

The canonical native worker runtime is [bootstrap/NativeThreadRuntime.bas](bootstrap/NativeThreadRuntime.bas).
The bootstrap project includes that module directly. `bootstrap/tools/runtime-text.ps1`
extracts its reviewed text into the production `compiler/llvm/windows-runtime.ll`
asset alongside the existing memory, file and process runtime definitions.

Precise-root metadata mechanics are now authored in
[bootstrap/NativeManagedRuntime.bas](bootstrap/NativeManagedRuntime.bas) and
included by the same extraction tool. The exact primitive and layout
boundary is [managed-memory.md](managed-memory.md). Frame registration,
rooted identity transfers, thread registration and snapshot-mark metadata
access, rendezvous, typed edge enumeration, packed text candidates, allocation
retry and orderly disposal are implemented. Graph traversal and sweep selection
remain ordinary UBE in `std-lib/src/portable/ManagedMemory.bas`.

`tests/managed-text/metadata-check.ps1` checks the canonical managed mechanics
at O0/O2 with an isolated metadata harness: exact snapshot counts/identities,
invalid-output preservation, first versus repeated marking, seal rejection,
frame/candidate cleanup, rooted transfer, consumed return handoff, registration
and native-safe reentry, packed text lifecycle and idempotent shutdown. Missing
metadata lists produce controlled rejection; removing the guard reproduces the
access violation. A changed first-mark result is rejected. Evidence
`d4e1f0c4-5bb9-4566-9950-06776655953b` passed; this gate alone does not establish
stop-the-world collection or actual UBE String execution.

`tests/managed-text/fault-check.ps1 -ProgramIR <positive emitted program.ll>`
links assertions to the actual compiler-emitted UBE collector and requires the
current runtime asset verbatim. Test-only allocation, workspace and release
hooks exercise one callback/one retry, preserved Err and exhausted source depth,
failed workspace and partial marking without sweep, retained charges after release failure, subsequent
recovery, startup refusal and zero owned blocks after disposal. `-Rendezvous`
forces two callers to own/join one round, checks independent Err values and a
String rooted only by the worker capsule. `-Graph` constructs exact native
metadata for a 5000-record cycle and checks integer lookalikes are not roots,
reachable cycles survive and unreachable cycles are reclaimed. These do not
substitute another traversal algorithm. `-Growth` additionally checks metadata
expansion, allocation refusal with unchanged old buffers, and recovery. Current
O0/O2 results are in [the managed-text gate](tests/managed-text/README.md).
The following earlier String checkpoint used the former 3000-record graph:
all three suites passed O0/O2 with changed-oracle controls against its
`Collector.ll`: `b1c128e1-3921-4bcd-972c-45f57ed80bbe`,
`afbc26b8-341c-4190-8c44-3db782e9baf4`, and
`51be44cd-6f31-44ea-9db7-3fd1c55f4914`, respectively. The input is retained in
`ube managed text a6271c60-763d-4b23-be3e-6ea3562f19ec`.

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
