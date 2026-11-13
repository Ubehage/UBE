# Storage contention diagnostic

These scripts instrument a retained native compiler driver without changing production source or its frozen input package. `prepare.ps1 -InputIR <driver.ll> -Destination <new-directory>` redirects only output paths and adds counters. Compile the resulting `profile.ll` with the same target, O2, no CRT, reviewed Kernel32 import archive, and stack setting as the original driver. Run `run.ps1 -Directory <directory> -Baseline <expected-output.ll>`; it requires native exit 0 and an exact SHA-256 output match. `read.ps1 -Counts <counts.bin>` reads the 72 native 64-bit counters.

Each lock-operation category has a separate 64-byte counter group. Scanner block/release totals accumulate locally and publish once per scan, avoiding a per-block atomic counter. Instrumentation changes runtime costs; elapsed times are diagnostic and must not be reported as compiler performance acceptance.

The frozen baseline was `%TEMP%\ube concurrent compilation 38e1d451-c37a-4bfb-94d5-f36e273423a9`, containing 51 compiler modules (722143 bytes), the actual UBE compiler driver, input hashes, and retained benchmark results. On 2026-11-13 profiles of `compiler sources trial 1.ll` and `compiler sources trial 2.ll` passed native execution and exact output comparison in `%TEMP%\ube storage profile one` and `%TEMP%\ube storage profile two` respectively.

| Observation | One worker | Two workers |
|---|---:|---:|
| Collection requests / locked scans | 1,038,729,983 | 1,039,292,363 |
| Blocks scanned | 41,364,845,732 | 46,502,386,317 |
| Blocks freed | 20,550 | 20,608 |
| Scans reclaiming nothing | 1,038,712,049 | 1,039,274,388 |
| Collection lock failed CAS | 0 | 24,080,905,232 |
| Contended collection acquisitions | 0 | 227,624,655 |
| Snapshot lock failed CAS | 0 | 6,394,679,941 |
| Contended snapshot acquisitions | 0 | 55,511,125 |

Both outputs had SHA-256 `E04E6F1E1E189089040F4AD22798C56ADF4400C8F6EEED9927D6C1272682EBF2`, identical to the frozen uninstrumented outputs. The measured empty-reclamation scans motivated the pending-retirement flag; the separate pending-retirement gate checks that optimization's behavior. An uninstrumented idle benchmark is still required to measure its throughput effect.

## Relaxed-poll lock experiment

`lock-experiment.ps1 -BaselineDirectory <frozen-benchmark-directory>` copies the frozen drivers and installed assets, redirects their outputs, and changes only the candidate storage-lock acquisition loop. The candidate polls with relaxed atomic loads while the lock is held, and attempts an acquire compare/exchange only after observing zero. Release unlock is unchanged. No pause intrinsic or counters are added. Four O2 executables (original/candidate, one/two workers) run serially in reversed, interleaved blocks, four trials per combination; every execution must exit 0 and reproduce the frozen output hash.

On 2026-11-13, using the post-retirement baseline `ube concurrent compilation ff13c308-eb90-4949-a5b6-73be79b53f00`, all 16 trials passed those correctness checks. Evidence is `%TEMP%\ube storage lock experiment 61e10156-2514-40ba-82e7-5d46f920f69b`, including `measurements.csv` and all executable/IR inputs.

| Loop | Workers | Mean milliseconds |
|---|---:|---:|
| Original compare/exchange | 1 | 3941.62 |
| Relaxed poll then compare/exchange | 1 | 4135.92 |
| Original compare/exchange | 2 | 4750.49 |
| Relaxed poll then compare/exchange | 2 | 4995.67 |

The candidate slowed the one-worker case by 4.93% and the two-worker case by 5.16%; its two-worker result was 26.74% slower than the original one-worker case. This experiment did not justify adopting the candidate. Production locking remains unchanged.

## Descriptor stripe experiment

`lock-experiment.ps1 -BaselineDirectory <frozen-benchmark-directory> -DescriptorStripes` tests a distinct synchronization scope, retaining the original compare/exchange acquisition loop. `descriptor-stripes.ps1` transforms only three runtime definitions in the copied driver:

- `ube.array.snapshot` takes a descriptor stripe while reading all four descriptor cells and retaining the backing block. It does not take the heap lock.
- `ube.array.clear.locked` takes the same stripe while emptying the descriptor and dropping its old backing owner. Both callers (`array.clear` and final-owner `box.drop`) already hold the heap lock.
- `ube.array.install` retains its heap lock, then takes the stripe for descriptor replacement and the old-owner drop; it releases the stripe before the heap lock.

The test-only table has 64 cache-line-spaced locks. Its address hash XORs shifts by 3, 12, 16, 22 and 32 bits, including high stack-base bits so identical frame offsets do not systematically select one stripe. Collisions only serialize otherwise independent descriptors. No array/block layout or production source changes are made.

The lock order is heap then stripe; snapshots hold only a stripe, and no operation takes the heap lock while holding a stripe. `memory.copybytes` remains protected by the heap lock, which still excludes every published-descriptor writer. Its payload accesses are atomic. Resize/copy read through snapshots and publish through install/clear. IO/path/process `.pinned` routines read private stack copies produced by snapshot wrappers; they retain backing blocks across OS calls without holding either lock. Scalar overlap checks inspect addresses rather than descriptor contents. The collector holds the heap lock and reads atomic reference counts: a published descriptor owns a live block reference until a stripe-protected replacement, so snapshot can safely retain under its stripe before the owner is removed. The caller must still keep the descriptor storage itself alive through existing frame, global or boxed ownership.

Direct emitter descriptor stores initialize unpublished stack temporaries, newly allocated boxes, or module storage before publication. Escaping fixed-array resets use install. The audit separately found a UBE emitter dynamic-array reset that redundantly wrote empty cells after locked clear; that existing race was reported for a focused correction. It is not an argument for permitting unlocked published descriptor mutations.

Before timing, `descriptor-check.ps1 -SharedStorageEvidence <retained-shared-storage-directory>` patched and reran the existing real-thread shared-descriptor probes at O0/O2, including retained pins, boxed cleanup, injected allocation failures and expected-value negative controls. All four images passed their required exits (0/99), with evidence `%TEMP%\ube descriptor stripes 0c2d4aad-2f87-4afb-9eb1-40294fd59c3d`.

The 16 interleaved frozen-driver trials then passed native exit and exact output-hash checks. Evidence: `%TEMP%\ube storage lock experiment acae37a1-1ca1-4395-b946-51c372fa7a00`.

| Descriptor synchronization | Workers | Mean milliseconds |
|---|---:|---:|
| Whole-program heap lock | 1 | 3990.03 |
| Descriptor stripe | 1 | 4057.98 |
| Whole-program heap lock | 2 | 4776.79 |
| Descriptor stripe | 2 | 3955.08 |

The candidate reduced the two-worker time by 17.20%, identifying snapshot serialization as a significant contributor to that penalty. However, its two-worker mean was only 0.88% faster than the original one-worker mean, with overlapping observed ranges. This is not meaningful acceptance evidence for useful parallel speedup. Production synchronization remains unchanged by this experiment.

The same unchanged 16-trial experiment was repeated against the ByteText scalar-cache compiler snapshot `ube concurrent compilation c3c831ff-cfdf-44d0-97d7-ec1959bfc100`. All outputs matched SHA-256 `248EB3EC0345A117B6AFF7674AF279F7A8AC426908506D5A9A3D5F015F5C072D`. Raw trials and copied executables are in `%TEMP%\ube storage lock experiment 4e20985f-737c-42f4-9e90-9ba371c0f659`.

| Descriptor synchronization | Workers | Mean ms | Observed range ms |
|---|---:|---:|---:|
| Whole-program heap lock | 1 | 3823.29 | 3791.52–3850.21 |
| Descriptor stripe | 1 | 3837.74 | 3809.76–3869.99 |
| Whole-program heap lock | 2 | 4519.32 | 4396.78–4641.73 |
| Descriptor stripe | 2 | 3984.40 | 3913.69–4116.87 |

Here the striped two-worker mean remained 4.21% slower than the original single-worker mean and 3.82% slower than the striped single-worker mean. It reduced the original two-worker penalty by 11.83%, but again did not establish useful parallel speedup. The experiment did not change production locks.

With each emission worker receiving a private ByVal catalog snapshot, the same unchanged stripe experiment was repeated on frozen drivers `ube concurrent compilation 7e39ecb5-8a71-4d8d-8a1e-5f1946027fa4`. All 16 executions passed and reproduced the same `248EB3EC...F5C072D` output hash above. Evidence: `%TEMP%\ube storage lock experiment d0c867f0-c730-4381-907a-bde46136113a`.

| Private-catalog compiler variant | Workers | Mean ms | Observed range ms |
|---|---:|---:|---:|
| Whole-program heap lock | 1 | 3821.21 | 3798.00–3848.68 |
| Descriptor stripe | 1 | 3909.82 | 3828.19–4085.07 |
| Whole-program heap lock | 2 | 4383.53 | 4350.31–4451.02 |
| Descriptor stripe | 2 | 3499.33 | 3438.13–3555.84 |

The striped two-worker mean was 8.42% faster than the original one-worker mean, 10.50% faster than the striped one-worker mean, and 20.17% faster than the original two-worker mean. Even the slowest striped two-worker trial was 6.38% faster than the fastest original one-worker trial. This combination shows a repeatable gain in this frozen workload experiment; production integration and its complete correctness and performance qualification remain separate requirements. No production locking was changed by this test.

## Executed snapshots by procedure

`procedure-counts.ps1 -BaselineDirectory <frozen-benchmark-directory>` instruments direct calls to `ube.array.snapshot` inside each generated procedure and runtime helper, plus procedure entry counts. Bound symbol records supply module/procedure names. It also counts `LLVMFormat.TryFormat` calls to `LLVMWriter.TryAppendInteger` to quantify one proposed same-index cache. The single-worker driver dumps counters after normal completion; it must exit 0 and reproduce the frozen output exactly. These are execution counts, not static callsite counts or timing measurements.

Using the same `ff13c308` frozen driver, this passed with output SHA-256 `4574D383A868F2466636E2AE44EE815DBDBBB13C534ED2C91ACB87342FE4E91C`. Evidence and complete `counts.csv`: `%TEMP%\ube snapshot procedures acbc72c4-005c-4996-afa0-1501f19cb6f9`.

| Procedure | Entries | Direct snapshots |
|---|---:|---:|
| ProjectSyntax.ValidModule | 1530 | 90,798,910 |
| ByteText.TryAppendInteger | 624036 | 64,154,642 |
| SyntaxTokens.SpellingByte | 5542278 | 49,763,957 |
| LLVMWriter.TryAppendSpan | 1841761 | 21,476,207 |
| LLVMFormat.ValidSpan | 304547 | 15,329,143 |
| LLVMFormat.TryFormat | 304547 | 14,126,863 |
| Runtime array.length | 6524639 | 6,524,639 |

TryFormat performed 624017 integer-append calls. Eliminating two repeated catalog reads for each would avoid 1,248,034 snapshots in this workload. That is a bounded local opportunity; the larger measured paths remain relevant to total cost. No compiler-source optimization was made by this diagnostic.
