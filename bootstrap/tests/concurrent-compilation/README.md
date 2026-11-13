# Concurrent compiler acceptance

The ordinary UBE coordinator uses one or two workers, selected explicitly by
`CompilationRequest.TryCompile`. This is a bounded implementation, not a
hardware-scaled scheduler. `CompilerCommand` selects two workers and renders the
structured result returned by the reusable request API.

One request prepares authoritative frontend facts once. Workers read those facts
without mutation and emit contiguous, node-weighted symbol ranges into separate
private files. Each worker owns its writer, numbering and traversal buffers.
The private entry takes the validated rendering catalog ByVal, so ordinary
array capture supplies a separate descriptor and payload for each renderer.
Project facts remain shared and read-only. Header/footer emission keeps the
coordinator's original catalog; direct calls and quota replay also use ByVal.
After every started source worker has completed, the request checks cumulative
work, byte and line charges, copies closed chunks in stable symbol order, writes
the footer and leaves publication to the existing guarded publication path.
Quota replay preserves the accepted diagnostic cursor. The unchanged request
limits are 10000000 work charges, 16777216 LLVM bytes and 500000 lines.

Request resources, range results and stage ownership remain with the caller for
cleanup retry. `SourceFinished` means source execution and capture access have
ended; it does not claim that an OS thread handle has closed. Thread identities
and unsuccessful native handle cleanup remain owned by the program registry for
final drain. `WaitFailed` records fresh failure independently of its error
number, including zero. The 64 MiB program heap is shared across simultaneous
requests; each request does not receive a separate 64 MiB allowance.

Run the correctness gate:

```powershell
rtk proxy powershell -NoProfile -ExecutionPolicy Bypass -File bootstrap/tests/concurrent-compilation/check.ps1 -BootstrapExe <qualified-bootstrap>
```

The gate builds the actual compiler and a small UBE request driver. Test-only
LLVM observers wait at bounded barriers, record overlapping emitter/request
body lifetimes and require their active counts to return to zero. These helpers
are not production scheduling hooks. They are marked noinline so the observers
do not move compiler frame allocations out of their entry blocks.

The gate compares one/two-worker IR, source-specific simultaneous requests,
ordered diagnostics (including operation) and diagnostic paths. It exercises
cancellation after both selected emitters have emitted a real symbol, worker
failure alongside an independently checked successful request, fresh Err-zero completion failure, quota
boundaries, retained close retries and competing publication. Native backend
request pairs additionally exercise independent process/job/log ownership,
exit-7 failure, timeout, preservation of existing output and subsequent recovery.
These scenarios are qualified only when the printed assertions pass; source
inspection alone is not concurrency verification.

A separate idle-machine measurement mode disables all scheduling observers:

```powershell
rtk proxy powershell -NoProfile -ExecutionPolicy Bypass -File bootstrap/tests/concurrent-compilation/check.ps1 -BootstrapExe <qualified-bootstrap> -MeasureOnly
```

It runs complete source-to-LLVM requests in worker order 1, 2, 2, 1, requiring
identical output hashes. It excludes harness compilation and the native backend.
The retained package includes its source ledger; the evidence includes hardware
identity, raw times and both executable/output hashes. Do not run competing heavy
jobs while collecting these measurements.

Supply `-MeasurementManifest <frozen-package/Compiler.UBE>` to reuse an earlier
workload. Every entry in its `sources.sha256` is checked before timing. The
manifest, current driver IR and runtime hashes are recorded separately.

On 2026-11-13 the complete correctness command above passed to exit zero in
`ube concurrent compilation 41f66ece-9d0b-4398-81c0-dc927ebab23d`, using qualified
bootstrap `ube native context 49f0f01f-46f9-41d6-ae3e-610eb5293a0e/build/UBE-Bootstrap.exe`.
This includes retained-close cleanup at O0/O2, exact work-boundary and footer
byte/line quota diagnostics at both worker counts, native backend isolation and
the 30-second backend timeout followed by a usable same-process request.

The first idle baseline used an AMD Ryzen 9 3950X with 32 logical processors and
51 source modules (722143 bytes). One-worker trials took 120003 and 123077 ms;
two-worker trials took 151002 and 152755 ms. All four output hashes matched.
The two-worker mean was approximately 25% slower. This establishes a performance
regression to investigate, not useful parallel speedup. Evidence is retained in
`ube concurrent compilation 38e1d451-c37a-4bfb-94d5-f36e273423a9`.

After the pending-retirement runtime correction, the same frozen workload took
4022 and 4005 ms with one worker, and 4735 and 5059 ms with two workers. Its
source ledger was checked and all four outputs matched. The absolute cost fell
substantially, but two workers remained about 22% slower; useful parallel
speedup is still unproven. Evidence is retained in
`ube concurrent compilation ff13c308-eb90-4949-a5b6-73be79b53f00`.

The following focused checks qualified the private-power scalar cache in
`ByteText.TryAppendInteger` on 2026-11-13:

```powershell
$hostExe = 'C:\Users\Ubehage\AppData\Local\Temp\ube native context 49f0f01f-46f9-41d6-ae3e-610eb5293a0e\build\UBE-Bootstrap.exe'
rtk proxy powershell -NoProfile -ExecutionPolicy Bypass -File bootstrap/tests/byte-text/check.ps1 -BootstrapExe $hostExe
rtk proxy powershell -NoProfile -ExecutionPolicy Bypass -File bootstrap/tests/llvm-format/check.ps1 -BootstrapExe $hostExe
rtk proxy powershell -NoProfile -ExecutionPolicy Bypass -File bootstrap/tests/llvm-writing/check.ps1 -BootstrapExe $hostExe
```

All three exited zero. Byte-text evidence `bbdae312-c4ad-4c56-b536-01b124f5c661`
contains 16 exact integer vectors, six bounds/publication cases and seven file
range cases at O0/O2, plus a negative control. Format evidence
`850e570b-a7c4-467f-a36b-e9aa04f1291f` contains 170 exact templates at O0/O2,
malformed-input and negative controls, and generator parity. Writer evidence
`b37e2e22-e70a-49a2-8a99-450c308af3a0` contains 14 native scenarios and the
changed-payload negative control.

The subsequent idle frozen-workload measurement used the command above with
`-MeasureOnly -MeasurementManifest 'C:\Users\Ubehage\AppData\Local\Temp\ube concurrent compilation 38e1d451-c37a-4bfb-94d5-f36e273423a9\compiler package\Compiler.UBE'`.
Trials in worker order 1, 2, 2, 1 took 3928, 4666, 4455 and 3880 ms, with matching
output hashes. Two workers remained 16.82% slower than one. Evidence is
`ube concurrent compilation c3c831ff-cfdf-44d0-97d7-ec1959bfc100`; this is not
evidence of useful parallel speedup.

The private renderer's ByVal catalog candidate subsequently passed the complete
correctness command in `95205396-5aaf-4636-b717-0b1298181b0b`. Additional O0/O2
cases inject a synthetic fresh failure with Err 8 at the second catalog copy
helper call, after the first source worker has entered. They require all-worker
cleanup, unchanged prior output and a successful subsequent request. This tests
caller/capture failure handling; it does not simulate the allocator's internal
retry path. Independent actual-UBE emission admitted the current compiler
within existing frame bounds, and its O0/O2 objects contained only the 42
reviewed native imports, with no CRT or stack-probe helper dependencies
(`ube private catalog planning`). Performance adoption remains dependent on
the separate frozen-workload measurements.

The complete gate was rerun against the integrated per-program descriptor
stripe runtime and exited zero in
`ube concurrent compilation 30afd7ad-b7cf-4153-a352-0b8b29e31988`, using
`ube native context 5b726a73-2fe7-48a4-865b-887e684959b6/build/UBE-Bootstrap.exe`.
This includes both catalog-copy failure cases and the native backend timeout
followed by recovery (30768 ms).

Final integrated idle timing used that same host and the validated frozen
51-module, 722143-byte workload. The exact command was:

```powershell
rtk proxy powershell -NoProfile -ExecutionPolicy Bypass -File bootstrap/tests/concurrent-compilation/check.ps1 -BootstrapExe 'C:\Users\Ubehage\AppData\Local\Temp\ube native context 5b726a73-2fe7-48a4-865b-887e684959b6\build\UBE-Bootstrap.exe' -MeasureOnly -MeasurementManifest 'C:\Users\Ubehage\AppData\Local\Temp\ube concurrent compilation 38e1d451-c37a-4bfb-94d5-f36e273423a9\compiler package\Compiler.UBE'
```

It exited zero in `ube concurrent compilation 39e257c4-0c53-40d9-885a-7938c4adb51d`.
Trials in worker order 1, 2, 2, 1 took 3939, 3581, 3517 and 3915 ms. Two workers
averaged 3549 ms versus 3927 ms with one worker, a 9.63% reduction on this
workload and machine. The observed ranges did not overlap. All four output
hashes were `8D4021512E2C1F4F4DAE9D0B560DA3358D1D8B158E5F484C52AACF5D69B81115`.
The measurement excludes native backend execution and driver construction;
it does not promise the same speedup for other projects or hardware. Raw times,
hardware identity, frozen source ledger and driver/runtime hashes are retained
with the evidence. The separate final self-hosting comparison passed in
`ube compiler rebuild 18c217dd-d417-4e79-b96a-198202d3613a`; common conformance
passed 860 assertions for the bootstrap/generation 2 and 446 for generation 1.
Exact commands and artifact identities are recorded in compiler/Progress.md.
