# Native resource contention qualification

Run `check.ps1 -BootstrapExe <qualified-host>` from PowerShell. The gate emits
`Owners.bas` with the ordinary FilePrimitives and ThreadPrimitives declarations,
then links the resulting source procedures with `probe.ll` at O0 and O2.
`-LoweredIR <path> -ProbeSymbol <identity>` accepts the same ordered library corpus
emitted by the UBE lowerer (ThreadPrimitives, FilePrimitives, Owners). Probe is the
last procedure in Owners and takes `(ByVal Mode As Long, ByRef Value As Long)`.
Every external process has a 60-second deadline. Artifacts and process output are
retained in the printed temporary directory.

Four fresh-context schedules each start eight real source `CallNew` workers.
Each worker creates 16 separate files, writes four known bytes, closes, reopens,
reads and compares every byte, closes and deletes. An open barrier for each
iteration exercises simultaneous live owners. Conditional yields vary admission
order. Exact source assertions check success, failure outputs, lengths, transfer
counts, cleared close tokens, and all 256 positive tokens for pairwise uniqueness.
The registry has 64 slots, so 256 successive identities exercise slot reuse.

A separate deterministic same-token case claims an existing slot in the test
bridge before starting a source worker. Its write must return False, Failure 13,
Err 5 and zero transferred bytes. The bridge releases the claim after the worker
finishes. After draining all workers, disposal must refuse the still-live file;
ordinary source closes and deletes it, then registry emptiness, successful
disposal and zero tracked native allocations are required. No production test
hooks or synchronization changes are introduced.

Passed with the qualified bootstrap host at O0/O2 on 2026-11-13:
`ube resource concurrency b0bd98d8-7b0c-43ab-b892-297f6579c03c`.
This is bounded file-owner contention coverage, not exhaustive scheduling,
process-owner contention, or concurrent compiler qualification. The deterministic
claim checks the Busy policy separately from independent-owner file I/O.
