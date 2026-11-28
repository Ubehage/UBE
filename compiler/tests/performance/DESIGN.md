# Generated-program performance evidence

## Allocation-pressure regression

`pressure-check.ps1 -CompilerExe <qualified-UBE.exe>` is a correctness/resource
regression, not a timing threshold. At O0/O2 it replaces the same live String
field for 512 and 1024 iterations, checks exact text/object/checksum preservation
and incoming Err 55, and snapshots allocation/root counts. Outstanding allocations
must remain at most 512 rather than grow with iteration count; one explicit
collection leaves exactly four reachable allocations. Root counts remain stable.
An explicit-collection-every-iteration control also leaves exactly four.
A third case runs two allocating workers with a shared object protected by
SyncLock, waits for both, and checks both arithmetic contributions and successful
completion markers. Each worker must preserve its own Err 55 through automatic
collection. The complete pressure gate contains twelve O0/O2 executions.

The pre-fix compiler failed with 1028 allocations after 512 iterations in
`%TEMP%/ube allocation pressure 3c1db34e-910c-4689-8c69-716cc98410c4/`.
The gate observes snapshot counts through a test-only native helper substituted
at an allowed Thread.CurrentId call in emitted IR. Ordinary source cannot declare
raw collector lifecycle intrinsics; the gate does not weaken that boundary.

The existing automatic allocation-pressure contract permits internal scheduling.
The implementation starts with a 256-allocation threshold; after a pressure
attempt it rearms at live allocations plus max(256, floor(live/2)). The existing
allocation-count bound makes the addition fit i64. Reservation and rearming use
the existing storage lock; the collector callback runs with that lock released.
The collection owner does not recursively request pressure collection. The
existing report=0 path preserves incoming Err, and allocation-failure collection
and retry remain unchanged. This is an internal policy, not a public knob or a
new collector. Native failure/rendezvous gates are required in addition to this
focused regression before qualification is claimed.

This corpus implements the existing lightweight, optimized native-code product
objective. It measures generated programs, not compiler throughput. It is not a
VB6 comparison or a performance release threshold.

Run correctness first from the repository root:

```powershell
powershell -NoProfile -File compiler/tests/performance/check.ps1 -CompilerExe <qualified-UBE.exe>
```

The script prints its temporary evidence directory. After arranging an otherwise
idle machine, reuse those exact binaries for measurements:

```powershell
powershell -NoProfile -File compiler/tests/performance/check.ps1 -CompilerExe <qualified-UBE.exe> -Mode Measure -PreparedDirectory <evidence-directory> -Batch 1 -Repetitions 5
```

No repository build outputs or dependencies are installed. Each process has a
deadline; failures retain logs and a failed report. Correctness is mandatory in
both modes. Prepared sources, harness, binaries, manifests, compiler and runtime
assets must still match their recorded hashes.

## Cases and independently specified results

Inputs are runtime command-line batch (0–9) and seed (1–9). N is batch times the
case's fixed iterations per batch; S is seed. N=0 returns checksum zero in every
case. Positive-N expectations use these closed forms in the host harness:

| Case | Iterations per batch | Observable work | Expected checksum |
| --- | ---: | --- | --- |
| scalar | 2000000 | scalar arithmetic and function calls | S×N×(N+1)/2 + 21×floor(N/7) + r×(r+1)/2, r=N mod 7 |
| array-record | 100000 | update 128 record cells each pass | 8128×S + 128×S×N + 379 |
| managed | 2000 | object method calls, UTF-8 String construction/equality | N×(N+1)/2 + S×N |
| collection | 20000 | two objects and a checked reference cycle per iteration; explicit collection every 64 iterations and at end | N×(N+1)/2 + 2×S×N |
| workers | 20000 | two workers adding through a shared object's SyncLock | N×(N+1) + 2×S×N |

Each O0/O2 executable must pass zero work, batch one with seeds three and seven,
and invalid seed rejection. Every timed invocation also checks its exact result,
count, seed, exit status and empty stderr. Runtime inputs and observable results
prevent replacement with an input-independent constant. Legal optimization,
including inlining, remains allowed; this is not an isolated call-overhead test.
String/reference assertions supplement the numeric oracle. Collection correctness
does not require a positive explicit collector count: automatic collection may
already have reclaimed objects. This corpus does not prove leak freedom.

## Measurement interpretation

`results.csv` retains all raw samples. `report.json` includes the host, exact tool
hashes/version observations, copied source hashes, support-runtime hashes, build
times, image sizes and sample records. Tool version-query failures are recorded;
the executable hash remains authoritative (llvm-dlltool need not accept
`--version`). Native artifacts must have an x64 PE32+ header.

`WorkMs` surrounds the workload inside the program and excludes argument parsing
and result formatting. It uses the admitted monotonic millisecond clock. The
timestamp unit does not promise one-millisecond effective granularity; values
below 10 ms are marked resolution-limited, not failures. `ProcessMs` includes
process creation, initialization, workload, output, shutdown and host launch/wait
overhead. A zero-work invocation of the same image is the startup baseline; it is
not a measurement of loader time alone. Do not subtract the two noisy timings
and label the difference pure startup or steady-state cost. Warmups are marked
separately. Trial order reverses across repetitions and seeds alternate.

OS process CPU time and peak working-set bytes are recorded only when available.
Unavailable memory observations remain null with a reason. Working set is not
managed heap size or an allocation count. Declared work units are scalar terms,
cell updates, managed iterations, two-object constructions, or synchronized adds;
they do not count every lowered operation or runtime allocation.

Acceptance requires every checksum/input/status assertion, bounded completion,
identity check and artifact check to pass. There is no arbitrary speed threshold.
Report medians and range with raw data, optimization level, batch and environment;
do not rank resolution-limited cases. The harness cannot establish machine
idleness and records that limitation explicitly. One Windows host, these small
workloads and the current support runtime cannot establish portability, a VB6
speed advantage, general workload coverage, or a performance regression budget.
