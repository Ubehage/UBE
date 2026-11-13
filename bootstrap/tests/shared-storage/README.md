# Shared runtime storage regression

Run `powershell -NoProfile -File bootstrap/tests/shared-storage/check.ps1 -BootstrapExe <bootstrap-executable>` with the current bootstrap executable and Windows LLVM tools.

The gate emits the UBE fixture, then links a test-only native `CreateThread` harness at O0 and O2. It checks:

- Two native workers contend on the same program storage lock while resizing and copying a shared array for 3,000 iterations each. A test-only delay requires observed lock contention before either worker can finish.
- Workers share program globals and keep independent sticky Err values; separate programs retain their own globals and parent Err values.
- Four injected allocation failures reach the expected failure result, followed by successful recovery.
- Heap boxes containing array descriptors survive either caller-first or worker-first ownership release. Both orders use a real native worker. The final outer owner releases the descriptor's inner ownership while an independent inner pin remains readable with exactly one reference.
- Joined workers, closed native handles and successful context disposal leave zero live runtime allocations.
- Changing the expected shared value from 42 to 43 produces the prescribed assertion exit code at both optimization levels.

The harness retains generated IR, executables and process outputs in the printed temporary evidence directory. This gate qualifies runtime ownership and storage operations through native harness threads; it does not qualify source `CallNew`, source capture lowering or production worker lifecycle APIs.
