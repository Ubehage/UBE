# Frontend performance measurement contract

Status: measurement procedure for the active bounded project/frontend goal.
The acceptance thresholds remain those in
[Development-Plan.md](../../project-docs/Development-Plan.md#parallel-performance-acceptance).
This document does not approve a runtime architecture change.

## Frozen work

Before changing production performance code, `tools/measure-frontend.ps1`
creates an immutable run directory under `bootstrap/out/frontend-performance/`.
Its input ledger identifies every source, runtime, adapter, tool, fixture and
script. The representative `real` corpus includes every `.bas` Source in the
current compiler and UBECore manifests, in manifest order. CLASS files are listed
as unsupported body grammar, rather than silently counted as parsed work.

The `balanced` corpus has 32 independent native MODULE inputs derived from the
complete production `SyntaxExpressions.bas`, with distinct `UBE_Name` values.
Only that envelope attribute changes; the real declarations and procedure bodies
remain intact. This is syntax work, not a claim that those modules bind together.
The separate `uneven` corpus alternates 16 such modules with 16 complete
`LibraryIdentity.bas` modules, also with distinct names. Small guards are a single
empty native MODULE and a single complete `SourceInput.bas`. All bytes, order,
counts and hashes are frozen before optimization. Do not regenerate a candidate's
corpora from its changed sources.

The harness calls actual UBE `TryMakeSourceOwner`, then `TryParseSources` with
the unchanged scan/parse bodies and the same limits at budgets 1, 2 and 4. C only
loads test bytes, calls the UBE entry points, measures time and asserts results;
it supplies neither parsing nor worker scheduling. Three production classes
retain source lifetime, private outputs and cancellation. No profiler, allocation
observer, rendezvous, schedule control or forced completion order enters this
executable. Both accepted source-built stages must emit identical raw LLVM.
The native runtime and LLVM are compiled together with `-O2`, the same target,
tool and flags for baseline and candidate.

## Complete-result comparison

Before timing, the frozen baseline creates a serial reference stream per corpus:
every source ID, document position field, original byte, token kind/position,
syntax result/count/root, every node field and every syntax metric. Integer
fields are serialized separately; padding and worker identity are excluded.
Its byte identity is frozen. It is a differential reference from the previously
qualified parser, not an independent oracle for language semantics. Existing
independent parser/CLI/concurrency gates remain mandatory.

Each trial first warms the same corpus with a fresh one-worker parse, validates
against that frozen stream, releases its output, and collects outside the timer.
Every measured repetition again performs fresh work, validates the complete
result outside the timer, releases it and collects. Original inputs must still
match the corpus. Success requires complete outputs, accepted states/status,
stable owner references, worker drain, baseline root count after each repetition
and zero owned payload/roots after final cleanup. A corrupted reference negative
control must fail. These checks do not replace the separately instrumented
failure/copy/root/memory gates.

## Timing and reporting

Time only the call to `TryParseSources`: qualified owners admitted through full
publication and drain, including native thread startup and synchronization.
Use QueryPerformanceCounter and process user+kernel CPU time. Report process peak
working set, setup/warmup/check/collection time separately from summed work time,
and whole-process duration in the orchestration report. Project end-to-end timing
is still pending the production project driver.

A pre-optimization pilot chooses a fixed repetition count per corpus by doubling
until at least 1.25 seconds of one-worker work, capped at 16384. Freeze those
counts for baseline and candidates. Every baseline/candidate comparison uses the
same frozen bytes, expected streams, repetition counts, flags and timing boundary.
Record all pilot results; do not use them as acceptance trials. Freeze seven
one-worker baseline trials for the one-worker regression guard before optimization.

Final acceptance needs two complete sessions, each with at least seven trials
per budget per corpus. Within each round rotate budget order `1,2,4`, `2,4,1`,
`4,1,2`; reverse corpus order on alternate rounds. Keep every trial. Record CPU,
physical/logical cores, OS, power plan, memory, exact tools and source identities.
Use an otherwise idle host with at least four physical cores available. Report
medians, min/max, all CPU/memory rows, and each target comparison in each session.
If variation makes results unreliable, repeat the complete session and retain
the inconclusive one. A pilot or a baseline run is not performance acceptance.

Both main corpora must reach 1.5x at two workers and 2x at four. Candidate serial
median must be at most 1.05 times its frozen serial baseline. All small guards,
including one source with budget four, must stay within 1.10 times candidate
serial median. Uneven results are reported, never discarded. Do not lower limits,
skip work, cache parse results or alter thresholds after observing a failure.

After any production optimization, rerun all applicable retained gates on the
same source cohort and record exact report/tool/source identities. Correct
results, successful builds, or a speedup on one corpus cannot complete the goal.

## Frozen replay procedure

`measure-frontend.ps1 -FrozenInventory <inventory.json>` extends the original
baseline using the snapshotted manifest inventory. It preserves all five
original corpora, reference streams, repetition counts and serial guards, adds
the expanded real corpus, and creates its reference through both identical-LLVM
source-built stages before freezing seven serial trials. A source/hash mismatch
rejects the ledger; new inputs are never silently regenerated from a candidate.

`measure-frontend.ps1 -BaselineReport <expanded-baseline-report.json>` builds the
candidate against those exact six corpora and runs both complete sessions.
`-ChangedBuildInputs` explicitly declares reviewed consumer/runtime/producer
source differences. It cannot authorize harness, measurement, contract, manifest
or toolchain drift. Independently source-qualified compiler artifacts may change
when an approved optimization changes their producer sources; both cohorts and
every difference remain recorded. Exact clang/Unicode-runtime/target/flags and
the native timing/comparison boundary must match.

Frozen replay requires complete qualified runs; partial/diagnostic replay modes
are rejected. It retains every trial even when a timing threshold fails and
reports the failed comparison. These tool paths require actual execution before
their static checks can be described as measurement verification. Their presence
does not constitute performance acceptance.
