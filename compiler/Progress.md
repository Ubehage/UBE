# Compiler development handoff

## Completed: checked integer operations and Unicode scalar codecs

Owner requested the next language/library increment, its qualification, root
README update and GitHub main publication. The dependency audit found ordinary
String requires the separate precise managed-memory architecture; byte-oriented
UTF-8 validation existed, but reusable scalar decoding/encoding and checked
integer `*`, `\`, `Mod` were missing. These foundational operations now pass
qualification under Roadmap.md's complete-language item. Managed String design is
recorded in TEXT-SUPPORT.md, not approved or claimed implemented by this task.

Concrete scope: both compiler paths admit/fold/lower the three integer operators
with the frozen EBNF precedence and existing promotion, error and evaluation
rules. `*` binds less tightly than `\`, which binds less tightly than `Mod`.
Zero division/remainder reports Err 11; overflow reports Err 6; minimum signed
value Mod -1 is successful zero, while its integer division overflows.
`/` and `^` still require floating-point support and remain rejected.

The library deliverable is `Utf8.TryDecodeScalar` and `Utf8.TryEncodeScalar`,
ordinary UBE algorithms over existing counted Byte storage. Exact declarations,
failure/publication and threading contracts are in ../std-lib/UNICODE-SCALARS.md.
No new runtime ownership architecture, generic built-in function semantics or
third-party dependency is introduced. Existing UTF-8 validation is reused.

Completed evidence: narrow original rejection; independent O0/O2 integer oracles
and negative/failure tests; exact UTF-8 vectors and exhaustive valid scalar
round trips plus independent encoding oracle, malformed inputs, bounds and
unchanged outputs; both bootstrap and actual UBE paths; prior UTF-8/scanner
regressions, actual lowering/import checks, successive self-build/conformance
and concurrent compilation. The next dependency candidate is managed String;
TEXT-SUPPORT.md records the required design/approval work, not a new active
implementation commitment.

Work ownership: production arithmetic in compiler/src and templates; bootstrap
parity in bootstrap/src; independent arithmetic gate in
bootstrap/tests/integer-operations; library/codecs and integration with root.

### Verification checkpoint

The final seed is `%TEMP%\ube source semantics cf7c9be7-1c06-4b32-8910-5fb75d3b6825\build\UBE-Bootstrap.exe`;
the initial final UBE compiler is `%TEMP%\ube integer codec compiler final\UBE.exe`.
Runtime parity remains 152116 bytes and 42 reviewed imports. The expanded
catalog has 177 templates / 24032 bytes / checksum 1886443.

`rtk proxy powershell -NoProfile -File bootstrap/tests/integer-operations/check.ps1 -CompilerExe <compiler>`
passed at O0/O2 with both final seed and actual UBE compiler. Evidence:
`ube integer operations 645ccce3-c497-4764-8be9-bc1df83a562c` and
`ube integer operations b5b11006-35b7-4caf-b0e3-17f5ffc660e8`.
The gate checks all integer widths, promotion and intermediate/narrowing
overflow, signs/extrema, constant/runtime agreement, exact evaluation and
failure order, handler/default continuation, changed-input rejection and
recovery. Sixteen numerical/Mod-spacing negatives preserve prior IR and EXE.
Pre-change actual UBE rejection plus an accepted addition control is retained
in `4ff6605a-5478-4ea5-a785-78a161bb7b86`; the independently reproduced spacing
bug is `fca7b2fa` (full IDs in the gate README).

`rtk proxy powershell -NoProfile -File std-lib/tests/unicode-scalars/check.ps1 -CompilerExe <compiler>`
passed for the same seed and UBE compiler in
`ube unicode scalars f621e0e5-196e-4e61-9ac2-adfa0456a7da` and
`ube unicode scalars 93bbd1ea-ca54-4058-9257-dd3572c2800e`.
Each checks 35 boundary/malformed/span/publication groups, all 1,112,064 valid
scalar round trips and exact independent .NET UTF-8 bytes at O0/O2, plus a
changed-scalar negative control. The helper algorithms contain no shared
mutable state and add no dynamic allocation or new runtime ownership model.

Regressions on seed 79867c1f (before the sole final malformed-Mod spacing fix):
source-scanning/check.ps1 passed 86 groups (`52807993-ee25-4923-920e-6bf977bc1822`),
source-scanning/utf8-check.ps1 passed 37 cases at O0/O2 plus changed input
(`1b5da3f6-95c8-4b1a-b7a0-8cf139bf5daa`), native-values/check.ps1 passed 38
UBE fragments / 119 vectors and negative control
(`6c29a3fd-d77a-48f1-b607-b8a3bc65d9d7`), llvm-format/check.ps1 passed 177
exact templates and malformed/negative controls (`6600acb3-7797-4820-b217-0545f6347408`).
Full native-lowering/check.ps1 passed
(`211577be-a565-43c8-bbe7-ba5349776c36`), including actual O0/O2 compiler objects,
reviewed imports, language/system behavior, 11 CallNew fault sites and all 54
dynamic-storage groups. The full concurrent-compilation/check.ps1 passed
(`de75a800`, full ID in the integer gate README), including isolated native
backend timeout followed by recovery. No idle performance result is claimed
for these concurrently executed regressions. All commands used `-BootstrapExe
<79867c1f host>` and the normal RTK PowerShell prefix.

After the spacing correction, source-semantics/check.ps1 passed 76 cases on
the final seed; source-scanning/syntax-check.ps1 passed 13 cases
(`fbb735c0-8a79-4d0d-86d2-3887b41d7fb6`). Final successive self-builds and common
conformance passed with the frozen corrected sources. The common corpus now
includes nine families, adding the arithmetic and Unicode fixtures.

Final commands from the repository root:

```powershell
$seed = 'C:\Users\Ubehage\AppData\Local\Temp\ube source semantics cf7c9be7-1c06-4b32-8910-5fb75d3b6825\build\UBE-Bootstrap.exe'
$initial = 'C:\Users\Ubehage\AppData\Local\Temp\ube integer codec compiler final'
$rebuilt = 'C:\Users\Ubehage\AppData\Local\Temp\ube compiler rebuild 30c8f236-462a-4e4f-a55d-7cf29fe9b408'
rtk proxy powershell -NoProfile -File bootstrap/tools/build-compiler.ps1 -CompilerExe $seed -Destination $initial
rtk proxy powershell -NoProfile -File bootstrap/tests/self-hosting/rebuild-check.ps1 -InitialCompilerExe "$initial\UBE.exe"
rtk proxy powershell -NoProfile -File bootstrap/tests/self-hosting/check.ps1 -CompilerExe "$rebuilt\generation-2\UBE.exe" -BootstrapExe $seed
rtk proxy powershell -NoProfile -File bootstrap/tests/self-hosting/check.ps1 -CompilerExe "$rebuilt\generation-1\UBE.exe" -BootstrapExe $seed -CompilerOnly
```

Every command exited zero. Host build took 17200 ms; successive actual
self-builds took 16563/16597 ms (observations, not an idle comparison).
Verified source ledgers and all native assets match repository bytes.
Both generations emitted exact LLVM SHA256
`32A09DCAE7FFD77A2947C31CA960EC138569186F940FBF42B029FB1BBC99C044`.
Their native images differ only in the documented four-byte COFF timestamp at
offset 128; normalization of that field alone yields exact bytes.
Final common conformance passed 1004 assertions for seed/generation 2 in
`ube compiler conformance a86e5700-daba-48f3-972d-f638c16dd0e3`, plus 518 for
generation 1 in `ube compiler conformance b96072e6-6af5-4ca1-9812-d8c99fef8ebf`.
These cover O0/O2 native behavior, repeated exact IR, malformed source,
identity guards, failed backend output preservation and recovery, including
the real timeout policy. No new runtime or third-party dependency was added.

The following records are earlier completed increments; their next-step
statements describe the handoff at that time.

## Completed qualification: concurrent compilation — 2026-11-13

The final Windows x64 one/two-worker implementation passes the concurrency
gate, successive self-build comparison and common conformance. The next existing roadmap
area is complete language and product support; no additional language feature
or architecture is selected by this handoff.

### Final acceptance evidence

All artifact directories below are under `C:\Users\Ubehage\AppData\Local\Temp`.
The final bootstrap is `ube native context 5b726a73-2fe7-48a4-865b-887e684959b6\build\UBE-Bootstrap.exe`.
Production runtime parity is 152116 bytes; 170 templates occupy 23487 bytes
(checksum 1843860); objects use only the 42 reviewed Kernel32 imports.

| Requirement | Passing evidence |
| --- | --- |
| Overlapping independent project work and simultaneous requests; exact single/two-worker IR and diagnostics | `ube concurrent compilation 30afd7ad-b7cf-4153-a352-0b8b29e31988`; both independent source baselines, repeated varied schedules, request isolation |
| Dependency/publication ordering, cancellation, worker failure and recovery | Same full gate; cancellation after real emission, simultaneous successful request, fresh FAIL with Err zero, copy-helper fault, retained-close retry, quotas, whole-artifact competing publication, native backend failure/timeout followed by recovery |
| Useful parallelism measured separately | `ube concurrent compilation 39e257c4-0c53-40d9-885a-7938c4adb51d`; idle uninstrumented trials 1/2/2/1 workers: 3939/3581/3517/3915 ms; means 3927/3549 ms, 9.63% reduction, nonoverlapping observed ranges, four identical outputs |
| Current UBE lowering and runtime dependencies | `ube native lowering 9532c629-4090-47d5-b971-a58723286aa4`; actual O0/O2 language execution, capture faults, compiler objects/imports and 54 dynamic-storage groups; focused reset/resource and runtime gates recorded below and in runtime test READMEs |
| Successive self-builds from current repository sources | `ube compiler rebuild 18c217dd-d417-4e79-b96a-198202d3613a`; both generations built by this run, source/asset bytes match repository, exact LLVM and timestamp-normalized native comparisons |
| Same positive, negative and recovery corpus | `ube compiler conformance 1a6736b3-f0fe-4d98-b9ad-fea398b150e6`: bootstrap plus generation 2, 860 assertions; `ube compiler conformance 5551e6e4-582c-4ab1-a356-0e64ebae1360`: generation 1, 446 assertions |

The measurement uses the checked frozen 51-module/722143-byte package on an
AMD Ryzen 9 3950X (32 logical processors). It includes source-to-LLVM request
work, excluding driver construction and the native backend. Output SHA256:
`8D4021512E2C1F4F4DAE9D0B560DA3358D1D8B158E5F484C52AACF5D69B81115`.
Exact measurement/correctness commands and raw-evidence locations are in
`../bootstrap/tests/concurrent-compilation/README.md`.

Final self-build and conformance commands (from the repository root):

```powershell
$seed = 'C:\Users\Ubehage\AppData\Local\Temp\ube native context 5b726a73-2fe7-48a4-865b-887e684959b6\build\UBE-Bootstrap.exe'
$initial = 'C:\Users\Ubehage\AppData\Local\Temp\ube concurrent compiler bootstrap final'
$rebuilt = 'C:\Users\Ubehage\AppData\Local\Temp\ube compiler rebuild 18c217dd-d417-4e79-b96a-198202d3613a'
rtk proxy powershell -NoProfile -File bootstrap/tools/build-compiler.ps1 -CompilerExe $seed -Destination $initial -TimeoutMilliseconds 360000
rtk proxy powershell -NoProfile -File bootstrap/tests/self-hosting/rebuild-check.ps1 -InitialCompilerExe "$initial\UBE.exe"
rtk proxy powershell -NoProfile -File bootstrap/tests/self-hosting/check.ps1 -CompilerExe "$rebuilt\generation-2\UBE.exe" -BootstrapExe $seed
rtk proxy powershell -NoProfile -File bootstrap/tests/self-hosting/check.ps1 -CompilerExe "$rebuilt\generation-1\UBE.exe" -BootstrapExe $seed -CompilerOnly
```

Every command exited zero. Host build: 13515 ms; successive self-builds:
15185 and 15977 ms. These are observed whole compiler-process times, not an
idle performance comparison. Both self-built compilers emitted exact LLVM
SHA256 `429C45BB4C65652DACFA3BE178E840061E82E83C86D52CB24ECA135610866DBE`.
Native images differed only in the four-byte COFF timestamp at offset 128;
normalizing that field alone yielded exact bytes. Conformance executed all
seven families at O0/O2, deterministic/changed-input checks, malformed/identity
guards and missing/nonzero/no-output/timeout backend preservation and recovery.

Independent final reviews covered request-private facts, immutable publication,
per-thread error/call state, heap/reference ownership, descriptor lock ordering,
resource claims, worker completion/handle ownership and backend boundaries.
Clang 23.1.3 rejects `--target=x86_64-pc-windows-msvc -fsanitize=thread -### -x c -c NUL`;
no race-detector execution is claimed. Reviewed synchronization plus bounded
real-thread tests do not establish absence of every possible race. Compound
shared updates, foreign callbacks, arbitrary concurrent context destruction,
the full coordination library and additional targets remain outside this gate.

## Historical concurrent-compilation checkpoints

The following records preserve intermediate findings and failed experiments.
Their pending-status statements describe those earlier checkpoints; the final
acceptance table above supersedes them.

Current integrated runtime identity: 152116 bytes, template catalog 170 entries /
23487 bytes / checksum 1843860. The fresh bootstrap is
`C:\Users\Ubehage\AppData\Local\Temp\ube native context 5b726a73-2fe7-48a4-865b-887e684959b6\build\UBE-Bootstrap.exe`.
Using `bootstrap/tests/native-lowering/check.ps1 -BootstrapExe <that executable>`,
the complete gate passed with exit 0 in
`ube native lowering 9532c629-4090-47d5-b971-a58723286aa4`: actual UBE O0/O2
language/system/path/process observations, capture-failure recovery, compiler
objects restricted to reviewed imports, and all 54 dynamic-storage groups.
Its worker-fault and dynamic-storage evidence are
`ube worker faults 777bebee-5f99-4ad5-9255-2176e9834f05` and
`ube dynamic storage 43525408-1323-468f-a94a-288471296401`.
The same command with `-ArrayDeclarationOnly` passed O0/O2 values, cleanup and
zero-allocation assertions in `ube array declaration 3be0c844-270d-4f8c-b25c-2b6a206153dd`
(driver `ube native lowering c1064a8d-75e7-4603-af25-812eea178479`). With
`-ResourceConcurrencyOnly`, all four eight-worker schedules passed at O0/O2 in
`ube resource concurrency eb01d4ca-4290-418a-a6d8-bfedacb0d113`
(driver `ube native lowering b8b3c429-3d39-4c00-9b1a-2da94777ab5a`).
The full integrated compiler concurrency correctness gate also passed in
`ube concurrent compilation 30afd7ad-b7cf-4153-a352-0b8b29e31988`.
All evidence directories above are under the user's temporary directory.
Final idle measurements, refreshed successive self-build/common conformance,
completion documentation and GitHub publication remain pending.

The complete corrected concurrency correctness gate now passes (exit 0), with
evidence in `ube concurrent compilation 41f66ece-9d0b-4398-81c0-dc927ebab23d`.
It includes the previously missing active-emitter cancellation, simultaneous
worker failure and successful request, independent second-source artifact
baseline, complete structured diagnostics, cleanup retry, footer quotas,
concurrent native backends and timeout followed by same-process recovery.
The command and tested limits are in
`../bootstrap/tests/concurrent-compilation/README.md`.

Performance remains an unmet acceptance requirement. The idle post-collector
run reused the checked original 51-module/722143-byte source ledger. Trials
with 1, 2, 2, 1 workers took 4022, 4735, 5059 and 4005 ms; means are 4013.5 ms
and 4897 ms, so two workers remain 22.01% slower. All four IR hashes match
`4574D383A868F2466636E2AE44EE815DBDBBB13C534ED2C91ACB87342FE4E91C`.
Evidence: `ube concurrent compilation ff13c308-eb90-4949-a5b6-73be79b53f00`.
A test-only relaxed-poll storage-lock experiment then rejected that candidate:
16 exact-output trials averaged 3941.62/4750.49 ms for original one/two-worker
drivers and 4135.92/4995.67 ms for the candidate. Evidence is
`ube storage lock experiment 61e10156-2514-40ba-82e7-5d46f920f69b`; commands and
limits are in `../runtime/tests/storage-profile/README.md`. That experiment did
not change production locking. A subsequent test-only descriptor-stripe experiment kept
heap-to-stripe lock ordering and passed focused same-descriptor contention
checks plus all 16 exact-output trials. Means were 3990.03/4776.79 ms for
original one/two-worker drivers and 4057.98/3955.08 ms for striped drivers.
Evidence: `ube storage lock experiment acae37a1-1ca1-4395-b946-51c372fa7a00`.
This removes much of the parallel penalty, but the 0.88% advantage over the
original single-worker baseline is too small to establish useful speedup.
Striping remains experimental. Per-procedure profiling reproduced the frozen
output exactly and identified 64,154,642 snapshots in 624,036 calls to
`ByteText.TryAppendInteger`; full counts are in
`ube snapshot procedures acbc72c4-005c-4996-afa0-1501f19cb6f9`.
The measured narrow optimization now carries the current negative decimal power
in one scalar and reads each private Powers entry once per digit position.
It preserves the algorithm, bounds and atomic output publication. The existing
byte-text, LLVM-format and LLVM-writing gates passed at O0/O2 with their negative
controls. Frozen-workload trials took 3928, 4666, 4455 and 3880 ms (1,2,2,1),
means 3904/4560.5 ms: two workers remained 16.82% slower. Evidence:
`ube concurrent compilation c3c831ff-cfdf-44d0-97d7-ec1959bfc100`.
Combining the cached formatter with test-only descriptor stripes also failed to
establish useful speedup: original one-worker mean 3823.29 ms versus striped
two-worker mean 3984.40 ms, 4.21% slower, across 16 exact-output trials in
`ube storage lock experiment 4e20985f-737c-42f4-9e90-9ba371c0f659`.
A candidate now passes the private
`NativeCompilation.EmitRange` catalog as ByVal, using the already qualified
array snapshot/capture semantics to give each worker an independent rendering
buffer while keeping authoritative program facts ByRef. The full correctness
gate passed again in `ube concurrent compilation 95205396-5aaf-4636-b717-0b1298181b0b`,
including O0/O2 synthetic failure of the second catalog-copy
helper after the first real worker enters. This asserts caller/capture cleanup,
preserved output and independent recovery; it does not inject native allocation
retries, which remain covered by the separate allocator gates. Comparative
timing is in progress before adoption.
The current 50-module source package, including this candidate, the ByteText
cache and the array-reset fix, passed actual UBE `--emit-llvm` through retained
generation-2 into `%TEMP%\ube private catalog planning\compiler.ll` (exit 0,
EMIT OK). Clang compiled that IR at O0/O2; `llvm-nm --undefined-only` for both
objects reported exactly the 42 imports in `compiler/llvm/kernel32.def`, with
no other helper dependency. Existing planning/frame bounds were not increased.

The private-catalog plus descriptor-stripe combination subsequently passed all
16 interleaved exact-output trials. Original one-worker mean was 3821.21 ms
(3798.00–3848.68); striped two-worker mean was 3499.33 ms (3438.13–3555.84),
8.42% faster with nonoverlapping observed ranges. Striped one-worker mean was
3909.82 ms. Root independently read the raw CSV in
`ube storage lock experiment d0c867f0-c730-4381-907a-bde46136113a`.
This justifies integration, not final acceptance: production descriptor locks
are now being placed in each program's own padded 64-stripe table, preserving
heap-before-stripe ordering and existing array/block layouts. The root context
grows by 520 cells, including a leading cache-line gap. Final regression and
uninstrumented timing must qualify this integrated runtime, which differs from
the experiment's process-global test table.
Root README/completion status and GitHub publication remain pending the full
objective.

The descriptor-lock audit also found an uncovered correctness issue:
`NativeStorage.NeutralStorage` clears a dynamic descriptor with the synchronized
runtime helper, then emits raw empty-descriptor initialization even when
`ReleaseExisting=True`. A repeated declaration of a captured dynamic local can
therefore overwrite a worker's intervening resize after the clear has unlocked.
The host boxed-array path already clears without the extra raw stores. The
focused regression reproduced failure with the old actual UBE compiler at
O0/O2: lost installed values, failed disposal and a retained allocation (exit 7).
The one-line correction returns success after ClearArray for an existing
unbounded descriptor; unpublished initialization remains unchanged. Actual UBE
lowering of the corrected source passed O0/O2, checking values 42/99, explicit
release, drain, empty registry, successful disposal and zero allocations.
The regression, exact commands and old/fixed evidence are recorded in
`../runtime/tests/array-declaration/README.md`. Full final compiler rebuild and
regression evidence must be refreshed after the remaining performance work.

The performance investigation now has a focused runtime profile. Reading
`runtime/tests/storage-profile/read.ps1 -Counts "C:\Users\Ubehage\AppData\Local\Temp\ube storage profile one\counts.bin"`
reported 1,038,729,983 collection requests and scans, 41,364,845,732 inspected
blocks, and 20,550 freed blocks. Of those scans, 1,038,712,049 reclaimed nothing;
the maximum scan visited 55 blocks. The single-worker run recorded no failed
storage-lock CAS operations. These diagnostic counters justify avoiding scans
when no block has lost its final reference; they do not establish a parallel
speedup. Instrumented elapsed times are not performance acceptance evidence.
An independent `Get-FileHash` comparison of the profile's `output-2.ll` with
the four baseline rows in `measurements.csv` confirmed the same SHA256:
`E04E6F1E1E189089040F4AD22798C56ADF4400C8F6EEED9927D6C1272682EBF2`.
The baseline evidence directory is
`C:\Users\Ubehage\AppData\Local\Temp\ube concurrent compilation 38e1d451-c37a-4bfb-94d5-f36e273423a9`.

The two-worker profile completed with exit 0 and the same output hash. Reading
`runtime/tests/storage-profile/read.ps1 -Counts "C:\Users\Ubehage\AppData\Local\Temp\ube storage profile two\counts.bin"`
confirmed 1,039,292,363 scans, 46,502,386,317 inspected blocks, 20,608 frees,
and 1,039,274,388 scans without reclamation. Collection lock acquisition had
24,080,905,232 failed CAS attempts and 227,624,655 contended acquisitions;
snapshot acquisition had 6,394,679,941 failed CAS attempts and 55,511,125
contended acquisitions. These instrumented counts support the focused change
to avoid collection scans until a final reference is released. Its source has
been reviewed and its focused/runtime regression gates passed; exact commands
and evidence are in `../runtime/tests/pending-retirement/README.md` and the
lowering results below. The subsequent uninstrumented measurements are recorded
above and still show a two-worker slowdown.

The acceptance review identified test coverage that was subsequently added: cancellation
after request emitters have demonstrably started, an injected worker failure
alongside a concurrently successful request, an independent second-request
artifact baseline, and comparison of RequestDiagnostic.Operation. Those cases
passed in the complete correctness run recorded above.

The current source closure passed
`rtk proxy powershell -NoProfile -File bootstrap/tests/self-hosting/package-check.ps1`:
275 source-packaging assertions, including refusal of a junction ancestor with
the redirected target and sentinel unchanged. Evidence:
`C:\Users\Ubehage\AppData\Local\Temp\ube self-host sources 81fe7066-ac21-46d8-acf2-4b849178ee20`.
This checks the updated package; executable self-hosting still requires the
final rebuilt compiler and common conformance corpus.

After the collector change, the fresh bootstrap at
`C:\Users\Ubehage\AppData\Local\Temp\ube native context 49f0f01f-46f9-41d6-ae3e-610eb5293a0e\build\UBE-Bootstrap.exe`
passed `rtk proxy powershell -NoProfile -File runtime/tests/callnew/check.ps1 -BootstrapExe <that executable>`.
O0/O2 assertions cover worker ownership and fresh failure, changed caller-return
scalar rejection, all 11 capture-allocation sites failing both attempts, native
startup failure, recovery after every fault, and zero live allocations.
Source evidence: `ube native workers eaee691e-1862-4953-b7b8-3ac0f203b83a`;
fault evidence: `ube worker faults 56a774c7-04db-4a14-ab18-f17d48e7de21`, both
under the user's temporary directory. Independent read-only tools passed:
`bootstrap/tools/runtime-text.ps1` (150717 bytes) and
`bootstrap/tools/llvm-templates.ps1` (170 templates, 23451 ASCII bytes,
checksum 1841488).

The complete rerun
`rtk proxy powershell -NoProfile -File bootstrap/tests/native-lowering/check.ps1 -BootstrapExe "C:\Users\Ubehage\AppData\Local\Temp\ube native context 49f0f01f-46f9-41d6-ae3e-610eb5293a0e\build\UBE-Bootstrap.exe"`
finished with exit 0 in
`ube native lowering 740621aa-d145-4021-aecd-59f4ddbdaeeb`.
It passed actual UBE-generated O0/O2 language and changed-input observations,
entry/initialization/recursion checks, system/path/namespace/process wrappers,
source CallNew capture faults and recovery, and compiler/library object checks
against the reviewed native imports with no unavailable helper dependencies.
Its final actual UBE-emitted ownership gate passed all 54 dynamic-storage groups
with zero live allocations at disposal; evidence:
`ube dynamic storage b1ee98ca-eab0-4e3b-b4b0-b9b1765a486f`.
The included worker-fault evidence is
`ube worker faults a7b734a2-a88a-4fc3-b866-a59a52d6d67d`.
These directories are under the user's temporary directory. This establishes
the updated lowering/runtime regression gate, not final compiler concurrency
or self-hosting conformance.

The compiler-emission allocation gate also passed both variants on bootstrap
49f0f01f: `bootstrap/tests/native-lowering/allocation-check.ps1 -BootstrapExe <that executable>`
qualified all 70 allocation sites at O0/O2, and the same command with `-CallNew`
qualified all 97 sites. Both include malformed-input, I/O, depth, independent
recovery and zero-live-allocation assertions. Evidence directories are
`ube lowering failures 0e2c3775-4d7d-4873-830d-4c15f4143cdb` and
`ube lowering failures 66358234-312f-4152-bbfb-3e00d4e83708` under the user's
temporary directory; full commands are recorded in the gate README.

The updated compiler built from bootstrap 49f0f01f into
`C:\Users\Ubehage\AppData\Local\Temp\ube concurrent compiler bootstrap 2\UBE.exe`
in 12749 ms. The command
`rtk proxy powershell -NoProfile -File bootstrap/tests/self-hosting/rebuild-check.ps1 -InitialCompilerExe "C:\Users\Ubehage\AppData\Local\Temp\ube concurrent compiler bootstrap 2\UBE.exe"`
then passed with exit 0. Both generations were built by that invocation, with
compiler-process times of 16438 and 16371 ms. Their manifests, verified source
ledgers and native assets match one another and current repository bytes.
Generated compiler LLVM is byte-identical, SHA256
`6A74E8612F33FE66B57B175F0A193EDFD20A8D339E5359569DC05074C7FB2E16`.
Native images differ only at byte 128 within the COFF TimeDateStamp field;
zeroing only that documented four-byte field produces identical images.
Evidence and both generation packages:
`C:\Users\Ubehage\AppData\Local\Temp\ube compiler rebuild ee02eff8-ab8e-476f-83e3-5f7d9e2e0e0f`.
These build timings are observations during regression work, not the idle
one-versus-two-worker performance measurement. The shared seed/compiler CLI
conformance command
`rtk proxy powershell -NoProfile -File bootstrap/tests/self-hosting/check.ps1 -CompilerExe "C:\Users\Ubehage\AppData\Local\Temp\ube compiler rebuild ee02eff8-ab8e-476f-83e3-5f7d9e2e0e0f\generation-2\UBE.exe" -BootstrapExe "C:\Users\Ubehage\AppData\Local\Temp\ube native context 49f0f01f-46f9-41d6-ae3e-610eb5293a0e\build\UBE-Bootstrap.exe"`
passed all 860 assertions with exit 0. It ran the same seven source families
against both compilers at O0/O2, including CallNew, deterministic IR, native
results, malformed input/identity guards and prior-output preservation after
missing, nonzero, no-output and timed-out backends. Evidence:
`C:\Users\Ubehage\AppData\Local\Temp\ube compiler conformance be739a8d-325e-48ca-b3f2-6055d22342d5`.

The owner requested the next roadmap item and authorized updating the root
README and pushing the completed work to GitHub. The goal is the full existing
concurrency gate, including overlapping intra-project work and same-process
independent requests, deterministic output, failure/cancellation isolation and
performance evidence. [CONCURRENCY.md](CONCURRENCY.md) records the source/runtime
assessment and the owner's worker-completion decision: escaping worker-entry
FAIL ends that worker normally, while ThreadWait delivers fresh FAIL on the
waiting thread. Timeout/cancellation remain normal status. The runtime and source
thread implementations are undergoing qualification. The full compiler
concurrency gate remains pending; self-hosting remains the passing baseline.

The owner subsequently clarified CallNew: ordinary Call syntax and parameter
semantics, Subs or Functions, usable both as a statement and as a LongLong
thread-ID expression. Parser/binding and documentation are being reconciled;
native thread-start emission now has capture ownership and entry-thunk
implementations in both emitters. Source-level lifetime and fault qualification
is in progress; this is not yet a completed compiler concurrency gate.

Native planning now carries request-owned escape facts and a per-symbol storage
escape flag, derived from the checked syntax/binding graph. NativeOwnership and
NativeThreads implement retained local/temporary boxes, hidden owner arguments,
typed capture cleanup and statically bound worker entry thunks. The native guard
was removed for qualification after that implementation was connected.
The command
`rtk proxy powershell -NoProfile -File bootstrap/tests/native-planning/check.ps1 -BootstrapExe "C:\Users\Ubehage\AppData\Local\Temp\ube native context 20f3aadd-b9bf-4494-b699-de49dc2d5d79\build\UBE-Bootstrap.exe"`
passed 18 cases and 9,153 assertions at each of O0/O2; the changed frame input
was rejected at exact assertion 423 at both levels. Evidence:
`C:\Users\Ubehage\AppData\Local\Temp\ube native planning 7aac5e13-2c3e-4df9-b973-a793a8fd4378`.
This checks the planning integration on the admitted serial profile, not worker
capture execution. An earlier attempt failed to link because the shared test
import helper omitted CreateThread; that explicit import is now included.

Self-host source packaging includes NativeEscapes. The command
`rtk proxy powershell -NoProfile -File bootstrap/tests/self-hosting/package-check.ps1`
passed 250 assertions, including the junction-ancestor refusal and unchanged
sentinel, with evidence in
`C:\Users\Ubehage\AppData\Local\Temp\ube self-host sources 1fcdf8db-b42f-44df-b268-6736abd56b2b`.
This is packaging evidence only; the updated compiler has not yet passed a new
self-hosting or concurrency gate.

Capture implementation must account for fixed local arrays: their existing
inline payload has no retainable block. The selected implementation gives
escaping fixed local arrays a separately owned payload, retaining the original
bounds. Indexed escape requirements must propagate back through ByRef array
parameters so the originating local receives that storage. Program-owned fixed
arrays may retain inline storage. Both emitters now implement this lifetime case,
with complete execution/fault qualification still in progress.

After integrating the ownership-aware frame accounting, the command
`rtk proxy powershell -NoProfile -File bootstrap/tests/native-planning/check.ps1 -BootstrapExe "C:\Users\Ubehage\AppData\Local\Temp\ube native workers 6e56a4fa-607e-4158-bbb8-444bb4d39224\UBE-Bootstrap.exe"`
passed 21 cases and 10,067 assertions at each of O0/O2, plus exact frame-input
mutation rejection at assertion 423. New cases distinguish escaping fixed
payloads from ordinary inline frame storage, charge the hidden array owner and
indexed pin, and charge a boxed record snapshot and its cleanup. Evidence:
`C:\Users\Ubehage\AppData\Local\Temp\ube native planning d67f092d-33c1-4768-9ce2-436db7f55481`.

The initial integrated native-lowering run passed the existing executable,
control/error and system/path/file/process observations at O0/O2, then exposed
an unavailable `__chkstk` dependency in NativeExpressions.EmitCall: its O0 frame
was 4,664 bytes. Argument preparation was extracted into a separate procedure;
the complete rerun, including source CallNew execution and fault cases, remains
in progress. The failed run's evidence is
`C:\Users\Ubehage\AppData\Local\Temp\ube native lowering 59e05d8f-0e37-4905-a201-c2679a37712d`.
No bound increase or runtime helper substitution was made.

The complete native-lowering gate subsequently passed with exit 0:
`rtk proxy powershell -NoProfile -File bootstrap/tests/native-lowering/check.ps1 -BootstrapExe "C:\Users\Ubehage\AppData\Local\Temp\ube native workers 6e56a4fa-607e-4158-bbb8-444bb4d39224\UBE-Bootstrap.exe"`.
Evidence is `ube native lowering 2e395f76-a7d8-4e9c-9ccc-0afc04a87e14` under
the system temporary directory. This includes the source CallNew cases at
O0/O2, capture allocation/startup failures with recovery, the existing runtime
observations, actual compiler objects without forbidden helpers or unreviewed
imports, and all 54 UBE-emitted dynamic-storage groups. The compiler-source
driver alone now has a measured 120-second test deadline: its preserved
60-second timeout case completed in 63.68 seconds on a controlled rerun.
Other emission-driver deadlines remain 60 seconds. The final aggregate command
passed without relying on manual continuation.

The compiler-side fault gates now pass with the current owner-aware emitter:
`bootstrap/tests/native-lowering/allocation-check.ps1` with bootstrap
`C:\Users\Ubehage\AppData\Local\Temp\ube native workers 6e56a4fa-607e-4158-bbb8-444bb4d39224\UBE-Bootstrap.exe`
passed all 70 observed allocation sites at O0/O2. The same command with
`-CallNew` passed all 97 observed sites while emitting local boxes, hidden
owners, record/array snapshots, indexed fixed-array captures, grouped
temporaries and nested worker thunks. Each variant also passed malformed input,
write/flush failures, depth boundaries, exact recovered-output hashes and zero
live allocations at disposal. Evidence directories are respectively
`ube lowering failures 4909a005-0893-4fd2-85db-5989798b19f5` and
`ube lowering failures 836f3156-cb37-4ab7-9800-856d3c3b0698` under the system
temporary directory. Runtime capture-allocation checks are separate.

An initial native compiler build at
`C:\Users\Ubehage\AppData\Local\Temp\ube concurrent compiler bootstrap 1\UBE.exe`
successfully rebuilt the 50-module compiler package into
`C:\Users\Ubehage\AppData\Local\Temp\ube concurrent compiler self 1\UBE.exe`.
The first attempt hit the build helper's 180-second deadline; both emission
chunks had completed and concatenation had begun. After that process was
confirmed terminated, rerunning the same compiler/package completed with
`BUILD OK`. This is an intermediate self-build, not fixed-point or conformance
qualification. Coordinator cleanup/diagnostic review fixes and removal of
duplicate private-chunk validation require another current-source build.
The build helper now accepts an explicit bounded `-TimeoutMilliseconds`
override (its default remains 180,000) and reports elapsed compiler-process
time; this does not change compiler/backend timeouts.

The reviewed current package subsequently built through the UBE-built compiler
at `C:\Users\Ubehage\AppData\Local\Temp\ube concurrent compiler self 3\UBE.exe`.
The exact command used `bootstrap/tools/build-compiler.ps1` with compiler
`ube concurrent compiler self 1\UBE.exe`, destination `ube concurrent compiler
self 3`, and `-TimeoutMilliseconds 360000`; it completed with `BUILD` after
182,905 milliseconds of compiler-process time. This measurement includes the
older input compiler's chunk assembly and is not the final parallel speedup
measurement. A prior `self 2` snapshot was cleanly rejected at the unchanged
128-cell frame bound after an extra replay-state assignment; extracting
PrepareReplay removed that aggregate temporary. The `self 3` source ledger
includes this correction and the private-chunk direct-copy optimization.
Current-source conformance and repeated self-build artifact comparison remain
pending. Performance trials reserve an otherwise idle window before those
heavy checks resume.

The reserved idle benchmark completed with identical IR across all four trials,
but two workers were about 25% slower than one worker on the full 51-module
compiler-plus-probe workload. Raw results are in `ube concurrent compilation
38e1d451-c37a-4bfb-94d5-f36e273423a9`; CONCURRENCY.md records the exact times,
hash and measurement scope. Useful parallelism is therefore not qualified.
A separate test-only profile is counting collection scans, reclaim work,
descriptor snapshots and storage-lock contention before any runtime optimization.
Current-source CLI conformance and final reproducible rebuilds are held while
this performance issue is resolved. Do not mark the roadmap complete or push
based only on overlap and passing correctness cases.

## Completed: runnable compiler and reproducible self-hosting

The approved "Build compiler in UBE" item passed its sequential self-hosting
gate on 2026-11-13. The VB6 bootstrap built the actual 44-module compiler;
that executable rebuilt the compiler, whose output rebuilt it again. Successive
UBE compilers emit identical LLVM and native artifacts agree after normalizing
only the documented PE timestamp. The same positive, negative and recovery
corpus passed through the bootstrap and both successive UBE outputs.
Scope and acceptance are in ../bootstrap/SELF-HOSTING.md. Concurrent compilation
is the next roadmap item; these results do not qualify concurrency or full
source-level debugging.

The initial source packaging prerequisite passes:
`rtk proxy powershell -NoProfile -File bootstrap/tests/self-hosting/package-check.ps1`
passed 245 assertions for exact source copies, deterministic order/hashes,
contained paths, explicit additional sources, refusal to replace an existing
destination and refusal through a junction ancestor with the target sentinel
unchanged. Evidence: `C:\Users\Ubehage\AppData\Local\Temp\ube self-host sources 39be4e99-e2bd-427c-80c0-b3b4261ed1b8`.
bootstrap/tools/self-host-sources.ps1 stages the current 44 modules into a
contained project because sibling Source paths and project references are not
admitted by the bootstrap. The generated manifest is written last.

WindowsArguments now supplies counted argument quoting and raw argument parsing
as ordinary Windows-library UBE. The command
`rtk proxy powershell -NoProfile -File bootstrap/tests/windows-arguments/check.ps1 -BootstrapExe "C:\Users\Ubehage\AppData\Local\Temp\ube emission scopes 6d5a8c9e-4fb3-4bfd-9f36-88882244ddca\build\UBE-Bootstrap.exe"`
passes at O0/O2: 15 exact quoting vectors and Windows OS roundtrips, ten append
refusals, 4,524 raw-parser comparisons per level against CommandLineToArgvW,
source/destination aliasing, malformed input and all observed allocation sites
with failed retries and recovery. Changed-input controls return exact 99/100;
disposal leaves zero observed live blocks. Evidence:
`C:\Users\Ubehage\AppData\Local\Temp\ube windows arguments cf89c26b-8198-40be-9c0c-7a93c9bcc33f`.
The gate diagnosed a reserved local identifier and missing Err assignment on
invalid UTF-8; both are corrected. API bounds and tested cases are in its README.

ProjectManifest supplies the bounded ordinary UBE manifest parser with retained
source spans and atomic metadata publication. The command
`rtk proxy powershell -NoProfile -File bootstrap/tests/project-manifest/check.ps1 -BootstrapExe "C:\Users\Ubehage\AppData\Local\Temp\ube emission scopes 6d5a8c9e-4fb3-4bfd-9f36-88882244ddca\build\UBE-Bootstrap.exe"`
passed 52 manifest vectors, seven decoded-value vectors and all three parser
allocation sites with failed retries/recovery at O0/O2, plus an exact
changed-input control. Evidence:
`C:\Users\Ubehage\AppData\Local\Temp\ube manifest 4c5480d7-bbc6-4064-8e48-8d56a0d79983`.
This parser does not establish physical path containment or file identity.

CommandOptions now admits the emit/build command forms through WindowsArguments.
`rtk proxy powershell -NoProfile -File bootstrap/tests/command-options/check.ps1 -BootstrapExe "C:\Users\Ubehage\AppData\Local\Temp\ube system primitives 74f4f9c9-eb02-4e20-a63e-871e3d04c435\build\UBE-Bootstrap.exe"`
passed 28 command/diagnostic vectors at O0/O2 and all 19 observed allocation
sites with failed retries, preserved request fields, recovery and zero live
blocks. Evidence: `C:\Users\Ubehage\AppData\Local\Temp\ube command options 754ae4d5-0126-43b2-b9ca-4ad2faee0d1e`.

The command-line/standard-stream dependency is qualified in both emitters.
SystemPrimitives exposes two validated roles; StandardStreams owns ordinary
bounded write progress. Both portable modules are registered in UBECore. The
updated bootstrap is:
`C:\Users\Ubehage\AppData\Local\Temp\ube system primitives 74f4f9c9-eb02-4e20-a63e-871e3d04c435\build\UBE-Bootstrap.exe`.
The system gate README records exact source and 36 fault/progress/ownership
assertions. Semantic authority passes 54 cases / 17,487 assertions per O0/O2;
all 116 formatter templates and generator controls pass. Runtime parity is
40,143 bytes with byte sum 3,203,460. Exact evidence directories under Temp:

| Gate | Evidence |
| --- | --- |
| system source | `ube system primitives c31b8269-3968-446c-bd6b-1bd9f7e704c5` |
| system fault/progress | `ube system primitives 496bb53c-1e66-4bd2-8af5-78756be305b3` |
| semantic-storage | `ube semantic storage cf81f8ae-e4c1-4fea-9ec3-e5a0104f06ac` |
| llvm-format | `ube llvm format b6588b2e-eda8-4694-bc62-9dbec5fcf412` |
| native-lowering/check.ps1 | `ube native lowering 94490b06-3821-4403-bc17-d9fbeb6e8ff5` |
| native-lowering/allocation-check.ps1 | `ube lowering failures 07d2c590-d1e1-476b-bd06-3b95a84ab8e1` |

The last two commands used `rtk proxy powershell -NoProfile -File
bootstrap/tests/<script> -BootstrapExe <updated-bootstrap>`. Whole-program
lowering passes O0/O2 including UBE-generated system wrappers, exact changed
source rejection and actual compiler/library bodies. The companion again passes
all 160 fault cases and two baselines with 64 observed allocation sites. These
snapshots precede the subsequent FileBytes read-helper extraction and pending
path roles; their later source revisions need their own regression evidence.

The three path roles (same-owner File.TryFinalPath, Path.TryFullPath and
Path.TryCompareOrdinal) are qualified. The current bootstrap is
`C:\Users\Ubehage\AppData\Local\Temp\ube path primitives 0d868d63-27a3-45a4-9e74-2f8aa888b7cd\build\UBE-Bootstrap.exe`.
The path gate README records 58 fault/boundary/owner cases, the 16-role semantic
gate passes 60 cases / 19,315 assertions per level, and all 119 formatter entries
pass. Runtime parity is 50,703 bytes, byte sum 4,055,834. Whole-program
`native-lowering/check.ps1` passed again with this binary, including UBE-emitted
path wrappers and exact changed-file rejection at O0/O2; evidence:
`ube native lowering 8c31c68e-3daa-459c-959f-02b591a02464`. This snapshot includes
the shared FileBytes read-helper extraction.

Further focused gates use `rtk proxy powershell -NoProfile -File
bootstrap/tests/<gate>/check.ps1 -BootstrapExe <path-enabled-bootstrap>`:

| Gate | Passed | Evidence directory under Temp |
| --- | --- | --- |
| windows-paths | 78 vectors per O0/O2, every measured helper allocation/retry, recovery and changed-path control | `ube windows paths e38aa247-c44c-4342-a91a-1d74cede02e0` |
| windows-images | 24 image/bounds/read/close/allocation cases per O0/O2 and changed-file control | `ube windows images bf420a5e-1d3a-479b-ad64-33448308a8c5` |

WindowsPaths keeps ordinary path policy in the Windows library and compares
complete directory prefixes through OS Unicode ordinal rules. WindowsImages
checks the existing backend's bounded AMD64 executable framing; this is neither
complete PE validation nor evidence that an arbitrary program runs correctly.

ProjectLoader now retains ordered canonical source paths and parses modules
only after containment has been checked against the same open file owner. The
`project-loading-ube/check.ps1` gate passed 15 cases and all 155 observed
allocation sites with failed retries/recovery per O0/O2. It checks real compiler
modules, ordered source bytes, junction escape without external source reads,
duplicates, diagnostic locations, incoming-owner preservation and failed-close
ownership. Changed source fails the exact unchanged assertion. Evidence:
`ube project source 12de2101-ed85-47a6-81ba-efc315f640c7`. Failed new requests
invalidate Counts and Info.SourceCount; arrays remain caller-owned scratch, not
an atomically published old project. A nonzero incoming owner is refused before
invalidating earlier request fields. Its README specifies this contract.

FileBytes.TryReadOpenBytes shares the existing read/probe loop while leaving
the owner open; TryReadAllBytes still closes before final publication. The open
reader gate passed nine cases plus both allocation sites/retries and recovery;
evidence `ube open file a47377a8-6df4-4d27-ab78-5f1dddea2af3`. The existing file-I/O
gate passed 56 groups with the system-enabled host; evidence
`ube file io 34d64f2b-84cb-4b2b-b2d2-997c894b8ba9`.

Native-tool argument construction, explicit process ownership and guarded
publication now have focused acceptance gates. The process extension
reuses the existing bounded owner layout with tagged resource kinds; file
operations must reject process owners. Process starts use a private explicit
inherited-handle list, suspended startup and job containment. Completion means
root exit plus no active descendants, not merely a successful termination call.
The final runtime has 95,098 bytes, 133 formatter templates and 41 reviewed
Kernel32 imports. Focused semantic-storage acceptance passes 77 cases and
24,535 assertions per optimization level; metadata/namespace failure acceptance
passes 88 cases. The source driver owns cleanup and protects compiler assets
and tools as well as project inputs. A cleanup failure after successful atomic
publication emits a warning; it does not relabel an already committed output
as a failed build.

The complete source requires 74,893 syntax nodes (74,894 including the VB6
project root), with a largest module of 7,748 nodes. A focused cumulative
project-capacity extension to 131,072 passed exact-limit and refusal acceptance;
the per-module limit remains 65,536. The next full build passed that boundary
and reported a controlled native-IR output limit failure. Its evidence is
`C:\Users\Ubehage\AppData\Local\Temp\ube compiler first native build`.
Complete IR measured 9,810,828 bytes and 269,156 lines. Only the line bound was
raised to 500,000; the 16 MiB byte bound remains unchanged. The LLVM writer gate
passed all 14 O0/O2 scenarios and its changed-payload control, including exact
and over-limit line and byte cases. Evidence: `ube llvm writing e261ff6b-d0f4-42c6-a1cd-dc387eeb1d17`.

The full bootstrap build and its first actual UBE self-build succeeded using
`bootstrap/tools/build-compiler.ps1`. Outputs are respectively
`C:\Users\Ubehage\AppData\Local\Temp\ube compiler bounded native build\UBE.exe`
and `C:\Users\Ubehage\AppData\Local\Temp\ube compiler self build one\UBE.exe`.
The second successive self-build also succeeded at
`C:\Users\Ubehage\AppData\Local\Temp\ube compiler self build two\UBE.exe`.
The rebuild comparison gate passed: both packages match current repository
source and asset bytes; both compilers emit identical 11,349,661-byte LLVM,
SHA256 `4B50601911EDD1CEEE88C5E6E89966F822C66F8C50209F569A3CEE511CE84ACF`.
Native executables differ at offset 128 only, within the four-byte PE COFF
TimeDateStamp field at offsets 128..131. Zeroing only that field produces
byte-identical images, SHA256
`A86BCD238FEBA41C7F6249CFAF9084C9C7C1E11F45976B6E5978E3762FABFBD1`.
No executable code or other metadata was normalized. Evidence:
`C:\Users\Ubehage\AppData\Local\Temp\ube compiler rebuild 88b30588-00d5-4f3c-b649-ffdd273efda0\report.txt`.

Exact build and comparison commands (default O2):

```powershell
rtk proxy powershell -NoProfile -File bootstrap/tools/build-compiler.ps1 -CompilerExe "C:\Users\Ubehage\AppData\Local\Temp\ube llvm writing e261ff6b-d0f4-42c6-a1cd-dc387eeb1d17\build\UBE-Bootstrap.exe" -Destination "C:\Users\Ubehage\AppData\Local\Temp\ube compiler bounded native build"
rtk proxy powershell -NoProfile -File bootstrap/tools/build-compiler.ps1 -CompilerExe "C:\Users\Ubehage\AppData\Local\Temp\ube compiler bounded native build\UBE.exe" -Destination "C:\Users\Ubehage\AppData\Local\Temp\ube compiler self build one"
rtk proxy powershell -NoProfile -File bootstrap/tools/build-compiler.ps1 -CompilerExe "C:\Users\Ubehage\AppData\Local\Temp\ube compiler self build one\UBE.exe" -Destination "C:\Users\Ubehage\AppData\Local\Temp\ube compiler self build two"
rtk proxy powershell -NoProfile -File bootstrap/tests/self-hosting/rebuild-check.ps1 -InitialCompilerExe "C:\Users\Ubehage\AppData\Local\Temp\ube compiler bounded native build\UBE.exe" -FirstGenerationDirectory "C:\Users\Ubehage\AppData\Local\Temp\ube compiler self build one" -SecondGenerationDirectory "C:\Users\Ubehage\AppData\Local\Temp\ube compiler self build two"
```

The comparison invocation explicitly reuses the two builds witnessed above;
its report does not infer predecessor provenance from file equality. Without
the reuse parameters, the same script performs both builds itself.
Actual-compiler conformance passed. The common corpus exercises six families:
returns, ordered modules, initializer/source error flow, dynamic arrays,
file ownership/bytes, and records/aliases/checked failures. Both O0/O2 native
results must return 42; changing the return fixture must change IR and return
43. Further checks cover exact success markers, located malformed-source
diagnostics, missing inputs/assets, input/hardlink preservation, missing,
nonzero, absent-output and real 30-second timeout backends, no leaked private
stages, and successful real-backend recovery. Records copy independently;
element aliases retain original storage through resize; overflow and bounds
failures preserve the assignment destination and recover through handlers.

Final evidence directories under `C:\Users\Ubehage\AppData\Local\Temp`:

| Invocation | Assertions | Evidence |
| --- | ---: | --- |
| Full CLI, bootstrap and first self-build | 620 | `ube compiler conformance 484727fb-c58e-491f-8172-43d78c40671d` |
| Full CLI, second self-build | 326 | `ube compiler conformance 981dcafe-f764-4346-b0b4-5b9dd4b83ea2` |
| Added values family, bootstrap and first self-build | 75 | `ube compiler conformance f3076943-78a8-44af-8f9b-74597a8ed53e` |
| Added values family, second self-build | 39 | `ube compiler conformance f6844a13-b541-424e-844c-7b81c1b06291` |

These 1,060 assertions include harness checks. The values family was added
after the full CLI runs and qualified separately without repeating their
timeout waits; it is now part of the default full corpus. Exact commands:

```powershell
rtk proxy powershell -NoProfile -File bootstrap/tests/self-hosting/check.ps1 -CompilerExe "C:\Users\Ubehage\AppData\Local\Temp\ube compiler self build one\UBE.exe" -BootstrapExe "C:\Users\Ubehage\AppData\Local\Temp\ube llvm writing e261ff6b-d0f4-42c6-a1cd-dc387eeb1d17\build\UBE-Bootstrap.exe"
rtk proxy powershell -NoProfile -File bootstrap/tests/self-hosting/check.ps1 -CompilerExe "C:\Users\Ubehage\AppData\Local\Temp\ube compiler self build two\UBE.exe" -BootstrapExe "C:\Users\Ubehage\AppData\Local\Temp\ube llvm writing e261ff6b-d0f4-42c6-a1cd-dc387eeb1d17\build\UBE-Bootstrap.exe" -CompilerOnly
```

Repeat each command with `-ValuesOnly` for the two recorded focused runs.
The tested executable SHA256 values are
`314A2F14BCE8ADB9EE67F6590C684D76AF2ADAD1EB0C1398D78C52DC7429F134`
and `1F2FB318A24677DA4E504003EC7311C26481CEB4DFACBFF74F001087C6023F3D`.

The final broad native-lowering gate passed all O0/O2 behavior, real compiler
and library lowering, LLVM object compilation and reviewed import checks:
`ube native lowering e8fe024b-d7cd-4f7f-b166-db031b23cfa2`. Generated process
fixture path setters were split into bounded helpers after their large literal
setters exceeded the existing O0 stack-frame policy; all supplied bytes and
process assertions remain unchanged. The companion allocation gate passed
160 fault cases and two 64-allocation baselines at O0/O2:
`ube lowering failures 4b45d766-298f-47da-a4d7-550ec1bb448a`. Its type extraction
now uses the shared resource-owner name introduced by the runtime integration.

## Completed: UBE-written native lowering

NativeLowering now privately revalidates the ordered project and emits the full
admitted bootstrap profile: checked scalar values, calls and ByRef modes,
invocation-local error flow, records/arrays/pins, primitive wrappers, module
initialization, contexts and executable entry. Output streams to a caller-owned
private stage under the existing byte/line/work limits. The caller closes or
discards that stage and uses guarded backend publication; the emitter never
publishes a destination. Contracts: ../bootstrap/UBE-LOWERING.md.

The final whole-program gate reads original source files at native runtime.
At both O0/O2 it passes 18 existing source checks, an independently checked
256-byte file roundtrip, exact changed-input exit 101, executable exit 42,
initializer dependencies and failures, depth-256 refusal/recovery, identical IR
and exact source coordinates. Actual compiler/library bodies are lowered by UBE
and compiled by LLVM at both levels; objects contain only the ten reviewed
Windows imports, with no hidden CRT or stack-probe helper dependencies.

The companion gate passes 160 fault cases and two baselines: all 64 observed
allocation sites plus failed retries, five malformed-input/asset cases, two I/O
failures and nine depth settings at each optimization level. Successful LLVM
compiles; every recovered emission matches its baseline hash. Diagnostics are
fresh and all native owners are released. Scope and exact assertions are in
../bootstrap/tests/native-lowering/README.md.

Final commands (2026-11-13):

```powershell
rtk proxy powershell -NoProfile -File bootstrap/tests/native-lowering/check.ps1 -BootstrapExe "C:\Users\Ubehage\AppData\Local\Temp\ube emission scopes 6d5a8c9e-4fb3-4bfd-9f36-88882244ddca\build\UBE-Bootstrap.exe"
rtk proxy powershell -NoProfile -File bootstrap/tests/native-lowering/allocation-check.ps1 -BootstrapExe "C:\Users\Ubehage\AppData\Local\Temp\ube emission scopes 6d5a8c9e-4fb3-4bfd-9f36-88882244ddca\build\UBE-Bootstrap.exe"
rtk proxy powershell -NoProfile -File bootstrap/tools/runtime-text.ps1
rtk proxy powershell -NoProfile -File bootstrap/tools/llvm-templates.ps1
```

Evidence directories under C:\Users\Ubehage\AppData\Local\Temp:
- Main gate: `ube native lowering 2f0ff2cf-a03a-4576-83af-0bdf3d39cc10`.
- Fault gate: `ube lowering failures 2adbba20-0fae-4f23-b5c6-4c5cb1e7ae0b`.
- Final 114-template exact-output/generator gate:
  `ube llvm format 16636bb2-302f-4762-9553-d7cb74fb52a3`.

Two measured implementation fixes were necessary. The VB6 host repeatedly
scanned all symbols/nodes for each procedure; per-scope indexes remove those
scans without increasing its ten-million-step budget. The 400-procedure
regression passes O0/O2, deterministic output and exact negative controls,
with unchanged IR for three complex corpora. The UBE emitter initially carried
constant operands and direct frame addresses across calls, causing a 10,680-byte
O0 frame in the unchanged integration bridge. Scheduling pure constants after
module ensure and stable scalar frame addresses after RHS evaluation removes
that regression. Dynamic arguments, indexed/global lvalues and pins retain
their original evaluation order. No test shim or reduced fixture was used.

Focused byte-text, LLVM writer/format, planning, scalar, context and intrinsic
gates also passed; their test READMEs retain the exact scope and commands.
The indexed host passed these existing regressions:

| Gate | Result | Evidence directory |
|---|---:|---|
| integer-types | 46 groups | `ube integer types 205c50f9-ac87-49a0-8bdb-30c8e92d1fd9` |
| aggregate-storage | 35 groups | `ube aggregate storage a179a448-b6a4-44cf-8a20-a7d144e54c11` |
| dynamic-storage | 41 groups | `ube dynamic storage 669a3029-2461-4c0c-9ab8-c18c2c5ac6f6` |
| native-compilation | 26 groups | `ube native compilation 4ffb63f9-4dbd-4425-9054-7b9abf2ec607` |
| file-io | 56 groups | `ube file io d5b4e1ab-3b11-4579-9aee-05ef9bb1b62b` |
| counted-buffers | 25 groups | `ube counted buffers b5027ffc-775c-40fe-8a9c-2b7316426f49` |

The first native-compilation regression attempt could not execute its copied
LLVM helper under the sandbox. The unchanged gate passed outside the sandbox,
including the expected missing-Clang and failed-publication cases.

## Previous handoff: a runnable self-hosting compiler (completed above)

Connect the existing UBE frontend and native lowering through the project/command
driver and guarded native backend required by the next roadmap item. Preserve
ordered multi-module loading, source diagnostics, private staging and prior
outputs on failure. Measure missing source/library dependencies before extending
the same VB6 host. Then rebuild through the UBE-generated compiler, compare
deterministic artifacts and run the same conformance corpus.

Generating compiler objects is not yet a self-build. Concurrent execution and
full source-level debugging also remain separate acceptance gates. The final
compiler's state remains caller-owned; sequential tests do not prove concurrency.

## Previous handoff: intrinsic authority and finite aggregate layout completed

PrimitiveRoles now validates all eleven admitted intrinsic signatures, metadata
targets, empty bodies and nominal array-copy identity, publishing role IDs only
at procedure declaration nodes. Ordinary names confer no primitive authority.
AggregateLayout separately computes finite record widths/field offsets and
fixed, dynamic and borrowed array sizes from revalidated declaration/expression
facts. It rejects cycles, excessive storage and malformed shape metadata.
`../bootstrap/SEMANTIC-STORAGE.md` defines APIs, result mapping and diagnostics.

Both passes use private scratch state and caller-owned atomic outputs. No new
host operation or UBECore primitive was needed. The sequential host remains
unchanged from the IDE-safe fix; final-compiler concurrent execution is still
an independent acceptance requirement.

Next implement native lowering from the checked UBE facts under
`../bootstrap/LOWERING.md` and the existing integer, aggregate, dynamic-storage
and error contracts. Resolve calls by declaration identity and validated role,
then plan frame/control/borrow slots and temporaries before emission. Logical
storage facts are not final frame offsets, a foreign ABI or proof of complete
program executability. Qualify generated programs and failure/ownership paths;
do not claim self-hosting from frontend acceptance. Measure additional source
dependencies before extending the same bootstrap.

Final semantic acceptance and allocation/depth qualification passed.
Commands use `rtk proxy powershell -NoProfile -File
bootstrap/tests/<script> -BootstrapExe <binary>` with the unchanged VB6 6.00.9782
host and Clang 23.1.3. The binary is
`C:\Users\Ubehage\AppData\Local\Temp\ube project loading dbd30a59-26f6-43b5-a9d9-e3b4c6143261\build\UBE-Bootstrap.exe`.
Evidence directories are under `C:\Users\Ubehage\AppData\Local\Temp`.

| Script | Passed | Evidence directory |
|---|---:|---|
| semantic-storage/check.ps1 | 50 cases, 16,263 assertions at each O0/O2 | `ube semantic storage 1a6965b9-bb6a-493b-a180-d8639b38bfc9` |
| semantic-storage/allocation-check.ps1 -Pass Primitive | 38 allocation/depth checks plus two baseline measurements | `ube semantic allocation ba1b2e59-ee73-4bf9-914b-51bc4b325ddb` |
| semantic-storage/allocation-check.ps1 -Pass Layout | 72 allocation/depth checks plus two baseline measurements | `ube semantic allocation 64234d5b-3b19-49d7-a836-1df9c3836f00` |
| expression-binding/check.ps1 | 60 cases, 22,697 assertions at each O0/O2 | `ube expression binding 540bc176-999b-4a1d-9371-b9b3b6295a32` |
| declaration-binding/check.ps1 | 31 cases, 19,239 assertions at each O0/O2 | `ube declaration binding a4b72661-24fc-46ee-9870-bdd150385251` |
| module-parsing/check.ps1 | 27 cases, 6,394 assertions at each O0/O2 | `ube module parsing fe191433-bff1-475e-9d9b-9b036037622a` |
| source-scanning/check.ps1 | 86 groups | `ube source scanning d5824b74-6c33-4f56-aff4-b1e9847a5380` |

The main gate includes all actual compiler/library sources, precise second-module
diagnostics, two-module storage totals, exact 128-cell/64-visit/65,536-cell limits,
malformed primitive placement and complete-but-invalid array shape subtrees.
Its changed-role negative control fails exact assertion 432. Production-only
assembly passes the hidden-stack-helper checks at both optimization levels.
Final main-gate source snapshots match the working sources. All regression
negative controls pass. A declaration gate run exceeded its unchanged 30-second
Clang compilation deadline during concurrent test load; rerunning the unchanged
gate passed as recorded above. No acceptance assertion was relaxed.

Fault injection covers all 10 observed primitive-pass allocation sites and all
27 layout-pass sites at both optimization levels. Each injected allocation and
its retry fail, older output fields survive, public count becomes zero, the
subsequent successful attempt preserves sticky Err, and final disposal leaves
zero live blocks. Depth probes at 0, 192, 224, 240, 248, 252, 254, 255 and 256
require normal success at the low boundaries and controlled refusal at the
high boundaries. Final source comparisons ignore only line-ending/trailing
blank-line normalization; no tested production logic changed afterward.

## Previous handoff: UBE expression and constant binding completed

ExpressionBinder checks references, calls, assignments, result/argument
conversions, ByRef storage, labels and conditions over retained multi-module
syntax. ConstantValues evaluates exact checked integer/Boolean constants,
including signed 64-bit extrema and intermediate-width overflow. The binder
reuses DeclarationBinder's name index and SyntaxTokens decoding. Its 15-field
per-node result publishes atomically; inputs, scratch state and outputs are
caller-owned. No VB6 host feature or UBECore primitive was added.
The API, admission limits and diagnostic codes are defined in
`../bootstrap/EXPRESSION-BINDING.md`.

Semantic depth is bounded at 64 and name-lookup work at 4,000,000. Required
cross-module constant dependencies remain explicitly unsupported; ordinary
reads of checked constants in later modules work. Recursive nominal equality
is a Boolean type fact, not a runtime-layout claim. Intrinsic declarations
receive no trusted primitive authority here. Their presence, or whole-array
replacement, conservatively invalidates reference bounds proofs.

Next implement reviewed intrinsic-role validation and finite aggregate layout
in UBE as distinct checks before lowering. Measure concrete source dependencies
before extending the existing bootstrap. Complete semantic analysis, native
generation from these new facts, self-hosting and actual concurrent execution
remain ahead.

Verification used the unchanged VB6 6.00.9782 host and Clang 23.1.3. Run
`rtk proxy powershell -NoProfile -File bootstrap/tests/<script> -BootstrapExe <binary>`
with `C:\Users\Ubehage\AppData\Local\Temp\ube project loading 4512f340-a4e4-4aaf-98c4-de2e5192b324\build\UBE-Bootstrap.exe`.
All evidence directories below are under `C:\Users\Ubehage\AppData\Local\Temp`.

| Script | Passed | Evidence directory |
|---|---:|---|
| expression-binding/check.ps1 | 60 cases, 22,697 assertions at each O0/O2 | `ube expression binding 47b8d878-83be-4ba2-b731-6c066df3c009` |
| expression-binding/allocation-check.ps1 | 48 fault/depth checks, two baseline measurements | `ube expression allocation daa221f0-e029-4454-af07-082d01fe9b90` |
| constant-values/check.ps1 | 97 vectors at each O0/O2 | `ube constant values 191526cb-bf92-4d30-a25f-20b96e0a8559` |
| declaration-binding/check.ps1 | 31 cases, 19,239 assertions at each O0/O2 | `ube declaration binding 8c481b11-1811-4a69-b8a4-40adb43b526d` |
| module-parsing/check.ps1 | 27 cases, 6,394 assertions at each O0/O2 | `ube module parsing 1b20d411-4ea0-4fd3-8bb4-7ae824a88dba` |
| source-scanning/check.ps1 | 86 groups | `ube source scanning 78d71e8a-fae9-4fb6-b5b0-2b528bb483d7` |

The expression gate includes actual compiler/library bodies, invalid programs,
independent projects, malformed pools and exact changed-input rejection at
assertion 759. Production-only O0/O2 assembly checks exclude hidden reliance
on the large test driver's stack helper. Fault injection covers all 15 observed
allocation sites, preserves all older result fields, retries successfully and
returns live allocations to zero after disposal. Depth probes cover 0 through
256 at selected boundaries. The constant and regression gates also pass their
changed-input negative controls. These tests qualify frontend facts and failure
handling; they do not execute user programs from the new bound representation.

## Previous handoff: UBE declaration binding completed

ProjectSyntax now retains ordered modules in caller-owned flat source/token/node
pools; DeclarationBinder collects scoped declaration identities and resolves
declared scalar/nominal types, signatures and executable entry identity.
Forward, self- and mutually referencing Types resolve as nominal graph edges.
This establishes declaration facts, not recursive runtime layout or complete
program validity. No new VB6 host feature or UBECore primitive was required.
Contracts and APIs are in `../bootstrap/DECLARATION-BINDING.md`.

The earlier parser corpus measured 1,203 host-bound symbols and 18,008 nodes.
The new component keeps the existing 16,384-symbol boundary, qualified at its
exact limit. Project pools allow 128 modules, 1 MiB total bytes, 262,144 tokens
and 65,536 nodes under the existing 64 MiB heap quota. These independent bounds
do not promise simultaneous maximum allocation. No mutable global compiler
state was introduced; actual concurrent execution remains a separate gate.

Next implement expression/reference binding and checked constant evaluation
over the retained declarations. Measure any additional source dependencies
before extending this same bootstrap. Primitive authority, aggregate layout and
lowering remain distinct responsibilities. The current pass deliberately
accepts an unresolved call in a body because body expression validation belongs
to the next pass; do not represent declaration success as full ANALYZE OK.

The final production sources pass the following native gates using the unchanged
VB6 6.00.9782 executable and Clang 23.1.3:
`C:\Users\Ubehage\AppData\Local\Temp\ube project loading 4512f340-a4e4-4aaf-98c4-de2e5192b324\build\UBE-Bootstrap.exe`.
Run each with `rtk proxy powershell -NoProfile -File
bootstrap/tests/<script> -BootstrapExe <binary>`.
Evidence directories below are under `C:\Users\Ubehage\AppData\Local\Temp`.

| Script | Passed | Evidence directory |
|---|---:|---|
| declaration-binding/check.ps1 | 31 cases, 19,239 assertions at each O0/O2 | `ube declaration binding e7baceb5-9831-46c6-b6c3-550199867ce4` |
| declaration-binding/allocation-check.ps1 | 34 allocation/depth checks | `ube binder allocation fc834448-1d00-4331-b0e9-84647d98ab22` |
| declaration-binding/append-check.ps1 | 56 allocation/depth/corruption checks | `ube project append c3b617ff-dc8b-45c7-9541-528cc7ffc2f5` |
| declaration-binding/handler-scope-check.ps1 | O0/O2 success and exact negative control | `ube handler scopes fc10a9cf-046d-4eca-81e4-fdc45c6ff82f` |
| module-parsing/token-check.ps1 | 4 native runs, 929 tokens, 34 comparisons | `ube syntax tokens 43b0917a-e2fe-4a95-83f8-e0fb1c8690ff` |
| module-parsing/check.ps1 | 27 cases, 6,394 assertions at each O0/O2 | `ube module parsing 5c2eb740-b7e1-4f83-b1f0-d62a773ef05a` |
| source-scanning/check.ps1 | 86 groups | `ube source scanning 254f8b82-dec8-4cec-a24b-9369064e3a67` |

The main gate checks real compiler/library declarations, identity/scopes,
visibility, parameter/field ordering, entry selection, nominal recursive graphs,
original second-module diagnostic coordinates, repeatability and isolation.
It accepts exactly 16,384 symbols and rejects 16,386 with the symbol-limit
diagnostic. Invalid spans/windows/package names and parent/sibling cycles fail
without replacing older results. Changing Friend to Public fails exact assertion
814. Production-only assembly at both optimization levels has no dependency on
the test driver's stack-page helper.

The binding fault gate fails all eight allocation sites (including retries),
preserves all 16 old symbol fields, resets public count/entry and then retries
successfully. Native depth refusal is tested through depth 256. The append gate
fails all nine scanner/parser/arena allocation sites, tests depth refusal and ten
metadata corruptions, and injects failure after writing new byte/token tails:
every committed prefix/count remains unchanged. All disposal checks require
zero remaining live allocations. The four-million lookup-work guard remains
defensive; its exact threshold is not separately qualified.

The owner's handler-scope observation is now explicit in the normative/error/
lowering contracts and manual: each invocation, including recursion, owns
default-initialized handler state. A callee does not inherit or modify the
caller's handler; returning needs no On Error GoTo 0. Err remains separate.
The focused native gate proves caller/callee reset isolation, active recursive
handlers, default recursive entry, return without reset and shared sticky Err;
changing volatile recursion depth fails exact assertion 23. No runtime change
was needed.

Documentation static validation:
`rtk proxy powershell -NoProfile -File docs/assets/tools/validate-docs.ps1`
passed 274 pages. Local Firefox file renders of the two changed handler pages
passed the readable-prose/no-overlap/local-CSS/Copy-control checklist.
Screenshots: `ube handler docs 2aff2cc6-adb0-4966-8ed6-5b697490a55c/errors.png`
and `on.png`. Literal link clicks, clipboard and accessibility were not tested.

After local completion, the owner requested committing and pushing this increment
to GitHub main, including the owner's README edits.

## Previous handoff: UBE module parsing and source storage completed

The UBE-written scanner, token helpers and parser now construct caller-owned
syntax trees for the admitted bootstrap module profile, including their own
source. This is parsing, not self-hosted compilation. Binding, semantic layout
and code generation still use the VB6 bootstrap. Recursive Type references are
covered as syntax only; their runtime layout remains pending.

Source and array capacity is now 1,048,576 bytes/elements, with 65,536 tokens and
nodes, syntax depth 48, and bounded 65,536-byte file transfers. The 64 MiB live
heap, 4,096 live allocations, 256 runtime frames and 4,096-byte path bound remain.
Candidate trees publish only on success; failures preserve previous node storage
and reset public count/root. See `../bootstrap/MODULE-PARSING.md`.

Next measure project/module ownership and symbol-storage requirements for
UBE-written name resolution and type checking. Preserve ordered multi-module
input and caller-owned state; extend the existing bootstrap only for concrete
requirements. Managed String storage, general Unicode identifiers, preprocessing,
assembly payloads, recursive runtime layout and self-hosting remain pending.

Final acceptance binary (VB6 6.00.9782; native tests use Clang 23.1.3):
`C:\Users\Ubehage\AppData\Local\Temp\ube project loading 4512f340-a4e4-4aaf-98c4-de2e5192b324\build\UBE-Bootstrap.exe`.
Commands use `rtk proxy powershell -NoProfile -File
bootstrap/tests/<gate>/check.ps1 -BootstrapExe <binary>`, except project-loading
builds the binary without that argument. Evidence directories below are under
`C:\Users\Ubehage\AppData\Local\Temp`.

| Gate | Passed | Evidence directory |
|---|---:|---|
| Project loading | 54 | `ube project loading 4512f340-a4e4-4aaf-98c4-de2e5192b324` |
| Module parsing | 27 cases, 6,394 assertions at each O0/O2 | `ube module parsing f152048d-87a9-4e2b-b79d-baa2ee3b88eb` |
| Source storage | 16 | `ube source storage 2d484b1d-fb3e-41ca-9eb0-e6c0cb074333` |
| Source parsing | 37 | `ube source parsing 0272c5bc-4187-4662-8099-5e6abfb55ad2` |
| Source semantics | 76 | `ube source semantics f1a0f639-e030-437e-aea5-3967096a7494` |
| Native compilation | 26 | `ube native compilation 10609a69-eeaa-4eec-8a92-80f94f04105c` |
| Integer types | 46 | `ube integer types b79ba4b0-0c7f-4c52-9ef5-d595f2eca8d7` |
| Aggregate storage | 35 | `ube aggregate storage a37cee3b-10e2-45a0-96ae-309a3e890720` |
| Counted buffers | 25 | `ube counted buffers e076dccb-c235-4b25-b369-24673cfc96d4` |
| Dynamic storage | 41 | `ube dynamic storage 2657f309-ee5c-44d4-8293-9b2d4b0cff99` |
| File I/O | 56 | `ube file io e38e48f3-b7a3-4e56-9e53-21401f5c5561` |
| Source scanning | 86 | `ube source scanning 43e03795-4ad7-4c6f-8fa3-d7090b5fdf3b` |

Companion scripts use the same command and binary, replacing `check.ps1`:

| Script | Passed | Evidence directory |
|---|---:|---|
| module-parsing/token-check.ps1 | 4 native groups, 929 tokens | `ube syntax tokens b1c6fa71-17d1-4473-abd6-60764bbc9829` |
| module-parsing/allocation-check.ps1 | 26 | `ube parser allocation 254cc188-7518-4d37-8687-ceeed368d2a9` |
| source-scanning/allocation-check.ps1 | 42 | `ube scanner allocation 2ec3087c-0826-42ed-a245-808f45b0fab5` |
| source-scanning/syntax-check.ps1 | 13 | `ube scanning syntax 2e85da1b-be12-4779-bebf-f67c6f059421` |
| source-scanning/utf8-check.ps1 | 37 assertions at O0/O2 and negative control | `ube utf8 widths 9f3c232b-18e0-4935-9729-f1701bb8ef5f` |

Parser assertions cover tree links/reachability, source spans, independent trees,
precedence, declarations, calls, control flow, malformed tokens and bounded
nesting. The changed-source negative control fails the exact expected assertion.
Allocation tests inject failure at all three growth allocations and publication,
then verify preserved storage, released temporaries and successful retry. Depth
tests terminate under deadlines with complete or preserved output. Separate
production-only O0/O2 assembly checks exclude a hidden stack-probe dependency.
Source-storage tests cover real large files, transfer boundaries and quota
rejection; previous storage, alias, error-handler and file gates still pass.

Documentation: `rtk proxy powershell -NoProfile -File
docs/assets/tools/validate-docs.ps1` passed 274 pages. Local headless Firefox
rendering checked changed file-limit prose/table readability, intact layout and
loaded CSS/Copy controls; the Intrinsic link destination resolves. Screenshot:
`ube parser docs 91da26cf-5b8d-40e6-b9f2-0cdd4426a0be/files.png`.
Literal clicks, clipboard operation and accessibility were not tested.

## Previous handoff: source-scanning dependency completed

The owner requested completing the next dependency and pushing the result to
GitHub. Scope is `../bootstrap/SOURCE-SCANNING.md`: Do loops, subtraction,
Or/Not, and actual UBE scanning of retained UTF-8 bytes. The owner approved
skipping the complete If/Do construct when its condition fails; existing label
and active-handler behavior applies. Resume syntax remains deferred.

The actual UBE scanner and portable UTF-8 helper pass their native acceptance
gates. `bootstrap/tests/source-scanning/check.ps1 -BootstrapExe <binary>` passed
82 groups: real file reads, all seven token fields, byte/UTF-16 positions, BOM,
continuations, exact malformed-input diagnostics and 4,096-byte/token bounds.
It scans the checked-in Arithmetic example and rejects an actual on-disk token
kind change. The control-flow source returns exactly zero at O0/O2 and exactly
22 for the changed runtime input. Evidence:
`C:\Users\Ubehage\AppData\Local\Temp\ube source scanning 438c8180-d538-422c-8f15-28e6c0bc3616`.

Next measure syntax-tree construction and source-storage requirements for the
UBE-written parser, including support for real compiler modules beyond the
current 4,096-byte input bound. Managed String storage, general Unicode
identifiers, preprocessing, assembly payloads and self-hosting remain pending.
The scanner uses caller-owned state without mutable global source/token state;
actual concurrent compilation still requires the separate acceptance gate.

Current acceptance binary (VB6 6.00.9782):
`C:\Users\Ubehage\AppData\Local\Temp\ube project loading f9237060-f7de-4aee-a644-89756badbc2b\build\UBE-Bootstrap.exe`.
The source-scanning extension adds no further host changes after this build.
Existing gates ran with `rtk proxy powershell -NoProfile -File
bootstrap/tests/<gate>/check.ps1 -BootstrapExe <binary>`; project-loading built
the binary without that argument. Evidence directories are under
`C:\Users\Ubehage\AppData\Local\Temp`:

| Gate | Passed | Evidence directory |
|---|---:|---|
| Project loading | 54 | `ube project loading f9237060-f7de-4aee-a644-89756badbc2b` |
| Source parsing | 37 | `ube source parsing 70439a03-c801-4cb1-be10-13b69befc827` |
| Source semantics | 76 | `ube source semantics 0fa0da46-d5fd-43ec-a44f-665c16e74228` |
| Native compilation | 26 | `ube native compilation 8487ed45-dac3-4ea4-ab67-9e33702d5014` |
| Integer types | 46 | `ube integer types 04ffd3c7-32d3-4b0a-ae1c-9ece3db27784` |
| Aggregate storage | 35 | `ube aggregate storage 111e2ed9-af51-4bd0-9cf7-973baf2aeade` |
| Counted buffers | 25 | `ube counted buffers 1194374a-2e79-4167-a2f8-c084996f07d6` |
| Dynamic storage | 41 | `ube dynamic storage 2c026fb2-e28d-45d3-85e7-8a4448ce93c4` |
| File I/O | 56 | `ube file io 510acca6-ffa1-4595-af3a-749d7b77939a` |

`bootstrap/tests/source-scanning/syntax-check.ps1 -BootstrapExe <binary>` passed
13 focused parser/binder cases, including exact constant values and located
negative diagnostics. Evidence: `ube scanning syntax
749b73db-1e82-4bb2-ba46-c9e68232e847`. The obsolete native rejection of potentially
failing If was replaced by exact successful/failed-condition execution at O0/O2;
other rejection and output-preservation assertions remain intact.

`bootstrap/tests/source-scanning/utf8-check.ps1 -BootstrapExe <binary>` passed
37 ordinary UBE source assertions at O0 and O2, plus a negative volatile-input
control rejected at exact case 1. This checks strict scalar encodings, widths,
overlong/surrogate/out-of-range/truncated sequences, invalid offsets and array
bounds, zeroed failure widths and preserved Err on success. Evidence:
`ube utf8 widths f7455e6a-0e4e-471c-9c8a-aca894504e76`.

`bootstrap/tests/source-scanning/allocation-check.ps1 -BootstrapExe <binary>`
passed 42 checks at O0/O2. Four injected allocation stages each fail both
allocation/retry attempts: initial token growth, expanded growth, final shrink
and publication copy. Count remains zero, all seven prior sentinel token
fields survive, Err is 7, and the successful retry preserves that sticky Err.
Allocation observations assert two retained owners before disposal and zero
live allocations afterward. Depths 249 through 256, with quoted and ordinary
source, complete within the five-second deadline; positive and negative source
lower bounds reject before publication. Evidence:
`ube scanner allocation 0c47b7d3-e816-4da9-b988-cd4b42f49150`.
The final run also requires one-based UTF-16/line/column coordinates whenever
an entered scanner call publishes a failure diagnostic.

Review found that default continuation could swallow a failed helper call and
prevent cursor advancement near the call-depth limit. Scanner helpers now
explicitly propagate fresh language failures to the public status/diagnostic
boundary. The boundary writes its emergency diagnostic without another helper
call, so reporting does not require an extra call-depth slot. The depth gate
above covers that correction.

Public-manual reconciliation updated Errors, Do, Loop and Resume. The command
`rtk proxy powershell -NoProfile -File docs/assets/tools/validate-docs.ps1` passed
274 HTML files. Headless Firefox rendered the four changed pages through file
URLs using isolated temporary profiles. Inspection confirmed readable changed
prose, intact headings/code blocks, local styles and Copy-button initialization;
the new links resolve to the rendered Errors/Do pages. Evidence:
`ube scanner docs 2668e63c-0386-422d-9e43-b103252c8c3f`. Click/clipboard and full
accessibility behavior were not retested; no interactive code changed. Resume
remains explicitly specified but unsupported by the bootstrap.

## Completed dependency: counted file input/output

The completed bootstrap dependency is documented in `../bootstrap/FILE-IO.md`.
The surviving normative File.* signatures were compared with the two removed
contracts at revision 1376e39f. No historical implementation or passing test
claim has been restored. The owner approved both decisions: exclusive writable
file creation through File.TryCreateNew, and bounded byte packing for the
current i64-cell Byte representation. The final file-I/O gate passed 56 groups.

Read/open/close and write/flush signatures fit the current intrinsic attribute
mechanism without parser or binding-dump changes. Runtime alias checks must
compare actual scalar output addresses before writing them. Current arrays
admit at most 4,096 elements, so actual transfer spans are bounded by that
capacity even though the historical role ceiling is 65,536 bytes. Ordinary
UBECore TryReadAllBytes and TryWriteAllBytes implement progress, cleanup and
publication policy. Process.TryArgument, text decoding, general file syntax
and actual concurrent I/O remain outside this increment.

Next measure practical source-scanning requirements, including the operators,
loop forms and text handling needed by the UBE-written lexer and parser. Extend
the same pipeline under the existing bootstrap-dependencies item; file I/O alone
does not establish a self-hosting compiler.

Final native acceptance: VB6 6.00.9782 built
`C:\Users\Ubehage\AppData\Local\Temp\ube project loading 65843f86-7ee9-407b-8748-8d5ad6d40320\build\UBE-Bootstrap.exe`.
The following existing gates passed against that same executable, using
`rtk proxy powershell -NoProfile -File bootstrap/tests/<gate>/check.ps1
-BootstrapExe <executable>` (project-loading built it without that argument).
Evidence directories below are under `C:\Users\Ubehage\AppData\Local\Temp`:

| Gate | Passed | Evidence directory |
|---|---:|---|
| Project loading | 54 | `ube project loading 65843f86-7ee9-407b-8748-8d5ad6d40320` |
| File I/O | 56 | `ube file io 71990967-6774-46fe-a1a5-56978319903d` |
| Aggregate storage | 35 | `ube aggregate storage d923f23c-ee39-428d-b26d-9940510759c7` |
| Counted buffers | 25 | `ube counted buffers ddf7661b-8357-4e37-984e-fffd7f44fbe0` |
| Dynamic storage | 41 | `ube dynamic storage 05a3a221-463a-4bc5-b047-976e081334ea` |
| Integer types | 46 | `ube integer types 27d74113-7e10-4957-9a34-6d5ab496ccb5` |
| Native compilation | 23 | `ube native compilation f02956a8-c5c9-4817-84e2-9836d98e404a` |
| Source semantics | 76 | `ube source semantics 4715a1f1-e0b3-4158-8044-56cb1bbdf9b0` |
| Source parsing | 37 | `ube source parsing e2569044-c2be-4a08-af68-09550b6e38c3` |

The exact new-gate command was:

```powershell
rtk proxy powershell -NoProfile -File bootstrap/tests/file-io/check.ps1 -BootstrapExe 'C:\Users\Ubehage\AppData\Local\Temp\ube project loading 65843f86-7ee9-407b-8748-8d5ad6d40320\build\UBE-Bootstrap.exe'
```

It checks actual UBE source at O0/O2, independent bytes on disk, empty/full
4,096-byte files, partial progress, EOF/growth, zero-write rejection, read
failure preservation, exclusive creation, sticky Err, exact signature binding,
invalid output aliases and explicit cleanup before Raise. Fault injection
observes real calls and allocations, including one-failure retry and primary
Err 7 surviving cleanup Err 57 with a retained token. All native scenarios
require balanced file owners and allocator blocks after successful disposal.
The 64-owner registry limit, slot reuse, stale/foreign tokens and refusal to
dispose live files are exercised. The unchanged generated program also passes
the production --build/link/entry path; repeating creation preserves prior bytes.
Changed runtime input must invalidate the oracle.

Executed packing/unpacking stores are counted: the short-write case packs
4,810 bytes while ultimately writing a 256-byte result, so no zero-copy cost
claim is made. Each file owns a 12,296-byte scratch payload charged at 16,384
bytes, and transfers allocate no new scratch. The process-wide token counter's
exhaustion and actual concurrent I/O are explicitly untested; sequential gates
do not qualify thread safety or full language memory/foreign interfaces.

Documentation validation: `rtk proxy powershell -NoProfile -File
docs/assets/tools/validate-docs.ps1` passed 274 HTML files. The browser-control
service was unavailable, so installed Firefox 159.0.1 rendered the two changed
pages directly from file URLs using isolated temporary profiles and
`--headless --no-remote --screenshot --window-size 1440,4500`. Exit zero and
screenshot existence were asserted. Visual inspection checked the qualification
text, failure table, counted-file section and local styles; reciprocal relative
link targets were asserted and both destination files rendered successfully.
Evidence: `C:\Users\Ubehage\AppData\Local\Temp\ube file docs 6590a904-2a7b-485b-bdfc-1330128432ef`.
Clipboard interaction and literal link clicking were not exercised; no shared
interactive code changed. This scoped check does not qualify the entire manual.

## Host error-handler correction — 2026-11-10

BootstrapMain's Unexpected handler now resumes at a separate reporting label
before enabling On Error Resume Next. This leaves VB6's active handler so a
second error during diagnostic output is suppressed and the process exits 1.
`rtk proxy powershell -NoProfile -File bootstrap/tests/host-error-recovery/check.ps1`
passed four synthetic cases using the actual Main recovery tail: the old tail
lets a reporting error escape to the test caller (exit 77), while the corrected
tail exits 1 both with and without that second error. Evidence:
`C:\Users\Ubehage\AppData\Local\Temp\ube host error recovery c0a7e73e-52f8-41f5-8e65-1d0c2da66e5c`.
`rtk proxy powershell -NoProfile -File bootstrap/tests/project-loading/check.ps1`
rebuilt the full bootstrap with VB6 6.00.9782 and passed all 54 loader/CLI cases;
evidence directory: `ube project loading 55c35d11-b8d7-4af1-a9f3-a589115ae7cd`.

## Current handoff: growing arrays and retained element aliases

The owner approved keeping original element storage alive through a call when
an array is resized or replaced. The completed storage increment admits dynamic rank-one
scalar/finite-record arrays, Array.TryResize/TryCopy and independent array
assignment with changed bounds. The scope is `../bootstrap/DYNAMIC-STORAGE.md`.
The dynamic gate passed 41 groups, including allocation retry, owner/borrow
release, prepared-address failure paths and the real charged-byte quota at
O0/O2. ReDim/Erase syntax and managed fields remain later dependencies.
Minor unspecified details follow VB6 only where
consistent with the already defined UBE behavior and architecture.

Next measure counted file input/output and practical source-scanning needs
under the existing bootstrap-dependencies roadmap item. Growing bytes and
token records are demonstrated; managed text, broader aggregate ownership,
loops, library packaging and the UBE-written compiler remain unfinished.

### Dynamic-storage verification — 2026-11-10

VB6 6.00.9782 built the final executable using the dynamic-storage runner.
Clang 23.1.3 compiled generated native programs at O0/O2. All commands below
used the same final executable; the native backend gate requires execution
outside the sandbox because its isolated copied LLVM import tool is otherwise
denied access. No VB6 administrator-mode change was needed by this increment.

```powershell
rtk proxy powershell -NoProfile -File bootstrap/tests/dynamic-storage/check.ps1
$verifiedBootstrap = 'C:\Users\Ubehage\AppData\Local\Temp\ube dynamic storage cd871c2d-4cb0-40d5-aa6e-22bed7b6fd84\build\UBE-Bootstrap.exe'
rtk proxy powershell -NoProfile -File bootstrap/tests/dynamic-storage/check.ps1 -BootstrapExe $verifiedBootstrap
rtk proxy powershell -NoProfile -File bootstrap/tests/aggregate-storage/check.ps1 -BootstrapExe $verifiedBootstrap
rtk proxy powershell -NoProfile -File bootstrap/tests/counted-buffers/check.ps1 -BootstrapExe $verifiedBootstrap
rtk proxy powershell -NoProfile -File bootstrap/tests/integer-types/check.ps1 -BootstrapExe $verifiedBootstrap
rtk proxy powershell -NoProfile -File bootstrap/tests/native-compilation/check.ps1 -BootstrapExe $verifiedBootstrap
rtk proxy powershell -NoProfile -File bootstrap/tests/source-semantics/check.ps1 -BootstrapExe $verifiedBootstrap
rtk proxy powershell -NoProfile -File bootstrap/tests/source-parsing/check.ps1 -BootstrapExe $verifiedBootstrap
rtk proxy powershell -NoProfile -File bootstrap/tests/project-loading/check.ps1 -BootstrapExe $verifiedBootstrap
```

Evidence directories below are under `C:\Users\Ubehage\AppData\Local\Temp`:

| Gate | Passed | Evidence directory |
|---|---:|---|
| Dynamic storage | 41 | `ube dynamic storage db0f711b-c22d-409d-b303-06d8ccb9e958` |
| Aggregate storage | 35 | `ube aggregate storage 686642c7-c424-4926-9682-2978ece9fc13` |
| Counted buffers | 25 | `ube counted buffers 59a1e48a-6074-40ea-ab76-698c585fb38f` |
| Integer types | 46 | `ube integer types b8851084-de8b-4969-a219-90eff3f73f03` |
| Native compilation | 23 | `ube native compilation cd9df334-498c-43c6-8110-a9cf1938293f` |
| Source semantics | 76 | `ube source semantics 0b1ffc68-cc0e-43a2-9b29-9723421966d0` |
| Source parsing | 37 | `ube source parsing d337e006-5635-4a6d-8a48-af94213b3eaf` |
| Project loading | 54 | `ube project loading 34b67cbc-600a-43cb-a675-7d396cc98a40` |

The aggregate count changed from 38 to 35 because three rejection cases are
now admitted: dynamic declarations, different-bound copies and unknown-bound
copies. Positive coverage lives in the dynamic gate. Its fixtures cover actual
UTF-8 bytes and token records, index-intersection preservation, neutralization,
independent copies, prepared aliases across later arguments/callee/RHS changes,
abandonment, local cleanup and zero live allocations after disposal. Target
fault injection checks retry and failed-release recovery without production
test flags. The 64 MiB quota includes allocation headers and page rounding;
the 4,096-live-block quota is implemented but not exhausted by this suite.

The first aggregate run exposed accumulated per-expression borrow slots;
statement-lifetime slot reuse fixed the frame regression. The backend deadline
probe now checks elapsed time and the precise timeout diagnostic, preventing
an earlier import-tool failure from falsely passing that assertion.

## Previous dependency: counted buffer operations and UBECore source

The completed dependency increment adds exact Intrinsic declaration binding for
Array.Length and Memory.CopyBytes, and ordinary UBECore AppendBytes source.
The boundary is `../bootstrap/COUNTED-BUFFERS.md`; its acceptance gate is
`../bootstrap/tests/counted-buffers/check.ps1`. The operations use existing
fixed arrays without allocation and preserve the specified distinction between
usable primitive False and language FAIL. The subsequent dynamic increment
implements the ownership and alias decision recorded above.

The resize/alias boundary is now owner-approved as described above. Counted
file I/O and text remain further dependencies after growing buffers.

## Previous dependency: bounded source buffers and finite records

The latest dependency increment adds finite scalar-field Type records and fixed
rank-one arrays, including arrays of records, checked field/index access,
ByRef borrowing and independent record/same-known-bounds array copies.
`../bootstrap/AGGREGATES.md` defines the admission boundary. The source fixture
retains and traverses bytes and token/tree records, with failure and copy
assertions at O0/O2. Dynamic resizing, managed text, array fields and aggregate
value-call/result paths remain explicit later dependencies. This work extends
the existing pipeline and does not implement new loop-header semantics.

The completed incremental bootstrap dependency is Byte, Integer and LongLong
storage, parameters and results, including checked conversions and authoritative
integer suffixes. `../bootstrap/DEPENDENCIES.md` records the evidence from the
existing pipeline and the remaining array/text/library prerequisites. The
existing parser, semantic pass and emitter were extended, retaining all earlier
error-flow and multi-module gates. The new gate is
`../bootstrap/tests/integer-types/check.ps1`.

Next measure growing source/token buffers and counted input/output, including
the dynamic storage and text capabilities needed by actual compiler source,
then admit those dependencies incrementally under the existing development plan. The complete
UBE-written compiler and its self-hosting subset are not yet established.

Owner clarification, 2026-11-10: the final UBE-written compiler must be
multithreaded and all compiler code thread-safe. The bootstrap may remain
sequential. Apply explicit ownership and synchronization from the first UBE
compiler implementation; do not postpone this architecture until IDE work.
The development plan and ACCEPTANCE.md now state the requirement and its
pending concurrency gate. Current bootstrap evidence does not verify concurrency.

The owner authorized the restart sequence in
`../project-docs/Development-Plan.md`. The planned scalar source boundary is
`../lang-doc/bootstrap-profile.md`; exact gates are in [ACCEPTANCE.md](ACCEPTANCE.md).
The error contract is reconciled in the normative documents and affected public
articles. `rtk proxy powershell -NoProfile -File docs/assets/tools/validate-docs.ps1`
passed for 274 HTML files; browser verification and source-example execution
remain unverified. Remaining boundary choices are tracked
in `../project-docs/Error-Handling.md` rather than inferred during coding.

The repository-owned VB6 bootstrap now loads `.UBE` projects and retains
multiple source modules in manifest order in a caller-owned ProjectContext.
The owner explicitly requires this from the outset. No separate single-file
compiler precedes it.

The bounded lexer/parser retains syntax trees, and the semantic pass now
resolves symbols, checks scalar types and constants, validates Main and binds
the trusted error-support declarations described in `../bootstrap/SEMANTICS.md`.
The emitter now lowers those bound trees into LLVM and the bounded backend
builds Windows x64 executables. Actual SourceOracle.bas execution qualifies
the approved scalar FAIL protocol. Conversions, argument modes, exact constants
and trusted declaration roles feed lowering directly; behavior is not inferred
from fixture names or ordinary user procedure spellings.

Next follow the existing development-plan item **Extend bootstrap dependencies**:
measure the UBE-written compiler's required source/storage/library dependencies,
then extend and test the admitted profile incrementally. Byte/Integer/LongLong
storage and bounded arrays/records are now implemented; text, dynamic storage,
broader loops and explicit library I/O
remain candidates in the profile, not an all-at-once implementation. Self-hosting and
full-language support remain incomplete.

Adaptive context inference, assembly lowering and compound-header failure
continuations are outside this first implementation. The runtime inventory in
`../std-lib/INVENTORY.md` remains a planning input, not a support claim.

## Counted-buffer and UBECore gate

On 2026-11-10, this command built the final compiler with VB6 6.00.9782 outside
the sandbox and passed all **37 parser cases**:

`rtk proxy powershell -NoProfile -File bootstrap/tests/source-parsing/check.ps1`

Build and parser evidence:
`C:\Users\Ubehage\AppData\Local\Temp\ube source parsing b6c7eb7c-7edc-4625-877a-d1fa56158962`.

The following commands passed on that same unchanged executable:

```powershell
$verifiedBootstrap = 'C:\Users\Ubehage\AppData\Local\Temp\ube source parsing b6c7eb7c-7edc-4625-877a-d1fa56158962\build\UBE-Bootstrap.exe'
rtk proxy powershell -NoProfile -File bootstrap/tests/counted-buffers/check.ps1 -BootstrapExe $verifiedBootstrap
rtk proxy powershell -NoProfile -File bootstrap/tests/aggregate-storage/check.ps1 -BootstrapExe $verifiedBootstrap
rtk proxy powershell -NoProfile -File bootstrap/tests/integer-types/check.ps1 -BootstrapExe $verifiedBootstrap
rtk proxy powershell -NoProfile -File bootstrap/tests/native-compilation/check.ps1 -BootstrapExe $verifiedBootstrap
rtk proxy powershell -NoProfile -File bootstrap/tests/source-semantics/check.ps1 -BootstrapExe $verifiedBootstrap
rtk proxy powershell -NoProfile -File bootstrap/tests/project-loading/check.ps1 -BootstrapExe $verifiedBootstrap
```

Evidence directories under `C:\Users\Ubehage\AppData\Local\Temp`:

- `ube counted buffers 4334e8d5-f25d-45a1-9f0a-ca00fa925fe5`: **25 groups**.
- `ube aggregate storage 00cd26b0-fb9b-4eec-afa5-f9e045c5f64a`: **38 groups**.
- `ube integer types 5d1ad42b-daad-4de4-94f5-2a0c84930230`: **46 groups**.
- `ube native compilation 180d9e56-9869-4873-bc39-207b00b22ba3`: **23 groups**.
- `ube source semantics c5c0b630-2fc6-4616-b0b9-a66a3c59b3a6`: **76 cases**.
- `ube project loading 56f66e7e-bbde-4d28-9754-da536de6d998`: **54 cases**.

The new gate binds the actual UBECore project and compiles its portable sources
with independent fixtures. Five native checks run at O0/O2 for copying, usable
primitive status, append success/failure, append validation and pre-call
conversion failure. A changed volatile input produces exactly mask 5, detecting
the copy and append observations. Assertions cover varied/negative bounds,
finite-record lengths, a LongLong-minimum singleton, overlap in both directions,
self-copy, zero-count endpoints, extreme Long spans, unchanged destinations,
sticky Err, continued eager expression evaluation on False, and handler
transfer on actual language FAIL. A narrowing argument failure records Err 6
and preserves the receiving Boolean, separately from primitive False.

Binding assertions distinguish renamed/casefolded primitive roles from ordinary
same-name source procedures. Seventeen malformed/unsupported binding cases,
executable versus library Main treatment and failed-emission preservation pass.
Native tools remain Clang 23.1.3 and LLD. No allocation, collection, empty dynamic
arrays, file I/O, native library packaging or concurrency is qualified by this
gate. UBECore contains real portable source but is not a complete library.

## Bounded source-buffer and record gate

On 2026-11-10, this command built the final bootstrap with VB6 6.00.9782 outside
the sandbox and passed **38 aggregate-storage assertion groups**:

`rtk proxy powershell -NoProfile -File bootstrap/tests/aggregate-storage/check.ps1`

Build, generated IR, native executables and process evidence:
`C:\Users\Ubehage\AppData\Local\Temp\ube aggregate storage 464b9387-76b0-4159-b3ff-459aa6113b20`.

Actual UBE source retains ASCII/UTF-8 bytes, token spans and linked tree records,
traverses them, copies independent values and exercises nested fields, record
equality, aliases and parameter bounds. Four checks run at O0/O2 with volatile
input; changing the tree-start input returns the exact negative-control mask 1.
Invalid reads, destination indexes and ByRef arguments record Err 9 and preserve
destinations while skipping remaining operands/arguments. Enabled and active
handlers are exercised. Singleton arrays at both LongLong extremes remain
usable through ByRef with runtime indexes.

Inspection asserts nominal identities, field ownership/offsets and declaration
scopes, array shapes and resolved accesses. Bracketed intrinsic-name types remain
nominal, and escaped type names preserve AST/SYMBOL/BOUND record framing. Negative
cases reject unsupported aggregate paths and qualify array-element, flattened
record, recursive-layout-visit, total module storage and copy-snapshot frame
limits. Failed emission preserves the previous artifact.

The following commands passed on the same unchanged executable:

```powershell
$verifiedBootstrap = 'C:\Users\Ubehage\AppData\Local\Temp\ube aggregate storage 464b9387-76b0-4159-b3ff-459aa6113b20\build\UBE-Bootstrap.exe'
rtk proxy powershell -NoProfile -File bootstrap/tests/integer-types/check.ps1 -BootstrapExe $verifiedBootstrap
rtk proxy powershell -NoProfile -File bootstrap/tests/native-compilation/check.ps1 -BootstrapExe $verifiedBootstrap
rtk proxy powershell -NoProfile -File bootstrap/tests/source-semantics/check.ps1 -BootstrapExe $verifiedBootstrap
rtk proxy powershell -NoProfile -File bootstrap/tests/source-parsing/check.ps1 -BootstrapExe $verifiedBootstrap
rtk proxy powershell -NoProfile -File bootstrap/tests/project-loading/check.ps1 -BootstrapExe $verifiedBootstrap
```

Evidence directories under `C:\Users\Ubehage\AppData\Local\Temp`:

- `ube integer types 6f4df1d6-f82f-49c2-aef2-8e30726ffcae`: **46 groups**.
- `ube native compilation 74cd89fe-fbdc-47e7-9a5c-dad218cfdbb8`: **23 groups**.
- `ube source semantics 6dc1d0bc-ef54-4a82-9dff-a1fd1e26dc9c`: **76 cases**.
- `ube source parsing 5571ff58-197b-4ed8-8e6d-26e1ddbad1e9`: **37 cases**.
- `ube project loading d7bb71ef-b6d2-43fc-8044-6440a0fe7b18`: **54 cases**.

Native tools remain Clang 23.1.3 and LLD. The extension uses fixed owned storage,
not runtime heap allocation: dynamic resizing, managed text, aggregate
ByVal/results, public layouts, self-hosting and concurrency remain unqualified.
The next dependency assessment should cover growing source/token buffers and
counted input/output before choosing the next implementation boundary.

## Integer storage and conversion gate

On 2026-11-10, the updated bootstrap built with VB6 6.00.9782 and passed all
76 existing semantic cases using:

`rtk proxy powershell -NoProfile -File bootstrap/tests/source-semantics/check.ps1`

Build and semantic evidence:
`C:\Users\Ubehage\AppData\Local\Temp\ube source semantics 76b57bdc-1612-43b6-9cc7-c918a8fcff02`.

The following commands all passed on that same unchanged executable:

```powershell
$verifiedBootstrap = 'C:\Users\Ubehage\AppData\Local\Temp\ube source semantics 76b57bdc-1612-43b6-9cc7-c918a8fcff02\build\UBE-Bootstrap.exe'
rtk proxy powershell -NoProfile -File bootstrap/tests/integer-types/check.ps1 -BootstrapExe $verifiedBootstrap
rtk proxy powershell -NoProfile -File bootstrap/tests/native-compilation/check.ps1 -BootstrapExe $verifiedBootstrap
rtk proxy powershell -NoProfile -File bootstrap/tests/source-parsing/check.ps1 -BootstrapExe $verifiedBootstrap
rtk proxy powershell -NoProfile -File bootstrap/tests/project-loading/check.ps1 -BootstrapExe $verifiedBootstrap
```

Final evidence under `C:\Users\Ubehage\AppData\Local\Temp`:

- `ube integer types caa47339-8e01-4b4e-9ec8-30e0f0d02268`: **46 groups**.
- `ube native compilation 0fbc7a2e-a36b-496c-aa46-0047aa5ff8d3`: **23 groups**.
- `ube source parsing f9c4eef5-2c1e-46bb-80cf-2a232ad95d32`: **37 cases**.
- `ube project loading 9b50c4f8-661c-4017-9f12-d4293ce134f2`: **54 cases**.

The integer gate checks exact bounds, destination-context constant typing,
authoritative %, & and ^ literal suffixes, declaration/use suffix agreement,
Byte-to-Integer promotion, and typed ByRef alias/temporary bindings. Actual
source-generated native code runs at O0 and O2 using volatile harness input.
The 25-cell scalar matrix covers assignment, ByVal and result conversions;
113 additional runtime boundary cases cover source minima/maxima/zero and
destination bounds plus/minus one where representable by the source type.
Failures must preserve the destination sentinel and record Err 6; success
must report fresh success. The four-check input-zero negative control returns
exact mask 15. Known invalid constants and all 20 incompatible direct ByRef
pairs are rejected, and a failed emission preserves prior LLVM output.

Native tools remain Clang 23.1.3 and LLD. No new tool dependency, target ABI,
operator family or compiler generation was introduced. Public memory layouts,
arrays/records, source text, foreign interfaces and concurrent compiler execution
remain unqualified. The final compiler's concurrency requirement and pending
gate are recorded separately from these sequential bootstrap results.

## Scalar source-to-native gate

On 2026-11-10, the following command built the final VB6 bootstrap outside the
sandbox and passed all **23 native assertion groups**:

`rtk proxy powershell -NoProfile -File bootstrap/tests/native-compilation/check.ps1`

Tools: VB6 6.00.9782 and Clang 23.1.3 (LLVM revision
`0d261d1ca552c95a8f007e061c787ac7132fbcbc`), with the installed LLD linker.
Evidence and the tested executable are retained under:
`C:\Users\Ubehage\AppData\Local\Temp\ube native compilation 7ad953f1-5dfb-4994-b557-cbcc35084c7d`.

The gate compiles actual SourceOracle.bas and invokes all eight public checks
independently with volatile input 1, requiring fresh success and result zero
at O0 and O2. The same generated source code with harness input zero must
return exactly mask 255. Multi-module executable fixtures assert forward and
once-only initialization, neutral failed initializers, expression/argument
order, direct ByRef aliases, discarded grouped temporaries, declaration
reexecution, Boolean/Long conversions, runtime arithmetic and narrowing
failures, sticky Err, consumed callee failures, explicit handler modes,
Err.Clear while a handler is active, and guarded recursion (Err 28).
An ordinary user module Err remains ordinary. Demo returns 42; Sub Main returns 0.

The runner checks AMD64 PE output and repeatable LLVM, then proves prior-output
hash preservation for source failure, missing Clang, nonzero backend exit,
false-success backend with missing output, a timed-out backend, input/output
collision and unsupported/over-limit emission. A preserved executable still
returns 42 afterward. The timeout backend is contained and terminated by the
driver. The initial harness used dynamic alloca and exposed a missing __chkstk
link dependency; test-owned static context storage removed that dependency.
No production workaround or external runtime was added.

The same final executable passed all earlier gates:

```powershell
$verifiedBootstrap = 'C:\Users\Ubehage\AppData\Local\Temp\ube native compilation 7ad953f1-5dfb-4994-b557-cbcc35084c7d\build\UBE-Bootstrap.exe'
rtk proxy powershell -NoProfile -File bootstrap/tests/source-semantics/check.ps1 -BootstrapExe $verifiedBootstrap
rtk proxy powershell -NoProfile -File bootstrap/tests/source-parsing/check.ps1 -BootstrapExe $verifiedBootstrap
rtk proxy powershell -NoProfile -File bootstrap/tests/project-loading/check.ps1 -BootstrapExe $verifiedBootstrap
```

Final regression evidence under `C:\Users\Ubehage\AppData\Local\Temp`:

- `ube source semantics caeef0c8-282b-4399-ba0b-a2a1a321d70c`: 76 cases.
- `ube source parsing 3b0ff74d-767a-41cf-bd18-f130087b9a43`: 37 cases.
- `ube project loading 0962dc36-0c0d-42e1-b218-d600eb31a143`: 54 cases.

`../bootstrap/LOWERING.md` records the internal result/context ABI, numerical
limits and deferred cases. Frame/parameter limits are exercised; exact IR-size,
scan-budget and log-size thresholds are defensive and not separately qualified.
Root Raise, potentially failing If headers, lifecycle hooks and potential
initializer cycles are explicitly rejected. Native libraries/foreign ABI,
threads, full Err metadata, arbitrary OS stack exhaustion, managed resources,
debug-info emission and self-hosting remain unqualified. Manifest debug settings
do not yet produce Line/Full native debug information.

## Semantic gate (historical isolated step)

On 2026-11-10 this command built with VB6 6.00.9782 outside the sandbox and
passed all 76 semantic cases:

`rtk proxy powershell -NoProfile -File bootstrap/tests/source-semantics/check.ps1`

Build and initial evidence directory:
`C:\Users\Ubehage\AppData\Local\Temp\ube source semantics 2642cea7-48b2-4d25-9412-86e46fce5061`.

The final runner added exact label-target and 64-bit And intermediate assertions.
It passed all 76 cases against that unchanged executable. The parser and loader
regressions also passed against the same executable, using these commands:

```powershell
$verifiedBootstrap = 'C:\Users\Ubehage\AppData\Local\Temp\ube source semantics 2642cea7-48b2-4d25-9412-86e46fce5061\build\UBE-Bootstrap.exe'
rtk proxy powershell -NoProfile -File bootstrap/tests/source-semantics/check.ps1 -BootstrapExe $verifiedBootstrap
rtk proxy powershell -NoProfile -File bootstrap/tests/source-parsing/check.ps1 -BootstrapExe $verifiedBootstrap
rtk proxy powershell -NoProfile -File bootstrap/tests/project-loading/check.ps1 -BootstrapExe $verifiedBootstrap
```

Final artifacts under `C:\Users\Ubehage\AppData\Local\Temp`:

- Semantic: `ube source semantics b8a3d49e-8c97-424b-8183-c6067f684306` (76 cases).
- Parser: `ube source parsing 373323ab-d6e2-48fa-934f-ec567849554a` (37 cases).
- Loader: `ube project loading 595feb50-3001-4be7-815b-fd3f1c6a79ef` (54 cases).

Assertions cover declaration/entry identities, module/package visibility and
ambiguity, shadowing, duplicate/undeclared names, exact signatures, conversions,
ByRef aliases versus temporaries, constant boundaries, labels/handlers and
trusted Err roles. The actual source oracle binds to trusted error operations;
an ordinary user module Err does not. Negative diagnostics assert locations,
failed analyses publish no partial bound result, and semantic symbol/depth
limits fail cleanly. The lookup-work guard is not separately threshold-tested.

No source procedure is executed by these commands. Deferred cases remain
explicit in `../bootstrap/SEMANTICS.md`: hex/octal interpretation, mixed
Boolean/integer operator domains, cross-module required-constant dependencies,
and colliding package/module three-part qualifiers. Full Err signatures remain
future work; runtime behavior is covered only to the extent of the newer native gate above.
Actual concurrent compilation and editor
multi-error recovery are not qualified.

## Lexer/parser gate

On 2026-11-10, this command built with VB6 6.00.9782 outside the sandbox and
passed all 37 source-parsing cases:

`rtk proxy powershell -NoProfile -File bootstrap/tests/source-parsing/check.ps1`

Evidence directory:
`C:\Users\Ubehage\AppData\Local\Temp\ube source parsing b3e2053c-36d1-42da-8be2-e7571af6f13e`.

The same executable passed all 54 existing loading cases with:

```powershell
rtk proxy powershell -NoProfile -File bootstrap/tests/project-loading/check.ps1 -BootstrapExe 'C:\Users\Ubehage\AppData\Local\Temp\ube source parsing b3e2053c-36d1-42da-8be2-e7571af6f13e\build\UBE-Bootstrap.exe'
```

Loading evidence directory:
`C:\Users\Ubehage\AppData\Local\Temp\ube project loading 695107e3-81eb-42f6-a388-cb08c0537975`.

The syntax gate asserts tree ownership/reachability, operator precedence and
associativity, positional arguments, parameter modes, If branch structure,
exact source spans, comments/continuations, bracket escaping, multi-module
order and qualified-call syntax. The actual failure-flow source oracle parses
with all eight public checks represented. It is not executed.

Negative cases assert diagnostic categories/locations, no partial success on a
second-module error, and bounded token length/count, aggregate tokens, nodes
and expression nesting. An independent valid invocation succeeds after invalid
ones; this does not qualify reuse within one process or concurrent compilation.

`--parse` validates admitted syntax; `--dump-ast` additionally emits inspection
records. Limits, source ownership and UTF-16 span conventions are documented
in `../bootstrap/DESIGN.md`. One diagnostic ends a failed request; editor
multi-error recovery is unimplemented. This historical gate qualifies syntax;
the semantic gate above now covers its admitted name/type/entry checks.
Native execution is covered separately by the newer gate above.

## Project-loading gate

On 2026-11-10, this command passed outside the restricted sandbox with
VB6 6.00.9782:

`rtk proxy powershell -NoProfile -File bootstrap/tests/project-loading/check.ps1`

The build succeeded and all 54 cases passed: exact ordered output for multiple
modules and the checked-in sample; repeated loading; Unicode/BOM input and
Unicode paths; required fields; duplicate keys, paths and identities; malformed
text/headers; path and junction escapes; input bounds; unsupported features;
and exact CLI exit codes. Selected syntax/header errors assert filename/line.
Artifacts and logs were retained at
`C:\Users\Ubehage\AppData\Local\Temp\ube project loading f88b5979-2db4-4aa6-b985-d626e3b334d1`.

The sandbox blocks VB6 registry access; the outside-sandbox run made no registry
changes. An initial compile error was resolved by preserving CRLF in VB6 source
and project files, now specified by `.gitattributes`.

`--check` validates manifest metadata and source envelopes only. Procedure syntax
is handled by the separate parse commands; the analysis commands check Main
and cross-module call binding. Native commands now extend the same pipeline.
It emits no target artifact. Full Unicode identifiers, references/resources and
non-MODULE source kinds are explicitly outside the current admission boundary.
See `../bootstrap/README.md` for input bounds. The gate does not qualify reuse
of a context within one process or actual concurrent compilation.

## Native failure-flow gate

On 2026-11-10 this command passed with Clang 23.1.3:

`rtk proxy powershell -NoProfile -File bootstrap/tests/failure-flow/check.ps1`

O0 and O2 each produced a PE x64 image and exited with exactly 0 after eight
behavior assertions: successful zero with stale Err, raise exit, default
assignment preservation/skipped operand, caller handler, active-handler
failure, explicit cleanup ordering, preserved ByRef effect and repeated equal
error numbers. O2 negative controls were rejected with exact masks 158 and 4.

These are hand-authored native test calls, not UBE compiler output. Full Err
metadata, TLS, actual OS resource release, source parsing/lowering and public
ABI are not qualified. SourceOracle.bas and source-oracles.json define the
matching source gate, now executed separately by the native compiler runner above.

## Completed bootstrap feasibility experiment

Owner direction on 2026-11-10: restart the implementation and use VB6 for the
bootstrap if possible. The final compiler remains written in UBE, producing
native 64-bit programs through LLVM.

The compiler directory currently contains documentation only. The previous
bootstrap and standard-library implementation files are removed in the working
tree. Do not restore them wholesale or inherit their verification claims.

Acceptance gate used:

1. Locate an owner-provided VB6 installation and record its version.
2. Compile and run a minimal repository-owned VB6 project without interactive
   error dialogs; exercise a deliberate failure with an asserted result.
3. Locate and pin the LLVM tools used for the experiment.
4. Have the VB6 executable emit a minimal LLVM module, compile/link it for
   Windows x64, assert the PE machine type and the expected process exit code.
5. Record exact commands and results before declaring the bootstrap viable.

VB6's 32-bit host does not require a 32-bit generated target. Emit textual LLVM
IR and invoke the backend out of process; do not attempt to load a 64-bit LLVM
library into VB6. Target integers must not inherit VB6 host overflow behavior.

On 2026-11-10 the following command passed outside the restricted sandbox:

`rtk proxy powershell -NoProfile -ExecutionPolicy Bypass -File bootstrap/tests/vb6-llvm/check.ps1`

Tools: VB6 6.00.9782 and Clang 23.1.3. Assertions passed for IR emission,
invalid-path exit 3, x64 PE machine 0x8664 and generated-program exit 42.
The sandboxed invocation failed on registry access; the outside-sandbox build
succeeded without a registry change. This proves the fixed IR bridge only.
It does not parse UBE source or establish self-hosting. Tool versions are
recorded, not yet packaged or enforced as release prerequisites.
