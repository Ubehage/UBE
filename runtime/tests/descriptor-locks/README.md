# Program-owned descriptor locks

Run `rtk proxy powershell -NoProfile -File runtime/tests/descriptor-locks/check.ps1` from the repository root. The gate builds the current production runtime at O0/O2 and uses real native threads to check:

- A snapshot of a descriptor mapped to a different stripe completes while another stripe is held.
- The same descriptor address mapped through a different program remains independent.
- A distinct descriptor mapped to the held stripe waits until that stripe is released, then returns a coherent snapshot.
- Context initialization resets stripe storage and reports the expected enlarged context size.

The harness finds actual colliding and distinct addresses using the production hash. It observes worker entry, native wait outcomes, snapshot values, joins and native handle closure. A negative control restoring the old heap-only snapshot lock must fail at the collision assertion with exit 4. The positive images must exit 0. These checks passed at both optimization levels with evidence `%TEMP%\ube descriptor locks 4751e057-0af6-427b-84ce-a83531c3855d`.

Program field 13 contains `[65 x [8 x i64]]`: the first 64 bytes are padding, and the 64 actual lock words are separated by 64 bytes. This prevents sharing a cache line with pending-retirement state, even when the program has only 8-byte alignment. The context contains `853 + 2*moduleCount + globalCellCount` words. Array descriptors and the three-cell heap-block header are unchanged.

Snapshots take only the descriptor stripe and retain the backing block before releasing it. Descriptor writers retain the heap lock and then take the stripe. Final boxed-array cleanup uses the same writer path. No stripe holder acquires the heap lock, invokes source code or performs an OS operation. Other heap-only descriptor readers remain coherent because all published descriptor mutations still hold the heap lock. Locks belong to each program and reset with its context; there is no process-global mutable lock table.

Additional integration regressions passed with freshly built bootstrap `%TEMP%\ube native context 5b726a73-2fe7-48a4-865b-887e684959b6\build\UBE-Bootstrap.exe`:

- `bootstrap/tests/native-context/check.ps1`: eight native executions, four actual UBE emissions and exact order negative control.
- `bootstrap/tests/shared-storage/check.ps1 -BootstrapExe <bootstrap>`: 26 assertions including same-descriptor contention, retained backing pins, boxed lifetime, injected failures, recovery and zero live allocations. Evidence `ube shared storage e15d6b32-94c3-4ff1-b1f1-382a833554a3`.
- `runtime/tests/threads/check.ps1`: 42 lifecycle/cleanup executions. Evidence `ube native threads 16016277-72e9-4dab-b568-6a28609e2172`.
- `runtime/tests/pending-retirement/check.ps1`: both optimization levels and the missed-retirement negative control. Evidence `ube pending retirement 41cc4ee2-3e4d-4a1d-9f2f-53d47380dc76`.
- `bootstrap/tools/runtime-text.ps1` and `bootstrap/tools/llvm-templates.ps1`: exact parity for the 152116-byte runtime and 170 templates (23487 bytes).
- `bootstrap/tests/native-lowering/allocation-check.ps1 -BootstrapExe <bootstrap>` and its `-CallNew` variant: all 70/97 measured allocation sites plus malformed-input, I/O, depth, exact recovery and zero-live-allocation checks passed at O0/O2. Evidence `ube lowering failures 1d56a573-1fed-4637-ab71-09299d2c5ea5` and `ube lowering failures 442c13c5-eb21-4444-9068-674d7065d5de`.

The test-only global-table experiment that motivated this integration is documented in [storage-profile](../storage-profile/README.md). Its timings do not substitute for measuring the integrated per-program implementation.
