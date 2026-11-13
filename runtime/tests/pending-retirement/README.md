# Pending retirement collection

Run `rtk proxy powershell -NoProfile -File runtime/tests/pending-retirement/check.ps1` from the repository root. The gate builds the current production runtime asset at O0 and O2, instruments locked-scan entries, and checks exact scan and successful-release counts.

The cases cover an idle collection without scanning, a nonfinal reference drop, final-reference reclamation, retirement of an already-inspected live head during release of the following block, a refused release followed by successful retry, forced allocation-quota scanning with no pending retirement, and context reuse. The release callback deterministically reproduces the legal reference-drop interleaving while the collector holds the storage lock. Moving the flag exchange to scan completion must fail specifically at the missed-retirement assertion (exit 4). Positive cases must exit 0.

The program's pending-retirement field is a derived hint. Final drops mark it with a release atomic OR; scans acknowledge it with an acquire/release exchange at entry, and failed releases re-mark it. Allocation retries still scan unconditionally. Reference drops receive the owning thread context, and compute the program address before decrementing the reference count. No block access follows the final decrement. The three-cell block header and all existing collection checkpoints and workload bounds remain unchanged.

On 2026-11-13 the command passed both optimization levels and both negative controls, with evidence retained in `%TEMP%\ube pending retirement 0da58c39-c0e8-479b-8919-099ad290bdb9`.

Related regressions with bootstrap `%TEMP%\ube native context 49f0f01f-46f9-41d6-ae3e-610eb5293a0e\build\UBE-Bootstrap.exe`:

- `bootstrap/tests/native-context/check.ps1`: eight native executions, four actual UBE emissions, and the exact order negative control passed at O0/O2. This invocation built that bootstrap from current sources.
- `bootstrap/tests/shared-storage/check.ps1 -BootstrapExe <bootstrap>`: 26 harness assertions passed, including real native contention, isolated errors/programs, retained descriptors and boxed storage, injected failures, recovery and zero live allocations. Evidence: `%TEMP%\ube shared storage be48d3b1-6b9e-4ff8-be1c-1aa607bc7f2f`.
- `runtime/tests/threads/check.ps1`: 42 native lifecycle/failure/cleanup executions passed. Evidence: `%TEMP%\ube native threads 8f618618-2613-4613-ab9c-3c86b1594e6e`.
- `bootstrap/tools/runtime-text.ps1` and `bootstrap/tools/llvm-templates.ps1`: exact generated parity passed (runtime 150717 bytes; 170 templates, 23451 bytes).

These checks establish the collector behavior and regressions above. Compiler throughput requires its separate idle benchmark.
