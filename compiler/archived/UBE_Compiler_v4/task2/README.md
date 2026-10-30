# Compiler v4 Task 2 evidence

`run-task2.ps1` is the deterministic focused and cumulative-ready gate for the
first production v4 shell. It validates every `UBE-Test-Case 1` manifest under
`../tests/task02-shell/cases/`, builds `UBE_Compiler_v4.UBE` twice through the
preserved v3 compiler, compares LLVM hashes, links the native Windows x86-64
shell, executes all declared cases with separate arguments and a ten-second
timeout, and atomically publishes `bootstrap/out/v4-task2/verified-build.json`
only after cleanup succeeds.

The checked cases cover native startup, deterministic record publication,
malformed CLI/target input, empty and missing project input, exactly-at and
just-over argument limits, injected allocation/tool/write/cancellation
failures, stale-output removal, and host cleanup rejection. Generated LLVM,
executables, records, temporary files, and evidence stay below
`bootstrap/out/v4-task2/`.

Task 2 phases are deliberately fake adapters. They prove session ownership,
failure propagation, cancellation, cleanup, and atomic publication; they do
not claim lexing, parsing, semantic analysis, IR, LLVM generation, or compiler
parallelism. Those capabilities begin with later roadmap tasks.
