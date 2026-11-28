# Windows x64 generated-program checkpoint, 2026-11-28

All ten O0/O2 builds passed the predefined exact checksum, zero-work and invalid
input checks. A completed measurement run passed another 40 correctness/input
invocations, ten warmups, 50 timed workloads and 50 paired zero-work baselines.
This is scoped performance evidence, not a compiler-wide performance guarantee.

Compiler: `%TEMP%/ube compiler rebuild b6d42d2d-883c-4198-b223-776c5aa59025/generation-2/UBE.exe`.
SHA-256: `C5ED6B2976C03D6D0EEC754E480E7C5E7F488125DEEB6EAD13A142E02E38088F`.
Host: Windows 10.0.26300.0 x64, AMD64 Family 23 Model 113 Stepping 0,
32 logical processors, PowerShell 5.1.26100.10068. Other agents confirmed their
builds/tests had stopped before timing; this is coordination evidence, not
exclusive machine isolation.

Commands, with the compiler above substituted for `<compiler>`:

```powershell
rtk proxy powershell -NoProfile -File compiler/tests/performance/check.ps1 -CompilerExe <compiler>
rtk proxy powershell -NoProfile -File compiler/tests/performance/check.ps1 -CompilerExe <compiler> -Mode Measure -PreparedDirectory "$env:TEMP/ube generated performance 1cb67759-8216-4848-8643-a5278b9c6d0f" -Batch 1 -Repetitions 5
```

Completed raw CSV, report, logs and identities:
`%TEMP%/ube generated performance dcc11b4d-e58d-466b-94d8-315d9db0d360/`.
Prepared sources, manifests and exact native binaries remain in the preparation
directory named in the command. These local temporary artifacts may later expire;
the checked-in harness and fixtures are the reproducible evidence recipe.

Five measured repetitions, one batch, alternating seeds three/seven:

| Case | O0 workload ms median (range) | O2 workload ms median (range) | O0 image bytes | O2 image bytes |
|---|---:|---:|---:|---:|
| scalar/calls | 47 (46–63) | 16 (16–16) | 150016 | 168960 |
| array/record | 359 (359–360) | 110 (109–125) | 159232 | 178176 |
| managed String/object | 1250 (1234–1437) | 1453 (1250–1656) | 536064 | 911872 |
| allocation/collection | 187 (172–203) | 156 (156–172) | 536576 | 912896 |
| synchronized workers | 31 (15–32) | 16 (16–32) | 539648 | 917504 |

The monotonic clock advances in coarse ticks on this host; the 16 ms scalar and
worker results cannot support fine timing ratios. The pooled zero-work process
baseline median was 34.66 ms O0 (32.47–38.46) and 34.43 ms O2 (31.91–45.44).
These include host launch/wait, argument/output handling and shutdown; they are
not isolated loader costs. Per-case baselines remain in the raw CSV. OS peak
working-set counters were unavailable after exit and are recorded null.

O2 did not improve the managed String/object case in this sample and increased
image sizes in all five cases. A separate batch-three warmup took 47532 ms for
6000 managed iterations at O0; that longer run was deliberately interrupted
before completing repetitions and is not a qualified timing comparison. Its
partial logs remain in `%TEMP%/ube generated performance fc7c513d-d1b5-481e-9407-1edb9659300c/`.
The nonlinear managed-workload scaling deserves a focused runtime/profile
investigation before performance claims. No root cause or fix is inferred from
these measurements, and there is no VB6 speed comparison or pass/fail speed bar.

## Allocation-pressure correction and correctness qualification

The focused followup established accumulating unreachable allocations rather
than growing roots: 128/256/512 replacement iterations retained 260/516/1028
allocations with nine roots; explicit collection reduced every case to four
allocations. The runtime used a linear identity list and automatic collection
only on allocation failure. This supports the narrow scheduling correction
described in DESIGN.md, without attributing every measured millisecond to lookup.

The corrected compiler at `%TEMP%/ube checked publication corrected compiler/UBE.exe`,
SHA-256 `D00694FF12F90ECD2B75928B93827A131F13EF3FD44F14C386F8F18E3797F43D`,
passed:

```powershell
rtk proxy powershell -NoProfile -File compiler/tests/performance/pressure-check.ps1 -CompilerExe <corrected-compiler>
rtk proxy powershell -NoProfile -File runtime/tests/managed-text/fault-check.ps1 -ProgramIR <pressure-IR>
rtk proxy powershell -NoProfile -File runtime/tests/managed-text/fault-check.ps1 -ProgramIR <pressure-IR> -Graph
rtk proxy powershell -NoProfile -File runtime/tests/managed-text/fault-check.ps1 -ProgramIR <pressure-IR> -Rendezvous
rtk proxy powershell -NoProfile -File runtime/tests/managed-text/fault-check.ps1 -ProgramIR <pressure-IR> -Growth
rtk proxy powershell -NoProfile -File runtime/tests/threads/check.ps1
```

Pressure evidence: `%TEMP%/ube allocation pressure 87b48578-301d-42d6-9801-e6c7b4c2a88d/`.
Twelve O0/O2 cases check bounded allocations, exact surviving values/roots,
Err preservation, concurrent allocating workers and explicit collection controls.
The identical allocation bound rejects the pre-fix compiler with 1028 allocations
after 512 iterations: `ube allocation pressure 3c1db34e-910c-4689-8c69-716cc98410c4`.

The native fault suites used `o0/Pressure.ll` from the equivalent initial passing
run `ube allocation pressure 6bdc15d3-0abc-41de-aa41-a982c7f7a004`.
O0/O2 positive and negative controls passed for allocation retry/workspace abort
and recovery (`ube managed faults a0a0772c-3cc0-4e9b-a160-7b6770b1d7dc`),
the 5000-record graph (`16e68884-8020-4462-b01b-3fb825a81bd9`), joined collection
and thread error isolation (`a86c5bc5-2077-4f49-94e2-51df805de232`), and metadata
growth failure/recovery (`f0b239ee-6fcc-406c-8d39-8341632c7f97`). The complete
native lifecycle gate passed in `ube native threads f8c14a95-beb5-4e85-9c76-7c6790cc709b`
after correcting its stale EntryStart/Entry test composition.

These checks qualify correctness and bounded retained garbage. No controlled
post-fix timing comparison has been performed; the timing table above remains
the explicitly identified pre-fix checkpoint.
