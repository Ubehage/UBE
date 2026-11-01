# Frontend baseline and focused root-cost evidence

Filesystem layout note, 2026-11-01: production sources now live in `src/`.
All 24 source files retain identical bytes. Reports and source paths below retain
their original qualification context; the relocation's fresh source/CLI records
are listed in [Progress.md](Progress.md). No new timing result is claimed by the move.

## Current accepted qualification - 2026-11-01

Bounded normal `.UBE`/direct explicit UBECore input and the integrated parallel
frontend are complete within their frozen scope. The owner explicitly accepts
close initial results; 1.5x/two-worker and 2x/four-worker remain engineering
targets. **All correctness, resource, lifetime, copy, deterministic publication,
serial/small regression and complete-session obligations remain required and pass.**
The original measurement report still records its eight numerical target misses;
its `success=false` and `performanceAccepted=false` fields are unchanged.
Acceptance is a separate explicit judgment under [the owner policy](PERFORMANCE-ACCEPTANCE.md).

### Source and strict qualification

`rtk proxy powershell -NoProfile -File bootstrap/build-v2.ps1` exits 0,
785 assertions. Current cohort:
`bootstrap/out/v2/a732173e4f3d450cb7a6feaa519af1d3/`.
Manifest SHA-256:
`4CEC0F51C80F502FFFFE247988AAC5D3726D75419513EB8791710D9EFFB5CB9B`.
Stage-two executable SHA-256:
`C9E6B9598A41C43A4E2E2674E998CD9E8167C544E342A859C1A5C933BE19609C`.
Runtime object SHA-256:
`93E33D36A34F0DFF13A5E38748862302ABB5913AFE1CF126E0B20C0454831934`.

The retained gate commands are:

```powershell
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tools/check-project-contract.ps1
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tools/check-parser.ps1
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tools/check-parser-cli.ps1
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tools/check-local-cli.ps1 -CliReport C:/Users/Ubehage/vscodium/UBE/bootstrap/out/parser-cli/cd776c346cef4b48877d02652e865739/report.json
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tools/check-project-cli.ps1
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tools/check-borrowed-lifetimes.ps1
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tools/check-concurrency.ps1
```

All seven exit 0. Sequential ledger:
`bootstrap/out/final-frontend-gates/7c52a8c64b8a416e9fffc318ddd19f8e/report.json`.
Their exact report directories under `bootstrap/out/` are:

| Gate | Report directory | Result |
| --- | --- | --- |
| Project definition | See sequential ledger | 15 definition checks; definition-only status text is not consumer status |
| Parser | `parser/76bb231e0f0b4490891fe0e8f514286a` | 1769 grouped checks, all 188 cases; every capacity 0..58/200/206/207 per stage, 1350 attempts total |
| Source CLI | `parser-cli/cd776c346cef4b48877d02652e865739` | 104 exact process oracles, 29 diagnostic modes per stage |
| Local CLI | `local-cli/fd480fd077f84707bf0b955844993872` | 52 exact oracles, qualified stage-two bytes |
| Project CLI | `project-cli/25ff9846f7454d558b3ef82114fb1542` | 1202 assertions |
| Borrowed lifetime | `borrowed-lifetimes/9d09532bd9d0421b84c1f20ba09311c7` | 56 runs plus the negative unowned-watch control |
| Concurrency | `source-set-proof/f88a3b23fe064b788856c4e213a34348` | 4200 assertions through each stage |

The source cohort includes native project intake: 35 cases, four independent
contexts and 375 observed allocator-denial positions. The optional physical
case-sensitive 36th fixture is historical, not a current-cohort result. Parser
counts decrease because proven unnecessary roots were removed; no grammar case,
capacity interval or resource-failure obligation was dropped. Zero worker source
payload copies, Err behavior, private contexts, real overlap, cancellation/drain,
deterministic first failure, complete publication and older-result retention are
proved by instrumented strict gates, not inferred from timing stdout.

### Production changes and costs

Only the reviewed changes are adopted: conservative known-ByRef unused argument
slot removal in v2; address-owned root synchronization in the bootstrap runtime;
and the existing coordinator's `TryThreadWait` timeout changed from 0 to 1ms.
Current source SHA-256 values respectively:

```text
compiler/UBE_Compiler_v2/Main.bas
18A73EF11FDE91F73E2D6FAB40DF0A83A50980ACED7F73C34C9F3038421DA85B
runtime/bootstrap_runtime.c
2B6F0821D7C24859A807FB5602C39E06F41F5487002F4E9826D84FF1E0318A3F
compiler/UBE_Compiler_v3/SourceParsing.bas
945116DCF02C2D5AB28BF638FBD66F73EB77330A4010F4F7BB6B9402C305D3F1
```

Root ABI stays 32 bytes and global capacity stays 1,048,576. There are 4096
address-owned heads and 64 recursive stripes, atomic capacity/closure admission,
collector-owner exclusion and bounded simultaneous freezes. No callbacks run
under a freeze. Partial lock initialization permanently falls back to the old
heap mutex. Metadata costs 36,912 net static bytes (36,928 total); all 16 actual
target layout assertions pass. Cross-thread and absent/poisoned/inaccessible
leave, collection, shutdown and initialization failures remain covered.
Maintained root-registry tests add 87 source assertions (86 deterministic cases
plus the unchanged 2,106,814-assertion legacy test); materialization has 25 report
checks and 2,097,260 native assertions per stage. No new executor or public ABI
is introduced. Other experiments below remain historical and unadopted.

### Complete frozen measurement and acceptance

Command:
`rtk proxy powershell -NoProfile -File bootstrap/out/run-qualified-frontend-measurement.ps1`.
This invokes `measure-frontend.ps1` with the expanded baseline report
`bootstrap/out/frontend-performance/7b669fb006314b7293cf16444fc698dd/report.json`
and a real PowerShell `ChangedBuildInputs` array containing exactly the three
production files above. The wrapper avoids native `-File` array conversion.
It exits 1 only after both complete sessions: six corpora, seven interleaved
trials at each budget 1/2/4, 252 measured rows. All 34 hard comparisons pass;
only the eight original main-corpus numerical targets fail.

Report directory: `bootstrap/out/frontend-performance/0340fcdd651b45b5bf7ed1d6cd9fab7a/`.
`report.json` SHA-256:
`2C5841BDE063BD1BF71C469A6900A587F8382B9760C31B2FE562091F5EC99A5B`.

| Corpus | Session 1 median seconds, jobs 1/2/4 | Session 2 median seconds, jobs 1/2/4 |
| --- | --- | --- |
| Expanded real | 1.4083402 / 1.1668198 / 1.0803898 | 1.3855918 / 1.1437093 / 1.0379037 |
| Original real | 1.1884318 / 1.0102943 / 0.9492971 | 1.1781267 / 0.9920343 / 0.8803142 |
| Balanced | 4.4078431 / 3.4456740 / 3.1565943 | 4.3407778 / 3.3708739 / 3.0500877 |
| Uneven | 2.1612541 / 1.7310569 / 1.5335036 | 2.1603974 / 1.7206868 / 1.4971906 |
| Small empty | 1.2484553 / 1.237195899 / 1.222485099 | 1.231647401 / 1.2349173 / 1.230349201 |
| Small source | 0.1863463 / 0.1868635 / 0.1853159 | 0.1822416 / 0.1825526 / 0.1822567 |

Real speedups are 1.207/1.304x and 1.211/1.335x; balanced speedups are
1.279/1.396x and 1.288/1.423x (two/four workers). In each main corpus/session,
every parallel trial beats every serial trial, and every four-worker trial
beats every two-worker trial. This consistent range ordering supports initial
acceptance without inventing a replacement numeric threshold. Worst small-input
ratio is 1.00277548 <= 1.10; worst frozen serial-guard ratio is 0.61451996 <= 1.05.
Both frozen baselines, reference streams, corpus bytes, repeats, full 32-processor
affinity and power context remain unchanged.

`archive-performance-candidate.ps1 -ReportPath <0340/report.json>
-AcceptedCohortPath <a732/manifest.json>` exits 0 after copying and SHA-comparing
700 candidate/cohort artifacts. Snapshot SHA-256:
`E1F99BE7B5489C20E01BA9D4C0E50EE71FA99F38D947964DD862F16A6C19BDCF`.
The read-only `bootstrap/out/caller-location-review/audit-acceptance.ps1`
passes 6951 assertions: 252 rows, 12 stage/reference admissions, all medians,
distributions, hard guards, original targets, source/artifact and context pins.
Final `current-policy-audit-final.json` SHA-256:
`0EC22A7A7CC3D721750A000B45FE886D258F73AD01A40DEFE3930724F4D0DF8E`.
The initial audit's fractional shortfall rounding bug was corrected using the
double overload and 18 pure-JSON regression cases; original reports remain intact.
The audit deliberately leaves acceptance to explicit root judgment.

Independent assessment passes 177 checks and binds all strict evidence:
`bootstrap/out/caller-location-review/current-performance-assessment.json`,
SHA-256 `D7CD9E06459E3EB25D1FEB0E53A948BDE5D8AC412D2E5728584D7FC672D887E2`.
`rtk proxy powershell -NoProfile -File bootstrap/out/record-frontend-acceptance.ps1`
records accepted initial qualification in `0340.../acceptance.json`, SHA-256
`D0F00D1685929368F7E72E652623AC29F3E9C193E309D3CF93873CDF168FB36B`.
The completion audit maps every objective/contract family to evidence:
`bootstrap/out/root-synchronization-proof/completion-audit/audit.json`, SHA-256
`95CAE45BA9533D4F6281282BE2C1A8F52BAE9B9667A43F5AB12B13674ADF5EFA`.

Qualification is bounded to the initial Windows x64 native MODULE frontend and
explicit direct UBECore source references. Containment is lexical; junctions or
symlinks can resolve outside that tree. No separate project end-to-end timing
was collected; it is not a blocking gate in the frozen performance contract.
Full grammar, semantics, backend, arbitrary libraries and platform portability
remain unfinished. Further parallel optimization remains planned. Next proposed
work is the existing first semantic-checking contract. No new push is authorized.

## Historical development evidence

All candidate, pending-work and non-adoption statements below describe their
dated earlier checkpoints. They do not supersede the accepted qualification above.

Current owner acceptance revision,2026-11-01:1.5x/2x are engineering targets,
with close initial results acceptable. See [the current acceptance policy](PERFORMANCE-ACCEPTANCE.md).
Historical results below retain their original target outcomes. Required
correctness/resource/regression checks and complete measurement sessions remain.

## Qualified candidate: complete timing gate failed — 2026-11-01

The combined conservative materialization/caller-retention implementation passes
the complete source gate and every retained correctness gate. Its two complete
uninstrumented timing sessions do **not** pass the parallel speedup requirement.
The goal remains in progress; no baseline or threshold has been reset.

Current cohort: `bootstrap/out/v2/49fa6a4c182f44b6b002c4cb1177f18d`.
`rtk proxy powershell -NoProfile -File bootstrap/build-v2.ps1` exits0 with692
assertions. Manifest SHA-256:
`21F674EAD8F600708CE0D5378E8668BFBDA5B396FDFC093BA6595B2814B98A62`.
The sequential retained-gate ledger is
`bootstrap/out/final-frontend-gates/bef7bd2e20cb4d6b8c8a5afb13da358f/report.json`;
all seven commands exit0:

```powershell
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tools/check-project-contract.ps1
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tools/check-parser.ps1
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tools/check-parser-cli.ps1
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tools/check-local-cli.ps1 -CliReport C:/Users/Ubehage/vscodium/UBE/bootstrap/out/parser-cli/86409d582dfa4763bb62a983b620ea14/report.json
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tools/check-project-cli.ps1
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tools/check-borrowed-lifetimes.ps1
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tools/check-concurrency.ps1
```

Results: definition15; parser3161 checks over all188 cases, plus21243 strict
definition/provenance checks and16 negative controls; source CLI272 checks,
104 exact processes and58 diagnostic controls; local52 exact processes;
project CLI1202 assertions; lifetime56 runs plus the unowned-watch control;
concurrency4200 assertions through each stage. The parser sweeps every capacity
from zero through fresh requirements332/816/1141/1148 per stage (6882 total
attempts). Fewer required roots reduce its grouped-check count without removing
grammar cases or required capacity coverage. The lifetime probe's old duplicate
elision transform is now a no-op; retained caller35 supplies the current
caller-retention boundary proof. Err/copy/failure observations belong to these
instrumented correctness gates, rather than the timing rows.

```powershell
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tools/measure-frontend.ps1 -BaselineReport C:/Users/Ubehage/vscodium/UBE/bootstrap/out/frontend-performance/7b669fb006314b7293cf16444fc698dd/report.json -ChangedBuildInputs compiler/UBE_Compiler_v2/Main.bas
```

This command exits1 only after retaining both complete sessions: six corpora,
seven interleaved trials at each of budgets1/2/4,252 measured rows. Report
`bootstrap/out/frontend-performance/8a8ae593134a40429814e64035f57cf5/report.json`
has success=false/performanceAccepted=false, SHA-256:
`EB1B972E3822A8EC174D18D6527EB77B9CE3494B0D0F5A3AB7E40CC2C4F3E97D`.

| Corpus | Session1 median seconds, jobs1/2/4 | Session2 median seconds, jobs1/2/4 |
| --- | --- | --- |
| Expanded real | 5.390 / 7.466 / 11.947 | 5.368 / 7.513 / 11.935 |
| Original real | 4.518 / 6.369 / 9.697 | 4.529 / 6.408 / 9.676 |
| Balanced | 17.399 / 27.230 / 48.304 | 17.482 / 27.255 / 48.230 |
| Uneven | 8.696 / 13.661 / 24.260 | 8.685 / 13.700 / 24.263 |
| Small empty | 1.535 / 1.557 / 1.605 | 1.514 / 1.549 / 1.603 |
| Small SourceInput | 0.629 / 0.640 / 0.668 | 0.629 / 0.641 / 0.667 |

Real/balanced serial execution is about2.15x faster than the expanded baseline.
Every matching/original serial guard and every small-input guard passes.
Exactly eight checks fail: real/balanced speedup at two/four workers in both
sessions. Actual speedups are approximately0.72x/0.45x for real and0.64x/0.36x
for balanced, below the unchanged1.5x/2x requirements.

An independent read-only audit recomputes all36 medians and42 checks, verifies
all252 process/result/cleanup rows,12 two-stage reference admissions, four
265-pin session boundaries, unchanged power/full32-processor affinity and the
corrupted-reference rejection. Both stages emit raw LLVM SHA-256
`2E70E5A9507DBCE1DF04161ED5198DE72A1EA43E5C866E94EE143F3EEE25EE27`.
Command: `rtk proxy powershell -NoProfile -File bootstrap/out/caller-location-review/verify-candidate.ps1`;
2191 assertions pass. Audit `candidate-audit.json` in that directory has SHA-256
`7341D517DF9706B5492A1053DAA03FDFFB5DC04E41C884D37D225E10A2BDD1B1`.

Before further production changes,552 candidate artifacts and accepted-cohort
inputs were copied and SHA-compared. `candidate-snapshot.json` in the candidate
run has SHA-256 `AD4BD82261C3168E507967D1DBFF01E1CABC8BD66113189329FE195C1DFA1AB5`.
This archives a failed candidate; it does not create a new baseline. The original
f916 and expanded7b669 baselines remain unchanged. The next action is a small
current-code contention probe and an isolated replay of the existing minimal
spelling cache under the corrected lowering, with no production adoption or
collector redesign inferred from these failed timing sessions.

The next focused current-code probe completed with unchanged candidate raw LLVM
and four distinctly named SourceInput snapshots (23,740 payload bytes). It checks
complete document/token/node/metric equality and cleanup at budgets 1/2/4.
Measured root admissions/removals balance at 1,558,481 for each budget. Total
GC-lock calls are 3,972,328 / 4,000,307 / 3,960,692; root bookkeeping accounts
for 78–79%. Root-list links grow from 51,516,382 to 143,320,452 and 286,995,492;
peak roots grow from 1,295 to 2,480 and 4,727. No collection completes during
measured work. String validation contributes 163,376 calls, all hash misses;
hash-chain traversal is small. Coordinator zero-timeout waits exceed 100,000
for four completions. These observations identify current work to reduce;
instrumentation perturbs timing and supplies no speedup acceptance claim.
Report: `bootstrap/out/caller-root-adoption-draft/current-contention/1f12b73d88764888a41980a1d3f262e2/report.json`,
SHA-256 `0EC8968C597622141E9AEAA6638806CA6C8049146CD8CAA47306966D131B5B9D`.
The existing minimal spelling-cache replay now passes its current-lowering
diagnostic. Command:
`rtk proxy powershell -NoProfile -File bootstrap/out/spelling-reuse-current/replay.ps1`.
Both49fa tools produce identical LLVM per variant; independent25-vector suites
pass222/254 assertions. Complete-reference/corruption controls, six observed
copy/root rows and18 tiny uninstrumented rows pass with full drain. Root
admissions fall7.35% (1,558,481 to1,443,885), with identical727,264 copied bytes
across181,884 calls. TrySyntaxAt has four roots in both variants; the earlier
extra-root regression is gone. Three diagnostic trials of four repetitions give
baseline/cache medians0.620674/0.561171 at one worker,
1.172730/1.026392 at two and2.776949/2.458505 at four. The cache helps this
workload by about10–12%, but four workers remain4.38x slower than cache serial.
It is preserved as an ignored draft, not adopted or performance-qualified.
Report: `bootstrap/out/spelling-reuse-current/da091917251f4477887459519e9fbc75/report.json`,
SHA-256 `BF3A73AE2DBF24FB138E1CB968E8B99CF5F656500251BA10218A030E70B5F403`.
The next ignored probe isolates safe root lookup cost using the existing
32-byte storage/capacity/lock protocol; no runtime adoption is authorized by
that experiment alone.

That lookup probe is complete in `bootstrap/out/root-bucket-proposal/FINDINGS.md`.
Its exact ignored runtime patch is
`F1040ADF184F5D6475E3F9E6E6ADAA06B28F44F4AC618036E2E663DC92074B73`.
It replaces the single root head with 4,096 address buckets, preserves safe
address-only absence checks, all four root fields, generic captures, the
32-byte ABI, real capacity, allocation behavior and existing lock protocol.
Net static cost is 32,760 bytes; tracing/alias clearing scan 4,096 heads and
worst-case colliding removals remain linear. Both runtimes pass 2,106,814
synthetic assertions plus existing GC/concurrency/component probes. The proof
includes inaccessible/poisoned absence, non-LIFO removal, trace failure,
aliases, cross-thread captures, actual full capacity/recovery and shutdown.
Duplicate registration remains unsupported and unchanged; the probe does not
claim that malformed private-native use is safe.

Complete-output/copy/root/drain checks pass on the unchanged current raw LLVM.
Root counts and copied work stay identical. Root links drop from approximately
51.5/126.2/269.2 million to1.558/1.686/1.714 million at budgets1/2/4.
Three-trial original/bucket medians are0.156374/0.113412,
0.290619/0.163566 and0.703575/0.485564 seconds. Absolute gains do not solve
parallel scaling. Proof SHA-256:
`890FE1732B558A0234D5D9C97D71869AF839FF0EA737EBC1A065F16476752D9A`;
scout SHA-256:
`95E1913CA2D0783CF497D68585AD8987556A11F791A68F9E01308DFF6F93F454`.
No production runtime change is adopted. A current-code replay of the existing
private-procedure aggregation experiment is next, targeting admission count
through the existing precise-root layout API without changing UBE bodies.

That current aggregation replay now passes: 88 eligible frames contain 2,442
private values/precise slots, while all eight incoming/parameter admissions in
those procedures remain textually separate. Non-root call inventory is unchanged.
Native offset-union/alignment/bounds checks and zero/partial-admission rollback
pass, as do current caller35/borrowed56 watches. Each budget completes692 forced
collections from692 requests with no failed trace. Admissions fall from1,558,481
to332,743, a78.65% reduction; copied work remains727,264 bytes/181,884 calls.
Three-trial original/group/group-plus-bucket medians are
0.157175/0.051450/0.056517 at one worker,
0.297654/0.063164/0.078189 at two and
0.707220/0.152660/0.219169 at four. Buckets make the grouped variant slower and
are not selected for integration. Grouping is a large absolute improvement but
still fails parallel scaling; it remains an ignored LLVM diagnostic.
Report: `bootstrap/out/current-procedure-roots/scout/8ccd2173a90b4d788088cd65092bab28/report.json`.
The detailed safety reports and exact grouping are pinned in that experiment's
`FINDINGS.md`; no source emitter has been changed.

A matched policy probe then changes exactly one zero timeout to1ms, immediately
feeding the coordinator's existing wait call in grouped LLVM. It keeps the
original runtime. Wait calls fall from47,865/49,204/55,417 to8/9/13 for four
completions. Roots, copied work, complete outputs and drain remain identical.
Three-trial wait0/wait1 medians are0.051438/0.043796,
0.065757/0.050402 and0.153845/0.088670 at budgets1/2/4. Speedups remain only
0.869x/0.494x, so no optional cache combination or full performance replay is
justified. Report: `bootstrap/out/current-procedure-roots/wait-policy/2d0139afc4874564a1372577f0520130/report.json`,
SHA-256 `34A3DF89AA0E01F7150A6BD4F9CD21A30D033DDF7B0608D9F92569094565D71A`.
Further source-level investigation targets repeated known grammar spellings
using existing UBE helpers/trie data; no new GC or calling rule is adopted.

The later ignored lazy scalar-spelling implementation passes its demanded-prefix
compatibility proof and native checks. It rewrites 318 known literal sites,
retains the three generic helper bodies, adds two private POD cursor fields and
keeps token/node layouts and scanner roles unchanged. The abstract model checks
290,167 comparisons and 458,329 prefix relations; native execution checks841
query/read/cache sequences, generic vectors, malformed endpoints, actual registry
limits, allocation denial and cleanup (2,560,878 assertions). Both49fa producers
emit identical candidate LLVM. Actual admissions fall9.59%, while copied work
stays727,264 bytes. Four-repeat baseline/lazy medians at budgets1/2/4 are
0.631755/0.558079,1.163335/1.006985 and2.801570/2.403286 seconds: improved
absolute work, still negative parallel scaling. It remains ignored. Report:
`bootstrap/out/lazy-spelling-probe/d1829a81ce574165ae7bf72a7e82c989/report.json`,
SHA-256 `AFD85EC939B50CB7F5858CB4B6AC193C55778F2D40FCE1B779AE3AD095776F9E`.
Independent review checks every rewrite, actual generated range predicate,
invalidation, metrics and generic bodies, with no concrete finding.

An exact emitted-use audit then identifies a narrower existing lowering miss:
ByRef call arguments still receive private value/scratch slots even when call
emission uses their original lvalue addresses. The ignored source correction
marks only resolved, exclusively address-used arguments; unknown, unlinked,
mixed and ByVal uses retain value storage. It uses the same bounded positional
formal mapping as the existing resolver/emitter, changes no emission or runtime
protocol and preserves literal ByRef rejection UBE3202. Independent review found
and corrected a missing-callee/shared-link edge before qualification.

Corrected Main SHA-256:
`18A73EF11FDE91F73E2D6FAB40DF0A83A50980ACED7F73C34C9F3038421DA85B`;
patch SHA-256 `F99133FE84D58BFED8D6C4E7C205004024A70CBEA35A0E254384BB91D5FA455A`.
Clean-seed/source fixed point, three-compiler classifier controls (2,097,260
assertions each), current caller35/borrowed56, actual capacity and forced-GC
fixtures pass. Whole-frontend comparison proves2,255 omitted slot pairs have
only neutral initialization/root bookkeeping uses; every other LLVM instruction,
global and interface is identical. TrySyntaxAt's four unused roots become zero.
Actual admissions fall1,558,481 to351,827 (77.42%); copied work remains identical.
One-parse original/corrected medians are0.156242/0.050649,
0.291141/0.065629 and0.704633/0.157877 seconds. This is a large serial gain,
but still fails parallel scaling. No production integration follows from it.
Handoff: `bootstrap/out/byref-value-materialization/handoff.json`, SHA-256
`7B5A2DF512B5EEBCEAC5981C75E1B049110C80B9C62F65DC0C884045895B08F7`.
Maintained classifier extraction/signature adaptation and all full gates would
be required if the correction is integrated.

One current corrected-code attribution run, with the sole existing1ms timeout
to remove busy polling, reconciles all351,827 roots/leaves and full output/copy/
drain. Borrow315,350 plus fallback34,762 account for99.51% of registrations.
Two immediate Byte-rvalue sites account for139,064 (39.53%): TryReadSourceScalar
126,536 and TryScannerByte12,528. The85,948 token-copy borrows are actual ByRef
addresses and are explicitly retained. GC-lock calls total1,241,301, including
703,654 root admissions/removals,235,901 array-element accesses,136,645 lengths
and163,376 String validations. No collection runs in measured work. Remaining
scratch slots have no registrations;13 neutral-only assignment-target value
slots are a separate small context miss, not justification to drop real owners.
Attribution: `bootstrap/out/byref-value-materialization/ATTRIBUTION.md` and
`attribution/5fa10f6c7f6648a9b36c115c6bce13e7/report.json`, report SHA-256
`BBFA6CC287622719382C8CFA722A2F14FFACEF75DF3601C7DA3996878215C114`.
The next ignored probe tests only immediate rootless-scalar read/copy under the
existing exclusive lock, preserving exact neutral/Err/status behavior and all
address/ByRef/managed-element paths. No new GC synchronization is adopted.

That scalar probe preserves every unrelated instruction and replaces90 exact
single-use immediate primitive loads (76 Byte,10 i32,4 i64), with no records or
escaping element addresses. Independent static reconstruction matches candidate
LLVM `26EE4C51F8C739C509BD4C7EF294D70CBE445F1B29ECE6CCF915FFEB2BC77859`.
Matched complete-output/copy/root/drain checks pass at budgets1/2/4; admissions
fall351,827 to211,890, with identical727,264 bytes/181,884 copy calls. Three
one-parse baseline/candidate medians, both using the unique existing1ms wait,
are0.042839/0.037059,0.051811/0.040196 and0.100559/0.068588 seconds.
Candidate speedups remain0.922x/0.540x: the diagnostic still fails scaling.
Report: `bootstrap/out/current-scalar-read/scout/90a392cbd094401d9d67af1564b09577/report.json`.
Initial native checks cover actual full registry, old-chain value/status/Err,
allocation/trace faults, retained-owner replacement and concurrent collection.
Independent review identified a missing deterministic admitted-reader exclusion
assertion. The added test parks an admitted reader after holder capture and
before copy, asserts collector exclusion until release, and safely rejects a
premature-unlock mutant with exit88 before any freed-owner dereference. Command:
`rtk proxy powershell -NoProfile -File bootstrap/out/current-scalar-read/check-admitted-proof.ps1`.
Report: `bootstrap/out/current-scalar-read/admitted-proof/1435bf18ca71454b935a19534d7d2b1c/report.json`.
The positive run passes2,097,530 assertions; report SHA-256 is
`14378DFDDB3FEC6E02D228A548155529C90BB6990E2C9255FF044F7FD2961196`.
Independent read-only review confirms the overlap assertion and safe negative
control, with no remaining concrete finding.
These test-only gates are absent from the unchanged measured candidate.
Neither source emitter nor runtime production code adopts this experiment.

A separate read-only cursor-rollback review finds the retained `F (x)` case can
repeat a parenthesis read, but an external single-entry span memo would lose a
currently preserved opening-hash cache in `Print #2026-10-30#`. There is no
dynamic-frequency evidence making rollback the dominant cost; no memo prototype
is justified. Exact anchors and limits are in
`bootstrap/out/lazy-spelling-probe/rollback-review/FINDINGS.md`, SHA-256
`80B1374808F362E0E2FD43ACC168CE9328CAE99D8FF7ADC86DADB58AE158CBAE`.

## Approved root registry synchronization experiment — 2026-11-01

The owner approved [the bounded registry experiment](ROOT-REGISTRY-PROPOSAL.md).
Its independently reviewed ignored implementation contract fixes4,096 address
buckets and64 recursive stripes, preserves the32-byte root ABI and global1M
capacity, and gates foreign admissions through collection. Failed extra-lock
initialization cleans partial locks and permanently uses the existing heap lock.
All three registry consumers have bounded simultaneous-freeze intervals, with
no new lock held across arbitrary finalizers or waits.

Compile-only target checks pass all16 actual static assertions (the frozen
layout report's manual17 label is explicitly corrected). Metadata adds36,912
static bytes. Strict object compilation passes; neither compile establishes
native correctness. Independent actual-code review records258 original function
bodies unchanged, seven changed and11 private helpers added, with no concrete
finding. Review `bootstrap/out/root-registry-sync/code-review.json` has SHA-256
`7C9FF7FF6BDA900FF54D23C4669EB6AEC22E86EB0397CC3868878F19BB7C3CD2`.

```powershell
rtk proxy powershell -NoProfile -File bootstrap/out/root-registry-sync/check-layout.ps1
rtk proxy powershell -NoProfile -File bootstrap/out/root-registry-sync/prepare-runtime.ps1
rtk proxy powershell -NoProfile -File bootstrap/out/root-registry-sync/check-basic.ps1
```

The initial retained native comparison passes: original CF8 and ignored
candidate58A each satisfy2,106,814 root assertions, including actual1M capacity,
absence, tracing failure, aliases, capture cleanup and shutdown. Unchanged GC,
GC-concurrency and component probes return identical expected outputs. Report:
`bootstrap/out/root-registry-sync/basic-proof/98e25ed51a974d8c96fcbcbc6457cc33/report.json`.
Report SHA-256:
`FEFA72A35F39F831AA189B3198621CFCC5B528709E7F55EBD3BAED024F3AEF94`.
The final independent deterministic suite now passes86 cases:14 normal,
64 fresh-process initialization failures and eight safe mutant rejections.
This includes same-page root-record/slot lifetime and two contenders forced to
load the same actual1M-1 state before CAS, with failed-CAS retry and untouched
rejection. Independent review finds no remaining concrete proof issue.
`rtk proxy powershell -NoProfile -File bootstrap/out/root-synchronization-proof/check-sync.ps1`
produces `runs/3f39b933668c46af96a05157825117aa/report.json` in that directory,
SHA-256 `6EA986D306A96FBDA75655C83E053C76CA6E7316AF05FE2B4D7DB64555B7793C`.
The78 positive processes record6,923,327 assertions; safe mutants terminate
before unsafe effects. Earlier f686 results retain their narrower test scope.

Matched current18A frontend LLVM, with the same unique1ms wait, then passes
complete-result/copy/root/drain comparisons at budgets1/2/4. Both runtimes
register351,827 roots and copy727,264 bytes/181,884 times. Heap-lock operations
fall from about1,241,260 to538,284. Three tiny uninstrumented trial medians are:

| Workers | Original runtime seconds | Striped runtime seconds |
| --- | ---: | ---: |
| 1 | 0.0436983 | 0.0467293 |
| 2 | 0.0534461 | 0.0376787 |
| 4 | 0.1041215 | 0.0322449 |

The candidate gives positive1.240x/1.449x scaling, below the1.5x/2x requirements.
Its6.94% serial difference from this matched18A diagnostic is not the formal
serial guard, which uses the preserved pre-optimization baselines. Report:
`bootstrap/out/root-registry-sync/frontend/3a0cea162a434255b80734cfad25de63/report.json`,
SHA-256 `74E3A8C73679FE27773398B6B14669B646C4E95C164B3954C629947B357C9A60`.
The next bounded measurement screens this unchanged candidate on the frozen real
and balanced corpora before deciding whether full qualification is justified.
No production adoption or complete performance acceptance is claimed; all
original full gates remain required.

## Frozen expanded serial baseline — 2026-11-01

The corrected unoptimized source-qualified cohort db71 completed the maintained
expanded baseline procedure. All six corpora have seven retained serial trials
(42 total), complete-result comparison and cleanup. Both accepted stages emit
the same raw LLVM, `598ADB2C94BAE2234EAC5F35758AA9A865FC0F3739314E870E29E3301C795B80`.
The corrupted-reference control exits1 with the required mismatch. Report flags
are success=true/frozenBaseline=true/**performanceAccepted=false**.

```powershell
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tools/measure-frontend.ps1 -FrozenInventory C:/Users/Ubehage/vscodium/UBE/bootstrap/out/frontend-input-freeze/99720b93b260412f9c33c268429ee066/inventory.json
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tools/freeze-frontend-inputs.ps1 -BaselineReport C:/Users/Ubehage/vscodium/UBE/bootstrap/out/frontend-performance/7b669fb006314b7293cf16444fc698dd/report.json
rtk proxy powershell -NoProfile -File bootstrap/out/frontend-performance/7b669fb006314b7293cf16444fc698dd/audit-baseline.ps1
```

All three commands exit0. The snapshot copies/SHA-compares164 artifacts,
including all six input/reference pairs. The bounded audit verifies335 identities
and all42 actual native stdout/control rows. Both session endpoints check277
pins, full32-logical-processor affinity and unchanged high-performance power plan.
Native hardware reports16 physical cores and34267918336 memory bytes. WMI hardware
inventory is denied and retained as a limitation; native inventory succeeds.
The original f916 baseline, five input/reference streams, repetitions and serial
guards remain unchanged. These current medians do not replace original guards.

| Corpus | Sources | Repetitions | Trials | Median seconds |
| --- | ---: | ---: | ---: | ---: |
| Expanded real | 25 | 1 | 7 | 11.5950589 |
| Original real | 18 | 1 | 7 | 9.8415284 |
| Balanced | 32 | 1 | 7 | 37.5613674 |
| Uneven | 32 | 1 | 7 | 18.7772857 |
| Small empty | 1 | 8192 | 7 | 2.2209877 |
| Small SourceInput | 1 | 16 | 7 | 1.3877478 |

Every individual wall/CPU/memory/setup/control row is retained in
`bootstrap/out/frontend-performance/7b669fb006314b7293cf16444fc698dd/report.json`,
SHA-256 `6F8683B9340BFB4F101880596EF76F706AA798631889105DD8FA529EBDC15435`.
`snapshot.json` SHA-256:
`CB518FD76ABF192F8A76CE055FD3067F412C251D674912EAE3334F8997B1AE8B`;
`audit.json` SHA-256:
`4E77E54B9395D0CA1360AD04AAEA073C9D5931AD46C2DA9B1DD4BB2810F7BCD8`.
The source reservation released only after this terminal result and freeze audit.
The approved unused-slot/caller-root patches were integrated after this freeze.
Combined Main SHA-256 is
`4517171C0AC13F734352E265C388758A4DDDD9BD49F3846C0BCF6C070128B121`.
The source fixed point passes; retained caller-lifetime35 and materialization19
checks pass. Materialization report8e9f55db04804ff6b780acc060496fd1 has SHA-256
`E8767AB31CA71850E076F613D66FC32A06CAB22C32EA951DA8FD67BF733C1B43`.
Each stage's classifier preserves exactly two borrow roots and passes2,097,226
native assertions; exact LLVM-use comparisons and four corruption controls pass.
Caller report3cc7ab9dc44342a9ac366db33aa6311c passes35 retained groups.
These focused results do not replace the full692 source gate or retained
consumer gates. The final two candidate sessions and all original thresholds
remain required; no performance acceptance is claimed.

The finite native-adapter audit found two concurrency holder roots and library
adapter admission/error cleanup paths requiring alignment with the adopted rule.
All corrections are test-only. The 30-file v3 audit and actual-registry helper
checks are retained in `bootstrap/out/caller-location-review/report.json`,
SHA-256 `86567F05FF2E8BDA7CE24C71280D893891086BDE4622B85DD70E8CFA2039B4B5`.
They cover zero/one/two available roots at the real1048576 capacity and cleanup.
Focused library checks pass byte-buffer5, managed-values52 and path7 groups.
The final path report is `bootstrap/out/path-bytes/9f737b049f7b43bc9ca09b11d3803034/report.json`.
Ignored old-code controls in adapter-unwind/6aae955c19fe47f0ad82a395299ff931
reject the former partial-admission/short-circuit cleanup; control
adapter-unwind/f3b634838f8848a89bdafe816e56d4d3 separately rejects the former
worker body-error return, detecting both retained stack roots. These proofs
precede the refreshed full source and strict consumer gates.

## Additional diagnostic scouts — 2026-11-01

These ignored-artifact experiments use frozen historical inputs, not current
production modifications or final performance acceptance. Each retains complete
source/token/node/metric comparisons and resource cleanup. The original full
serial baseline below remains unchanged. The expanded real MODULE inventory
must also be frozen before any production optimization.

`rtk proxy powershell -NoProfile -File bootstrap/out/summarize-performance-scout.ps1`
audits seven reports and their input/artifact identities into
`bootstrap/out/performance-scout-summary.json`. It records the uninstrumented
root/wait, scalar-read, call-count, neutral-frame and forced-collection scouts.
Removing 58 entirely unused generated root frames improves the focused serial
median from 0.41852 to 0.37354 seconds, but does not provide parallel speedup.
Combined immediate scalar-read fusion and neutral-frame omission measures
0.32825/0.28892/0.39789 seconds at budgets 1/2/4, versus the matched original
0.41934/0.47960/0.82168. Candidate-relative speedups are only 1.136x/0.825x.
All 27 trials retain complete work and cleanup. Separate forced-collection
variants complete 692 actual collections per budget with zero mark failures.
This suggests a focused emitter follow-up; no production emitter changed.

After those experimental reductions, root removals visit only 1/1.075/1.173
links per removal at budgets 1/2/4. An auxiliary root index is not justified by
that residual measurement. Report:
`bootstrap/out/residual-root-cost/4d9a4528f3594991b8f445969b31eeaa/report.json`,
SHA-256 `B950D54E896FA30E54F47E057AAE394DC3C21DCB84182B643DDCAFCDCA984752`.

Changing the existing Windows critical-section requested spin count to
64/512/4096 makes four-worker medians 20–25% slower, with higher CPU use.
All 36 comparison/cleanup trials pass. The report captures the installed and
later host-adjusted counts rather than assuming the requested value persists.
Report: `bootstrap/out/critical-section-spin/6c09fc1663004948b43de88f76402d09/report.json`,
SHA-256 `E14D2C2FCB3CEFFAFDA64E8348C1EA5A26D155C283F20801636D254D21A5FEA8`.
No spin-policy change is adopted.

A separate shared-leaf lock prototype is also negative: existing-exclusive
versus shared-leaf medians are 0.320159/0.315139, 0.287700/0.312445 and
0.377940/0.439481 seconds at budgets 1/2/4. All 18 work/cleanup trials pass;
independent lifetime/error/exclusion tests pass 2097202 assertions, and forced
collection completes 692 times per budget without mark failure. Reports:
`bootstrap/out/shared-leaf-lock/ae4125060a4f469ea5628584584ca5d8/report.json`,
`bootstrap/out/shared-leaf-lifetimes/c845a3161d2f417b869fa591ce587852/report.json`
and `bootstrap/out/neutral-frame-collections/70602bcce8294a3981d28f2d2a30c418/report.json`.
This prototype is not adopted; fairness and
starvation are unproven. Any new production synchronization architecture needs
concrete owner review before adoption. A further ignored-only read-epoch scout
also fails scaling: exclusive versus epoch medians are 0.332108/0.321881,
0.299971/0.272435 and 0.570083/0.535776 seconds at budgets 1/2/4. All 18
complete-output/resource trials, 692 forced collections per budget and 2097271
lifetime/error/exclusion assertions pass. Epochs add 4160 global bytes and
16 bytes of TLS depth payload per thread while retaining the original writer
critical section. No production adoption is justified by this negative result.
Report: `bootstrap/out/leaf-epochs/e20fe2b9fef840eeae36573d8c02be89/report.json`,
SHA-256 `558B490D9B98E8A20FB53E17912F2C8E34F5141AD12CEF89F70F5CE7E81F11AD`.

The expanded pre-optimization inventory is frozen separately at
`bootstrap/out/frontend-input-freeze/0b89a62dd5594492aa311a6f8d2651f5/inventory.json`,
SHA-256 `0AE18EEA5BFC6C09D4054E5E956F1BB6420AEE7FB49418615E05BAE11FD7004C`.
It retains 25 manifest-ordered MODULEs (1001192 bytes), explicitly excludes seven
CLASS bodies, and copies the original corpus/reference/repetition/baseline rows
without changing them. The expanded input stream has SHA-256
`B2297EAA26F62ECC639C98709C846C153AD1880BECF42541919A2232728C8D89`.
This is a byte/inventory freeze, not parser admission or a measured serial
baseline. Untimed reference creation, seven serial trials for expanded real,
frozen-ledger replay and both final candidate sessions remain required.

A fresh caller-count observer on the combined experimental variant accounts for
all 754769/754774/754790 collector-lock acquisitions at budgets 1/2/4, without
counter overflow. Serial counts are 217286 root admissions/removals (28.8%),
372485 array operations (49.4%, including 151064 fused Byte reads, 136645 length
queries and 84744 borrowed-address accesses), and 163376 managed-string length
validations (21.6%). Only 688 untraced plus four traced allocations occur, and
no natural collection runs inside the measured parse. These are operation
frequencies, not measured elapsed-time shares. Complete output/drain checks pass.
Report: `bootstrap/out/combined-lock-callers/8ed361845fb849c69052379e24d739a0/report.json`.
This supports narrowing the next investigation to synchronization around roots
and reads rather than speculative reclamation or worker-count changes.

The next focused candidate is ordinary UBE grammar spelling reuse, not new
runtime synchronization. The retained site observer records 74816 TrySyntaxAt
comparisons, 80628 expected-string byte reads and 6204 physical token reads.
TrySyntaxAt causes 155444 of 163376 String length-discrimination calls; a separate
observer records zero managed-header hits for this frozen workload. This does
not justify changing generic managed String behavior. The complete grammar
inventory has 174 ASCII spellings, at most 11 scalars. An ignored candidate
computes an exact folded key lazily in private cursor data and compares constant
keys, preserving public tokens/results and existing metrics. Its contract and
source draft precede production adoption; no speedup is yet claimed. Reports:
`bootstrap/out/combined-string-validation/2cef2795c73441eb9d583db0401854e4/report.json`
and `bootstrap/out/complete-grammar-spelling-inventory.json`.

After removing only obsolete Main comments/blank lines, the final pre-optimization
input freeze is
`bootstrap/out/frontend-input-freeze/72b93e88e4b045a495d59ac8876639b9/inventory.json`,
SHA-256 `04F921538D6064BD4041664AA6F6CE2CB9F892F59D249947B68BC18ED914A522`.
It retains 25 MODULEs/1000868 bytes and seven explicit CLASS exclusions.
`real.inputs` SHA-256:
`08CAE61E38D195C3E66F5C4D1300E442BB1EC67454862D9D9B12264E501602C7`.
Its parent ledgers are preserved and prove Main's remaining 15 code lines are
identical. Original corpus/reference/repetition/serial-trial bytes are unchanged.

The maintained measure tool now supports `-FrozenInventory` for expanded serial
baseline creation and `-BaselineReport` for candidate replay/two sessions.
Changed production/producer sources must be declared with `-ChangedBuildInputs`;
harnesses, scripts, contracts, manifests and toolchain drift cannot be exempted.
PowerShell AST checks and 21 static/provenance assertions pass, recorded in
`bootstrap/out/frontend-input-freeze/measurement-draft/applied-static-audit.json`,
SHA-256 `24E47B6BA2FC9065A1D3D41958EB028C9441E8A55D423222411E34BD459F6956`.
Runtime replay is unverified until the refreshed qualified cohort and otherwise
idle host execute it. Static checks are not benchmark acceptance.
Subsequent actual helper probes found two blockers: PowerShell's case-insensitive
numeric Bytes parameter collides with a local byte buffer, and candidate replay
did not bind a previous expanded baseline's corpus/repetitions back to its
authoritative frozen ledger. Probe:
`rtk proxy powershell -NoProfile -File bootstrap/out/frontend-replay-review/probe.ps1`.
The incomplete 638-assertion refresh `6db31e5d2e6044cbb15ce326241dd359` was
deliberately interrupted to repair these tool defects. The earlier 636 cohort
remains the last accepted checkpoint. Focused dynamic helper regressions and a
new source refresh are required before measuring; no compiler/runtime defect or
performance result is inferred from these tool failures.

Both reproduced defects are now corrected. The byte buffer has a distinct name;
candidate admission binds the six ordered corpus roles, input/unit/reference
identities, repetitions, original guards, seven successful serial controls and
recomputed medians to their frozen authority. Expanded-reference creation
provenance is retained and checked. The independent reviewer reran the retained
helper and all **27 assertions pass**:

```powershell
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/concurrency/frontend-replay.ps1 -FrozenInventory bootstrap/out/frontend-input-freeze/72b93e88e4b045a495d59ac8876639b9/inventory.json
```

Report: `bootstrap/out/frontend-replay-regression/07eb2fd158a740aa8fc5e35e1189b355/report.json`,
SHA-256 `36E8702562E2BDCB9A3289E30AF838B94FCAA1417CF5AAC7DD4D712C376909B7`.
The corrected measure tool has SHA-256
`4A211845CA44A8FC1B66CF242B035DDD49AD63F4C030A3D7730C46CA96E8109F`.
Separate pure orchestration probes retain all 252 rows/two sessions/12 summaries
in both passing and failing timing scenarios, and reject independently mutated
source order, payload hash, historical repetitions and reference metadata.
These are actual helper executions with mocked external effects, not native
benchmarks or source qualification.

The refreshed immutable inventory, including the corrected tool and retained
helper, is `bootstrap/out/frontend-input-freeze/46697470a06c4e60bbb716c929d452f5/inventory.json`,
SHA-256 `7CD5FE8452FC3F2072744914AD48C3E5E24602A76D7811DC4498D2D5E5F8B2E0`.
The prior ledger is preserved, and the 25-MODULE production input stream remains
byte-identical (`08CAE61E38D195C3E66F5C4D1300E442BB1EC67454862D9D9B12264E501602C7`).
Use this latest ledger for the expanded serial baseline after source refresh.

The isolated spelling-cache experiment is negative under unchanged production
lowering and is **not adopted**. Both accepted stages emit identical candidate
LLVM (`B694D1E7C3A25393EE1576B3C6A8BC310B6612108FEFA746821C66EBB07F2B12`).
Twenty-five independent reader/cursor vectors pass 222 baseline/254 candidate
assertions, including malformed suffix demand boundaries, invalid spans,
Unicode folding, delimiters, incorrect keys and cursor consume/restore. All 18
matched trials retain complete outputs/metrics and resource cleanup. Medians
for four fresh focused parses are:

| Workers | Baseline seconds | Candidate seconds |
| --- | ---: | ---: |
| 1 | 1.35709 | 1.92196 |
| 2 | 2.80688 | 4.13704 |
| 4 | 6.02832 | 8.59314 |

Final identities, contracts, all 322 changed sites/173 folded keys, vectors and
individual trials are in `bootstrap/out/spelling-reuse-draft/refined/final-report.json`.
Report SHA-256: `82D02C96A3AE1725A009B9DC8FAE279E6907355BCCE828EE2F48F9F0ECFE504F`.
Static lowering changes TrySyntaxAt from 13 to 46 root admissions per successful
entry, predominantly compiler-created private value slots (10 to 43). At the
retained 74816 comparisons this derives 2468928 additional admissions and matching
removals; this is a static derivation, not an executed counter or sole timing
attribution. The next diagnostic audits exactly which generated value slots are
actually materialized, before changing root representation or collector design.
No production source/GC/root/wait optimization has been adopted.

The owner explicitly adopted CALLER-ROOT-PROPOSAL.md on 2026-11-01: retain the
writable caller location or precisely traced containing owner throughout each
managed ByRef call, including newly assigned values; omit only exact duplicate
callee argument roots. All other roots, value semantics, collector and public
foreign ABI remain. Native test bridges must obey the same retention obligation;
the existing empty-document OOM fixture has a concrete correction strategy that
preserves genuine failure coverage. Scope approval does not waive qualification.

The additional lifetime proof uses both accepted tools, original/elided LLVM
and ordinary/forced collection. Forty positive executions require actual
collection after nested-callee return and before any new borrow/read; no pending
or pinned value masks retention. Twenty dead-watch controls and four original-
callee unrooted-slot contrasts pass, with independent contents and cleanup.
Report: `bootstrap/out/caller-rooted-byref-review/6fd0be192840404ab935acdd2810bfb7/report.json`,
SHA-256 `68EA4E012E56F789CBD4DD371D9400F9CF69D71F13CEE75C1D1D79128999806F`.
These supplement the earlier 56 lifetime/watch executions. Production changes
remain pending the frozen expanded serial baseline and all stated gates.

After the reserved-name correction, the latest pre-optimization ledger is
`bootstrap/out/frontend-input-freeze/99720b93b260412f9c33c268429ee066/inventory.json`,
SHA-256 `78934B716272A3A7A8B3610971FD5BF32C988CAED2000B61D40591FBA6DB50FA`.
It preserves every earlier ledger and historical input/reference/repetition/
serial guard, and freezes25 MODULEs/1000934 bytes with seven CLASS exclusions.
Input stream SHA-256:
`F9439943F7540D0D7A8E9CC12CA7ED2DBABF6EDDF653922525200D882F16A450`.
Its sole production delta is exactly six Inline→InlineCoordinates replacements
(+66 bytes); CLI regression/inventory/helper changes are recorded separately.
No performance code is adopted: production v2 Main is still
`2B463E638D4993C1C9677A24B8F1462FBC2D8A021F0E829A84062F8B264FA9F8`.
Use this latest ledger after the current source qualification/admission completes.

Status: pre-optimization baseline frozen; focused diagnostics passed their
comparison/cleanup assertions. **The parallel performance gate is unfinished.**
No production compiler, UBECore or runtime code was changed by these measurements.
Project input and new path APIs are not implemented by this evidence.

## Exact procedure and frozen cohort

Commands, run from the repository root:

```powershell
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tools/measure-frontend.ps1
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tools/freeze-frontend-inputs.ps1 -BaselineReport bootstrap/out/frontend-performance/f9167dcd59e9495aa46de5e764be88f7/report.json
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tools/measure-root-cost.ps1 -BaselineReport bootstrap/out/frontend-performance/f9167dcd59e9495aa46de5e764be88f7/report.json
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tools/compare-root-cleanup.ps1 -RootCostReport bootstrap/out/root-cost/0f5a3bea9a4c4a09bfa3d2920cd1c1ee/report.json
```

The baseline reports success/frozenBaseline true, performanceAccepted false.
It uses the accepted source-built cohort whose manifest SHA-256 is
`138B17C45681B02999961D0EB5A76430667D5D5AC1F3A7091822A6724A62C97F`.
Both source-built stages emitted the same raw consumer LLVM:
`FBBDDCDCCEBD47C6BECFFF8447156040BFD23A73DCBBCA9C47B0D8FE7E3B8E06`.
Full source/tool/compiler/adapter/corpus identities and exact native commands
are in the report; 65 source/harness/corpus/reference/native artifact copies
were saved and SHA-256 compared under its `snapshot/` directory.

Native compilation uses the selected clang, target
`x86_64-w64-windows-gnu`, `-O2`, the unmodified C runtime and selected Unicode
runtime object. Only exported measurement entry wrappers and the unused native
main name differ from raw UBE emission. No observer or scheduling hook enters
the baseline. The production UBE source qualification and `TryParseSources`
execute all real source work and scheduling.

Host: AMD Ryzen 9 3950X, 16 physical/32 logical processors, 34267918336 physical
memory bytes. A live measurement process had affinity mask 4294967295, covering
all 32 logical processors. Power plan was AMD Ryzen High Performance, GUID
`9935e61f-1661-40c5-ae2f-8495027d5d5d`. Windows registry build was 26300.9711,
DisplayVersion 26H2; registry ProductName reports Windows 10 Pro. CIM inventory
was denied, so the report records registry/native fallback observations rather
than claiming successful CIM verification.

## Seven-trial serial baseline

All five corpora have seven recorded trials. Pilot-selected repetition counts
were then fixed; each repetition performs fresh work. Time is the summed work
interval per batch, including native worker startup/publication/drain, excluding
intake, warming, result comparison, collection and process launch. Every trial
compares complete original documents, tokens, nodes and metrics against its
frozen serial stream and checks root/payload/worker cleanup. A corrupted stream
negative control failed as required.

| Corpus | Sources / bytes | Repetitions | Median seconds | Min..max seconds | Median process CPU seconds | Maximum process peak working-set bytes |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Real production MODULEs | 18 / 890798 | 1 | 9.628890 | 9.559218..9.690271 | 18.937500 | 45858816 |
| Balanced complete SyntaxExpressions MODULEs | 32 / 2114870 | 1 | 36.817091 | 36.764990..36.889522 | 72.140625 | 149143552 |
| Uneven large/small MODULEs | 32 / 1060598 | 1 | 18.377307 | 18.285388..18.526790 | 36.000000 | 77287424 |
| One empty MODULE | 1 / 49 | 8192 | 2.031594 | 2.007388..2.045926 | 1.046875 | 4808704 |
| One SourceInput MODULE | 1 / 5936 | 16 | 1.307684 | 1.305642..1.314591 | 2.562500 | 6168576 |

CPU samples use process user+kernel counters around individual work calls;
short-call CPU accounting is quantized. Peak working set covers the whole
process, including warmup/checks, not just the work interval. All individual
wall/CPU/memory/setup/total rows and corpus bytes/hashes are retained. The three
production CLASS bodies are explicitly listed as unsupported grammar. The real
inventory is the pre-optimization inventory; if that inventory grows before
optimization, preserve this baseline and freeze the additional required real
inputs before changing performance code.

Report SHA-256:
`15B0156D8CF7EE418A2EE2B5AC3DD695B55212AD94CFA0C9335A31D957074B54`.
Snapshot ledger SHA-256:
`E48E7B3A63E55F06A985CB8F492200E9ACA7A640D322336C5E5925A19ABF93F7`.

## Focused actual-UBE root diagnostic

Four complete SourceInput MODULEs with distinct names use the same frozen UBE
consumer. Diagnostic-only runtime counters increment under its existing collector
lock. Expected complete outputs come from the frozen uninstrumented executable.
No C worker replaces the UBE work. Every budget performed exactly 4591213 root
admissions and removals, matched every complete result and drained resources.

| Budget | Collector lock acquisitions | Root-list links examined | Peak roots | Diagnostic work seconds |
| --- | ---: | ---: | ---: | ---: |
| 1 | 10240328 | 114447448 | 1838 | 0.367765500 |
| 2 | 10212358 | 301090929 | 3580 | 0.713040000 |
| 4 | 10189533 | 662137042 | 6869 | 1.939135900 |

This directly observes linear root-removal scans and their growth with live
workers. About 90% of the observed lock acquisitions are root admission/removal
calls. The emitter already omits scalar-only roots; a proposed scalar-only-root
fix would not address this measured cause.

Report: `bootstrap/out/root-cost/0f5a3bea9a4c4a09bfa3d2920cd1c1ee/report.json`.
SHA-256: `425C25C01B2D5AC045AC8FA8176EC8E831C676B04F990227F9FA01B369879304`.

## Smallest cleanup-order experiment

An explicitly experimental LLVM copy reverses only contiguous procedure-root
cleanup calls: 88 blocks, 3638 calls. Applying the reversal twice reproduces the
original LLVM exactly. Root layout, runtime, admission, work bodies and complete
reference results are unchanged. All three budgets still perform exactly the
same 4591213 root admissions/removals and pass complete-result/cleanup checks.
This experiment has productionQualified false and performanceAccepted false.

| Budget | Root-list links examined | Peak roots | Diagnostic work seconds |
| --- | ---: | ---: | ---: |
| 1 | 4591213 | 1838 | 0.271795100 |
| 2 | 188907446 | 3580 | 0.593508400 |
| 4 | 540146230 | 6900 | 1.744375000 |

Reverse cleanup removes serial list searching but leaves substantial cross-worker
scanning and root-registration locking. It is insufficient as the whole parallel
solution. These one-trial instrumented timings are diagnostic observations,
not the required uninstrumented two-session speedup acceptance.

Report: `bootstrap/out/root-cleanup/a1bf527ba99145f3a3b6a02a63df9f09/report.json`.
SHA-256: `70BE12E8806B1038517D08FD293AB1CE7D399F225E0F592102FA429D4BB15E10`.

## Further focused root and wait experiments

These are historical diagnostic experiments on the frozen pre-path-API cohort,
not production changes or speedup acceptance. They retain the actual UBE worker
and compare complete source/token/node/metric results and cleanup. One measured
trial per budget cannot establish the required performance gate.

`compare-procedure-roots.ps1` groups the same private managed values into 86
precise procedure frames under the existing 32-byte root ABI and existing layout
entry, preserving original initialization and external ByRef roots. It changes
3458 private root sites in experimental LLVM only. Admissions fall from 4591213
to 1005407 at each budget; root-list visits become 1523109/2825167/5649488 for
budgets 1/2/4. Instrumented work times are 0.0955622/0.1473974/0.4439553 seconds.
Report `bootstrap/out/procedure-roots/2684cb180c7c46bcb570fc011d6c390c/report.json`,
SHA-256 `8270E7446EA6DB06A98F17DC35472F2A7C6E26C0495E71F12D4585077D10D564`.

`observe-procedure-roots.ps1` separately observes full collection completion and
collector-lock callers. The final collection observer counts the executed end of
mark/sweep under the collector lock, not merely a collection request or the
reclaimed-anything return value. All budgets complete 692 requested collections
with zero mark failures and equal complete outputs. Report
`bootstrap/out/procedure-root-observation/3fa6efd2a6ac4c479276751005f281f9/report.json`,
SHA-256 `4C38168197831A02E73355F470EA1B4CD6AEEFDE72B9CC71549BFC98185C47EE`.
Earlier call-only counters were insufficient; an intermediate observer also
misread an empty successful collection as a failure. Neither is current evidence.

The final lock-caller observer has no counter overflow and accounts for every
acquisition. Serial totals include 1004732 layout admissions, 1005407 removals,
475358 element accesses, 119951 value snapshots, 163376 managed-string length
queries and 136645 array-length queries. Report
`bootstrap/out/procedure-root-observation/e4a9d3ade7cd4ffb802fcae8158dc42c/report.json`,
SHA-256 `3DF682DD1096E607B779E219A973DC8B0A2F417F262DBB671DC08ACA302D16B9`.

`compare-borrowed-roots.ps1` additionally omits 180 duplicate callee root sites
only when their address is exactly a caller-retained ByRef parameter. Private
frames, ByVal values, results, captures, borrowed-element owners and runtime
roots remain. Admissions become 332667 at each budget. Ordinary instrumented
work is 0.0616587/0.089902/0.236359 seconds; forced-collection work is
0.0791294/0.102169/0.244876 seconds, with 692 completed collections and zero mark
failures per budget. Report
`bootstrap/out/borrowed-roots/0e6c4e2d7f2e4880863237031b36a0cc/report.json`,
SHA-256 `A853E31569B62D17B23573F45B2BCE0519D43E561F82DFC4B486BB163FB3CCFE`.
Foreign/unrooted callers are outside this experiment; no production ABI changed.

`compare-wait-policy.ps1` tests replacing the single zero-time coordinator wait
with a one-millisecond timeout, without a forced sleep or a second scheduler.
The root-reduced variant measures 0.0510954/0.0639074/0.1193271 seconds and process
CPU 0.046875/0.125/0.46875 seconds. Complete outputs and unchanged root work pass,
but this still fails parallel speedup. Report
`bootstrap/out/wait-policy/1a2971fe566342bf9e93c4d54ec6120f/report.json`, SHA-256
`23EB35775177B549F934CEE5A41D32DBD98636BA7E8D62034E857EAD8EED1D01`.
It predates the corrected borrowed-root collection observer; it makes no new
collection-completion claim. Host timeout overshoot remains possible.

`check-borrowed-lifetimes.ps1` supplies a separate lifetime proof: seven cases,
two original accepted stages, original/elided callee roots and ordinary/forced
collection execute 56 times with exact independent stdout and zero remaining
roots/payload. Array-element and reference-class-field owners are dropped inside
the callee, then collection/read/write/resize are checked. Native liveness
watches are not roots; 40 observations require the exact borrowed byte/field
address to remain inside a live managed allocation after actual collection.
A deliberately watched stack byte is rejected with controlled exit 92 before
dereferencing it. Report
`bootstrap/out/borrowed-lifetimes/e601e5af38614f548eb8aa30cd56bc28/report.json`,
SHA-256 `363DF272F4AF38902CA96A7AE12C5ACC9DB3C520441D97FCF086699FDB7AF5F8`.
This does not qualify a changed production emitter or unrestricted foreign ABI.

The new path prerequisite changes the current source cohort after these probes.
Frozen reports/LLVM/runtime artifacts remain historical evidence; do not rerun a
historical source-pinned script against changed inputs and call it the same run.
No root/wait optimization has been adopted in production. Expanded real MODULE
inputs must be frozen before any production performance change.

## Remaining work after initial acceptance

Continue toward the original 1.5x/2x engineering targets as later optimization
work, retaining the frozen baselines and all correctness/resource guards.
The completed initial frontend goal has no remaining acceptance blocker.
The existing next proposed deliverable is the first semantic-checking contract:
inventory retained declaration information, define bounded binding/type rules
and independent expectations, and preserve spans, deterministic errors, private
results and one worker budget. Semantic implementation needs that contract and
owner review. No push or new compiler generation is authorized by this record.
