# Native build resource oracle: review draft

These are future acceptance tests, not measurements or evidence that the
compiler already implements native lowering. `../../NATIVE-RESOURCE-CONTRACT.md`
selects initial numeric budgets, accounting units, serial storage/traversal and
algorithmic bounds. Measure the implementation against those choices; existing
frontend measurements do not qualify the new consumer.

The selected LLD `--threads=1` setting is not an operating-system thread cap:
the reviewed Windows linker also creates asynchronous file-reading work. Count
the actual contained tool tree's processes, threads and memory separately from
compiler-owned worker/storage charges. A single scheduled external invocation
is not evidence of one OS thread or a bounded tool peak. The explicit support
test records the input cohort and selected environment, not these resource peaks.

Use a test-only interface to supply each supported limit and read high-water
marks. It must exercise the production allocator, lowering, worker coordination
and output paths; an oracle that simply echoes the requested limit proves
nothing. Record the compiler identity, sources, limit settings, worker count,
observed consumption, result and surviving artifacts. Check diagnostic UBE1502
and the resource category where the candidate contract prescribes them. A
resource failure is not an invalid-program diagnosis.

The selected tool-output retention ceiling is 4096 raw bytes per stream. Test
both streams at their ceiling and the maximum specified escaped expansion:
8192 raw bytes plus up to 49152 rendered excerpt bytes when all four buffers
are simultaneously live. Account for labels, paths, pipe buffers and process
state separately. A streaming formatter may retain less, but the measurement must
reflect its actual live allocations; when tools overlap, include every active
tool in the shared budget. This test does not fix the unrelated lowering or
candidate-file budgets.

Candidate storage needs two distinct observations: maximum candidate length
accepted for validation and maximum disk consumption while external writers
run. A test-controlled child must signal readiness, then write past a small
configured bound between two observations. A hard bound is established only
if the selected mechanism prevents the excess write or allocation; detecting
the excess after the write demonstrates rejection, not a storage quota. Test
temporary files and concurrent descendants in the same accounting scope and
record whether the bound covers logical file length, actual allocated storage,
or both, including sparse files. Verify controlled failure, cleanup and
old-output preservation. If a host or
mechanism cannot enforce the claimed quota, require its specified safe failure
or explicitly classify the limit as post-write validation instead.

The host-only `verifier/check-candidate-burst.ps1` demonstrates the sampling
gap with a barrier: a 0-byte sample was below a 4096-byte test limit, and the
controlled writer completed 65536 bytes before the next sample. Command:

```powershell
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/verifier/check-candidate-burst.ps1 -OutputDirectory bootstrap/out/candidate-burst
```

This test deliberately does not sample while the writer runs; it establishes
the concrete counterexample, not a measured worst-case overshoot, a filesystem
quota, actual allocated disk blocks, or behavior of the UBE compiler.

### Windows storage quota review

The default build contract must not call a post-write candidate length check a
hard disk quota. The following host facilities have different scopes and are not
interchangeable:

| Facility | Documented scope | Review disposition |
| --- | --- | --- |
| NTFS disk quota | The [quota is charged to the file owner on a volume](https://learn.microsoft.com/en-us/windows/win32/fileio/disk-quota-limits), summing data stream lengths; it excludes some metadata and may be configured to deny further space. | Not a per-build quota: other files belonging to the same owner can affect the limit, and the volume's settings and quota coverage must not be silently changed by the compiler. |
| FSRM directory quota | A [hard directory quota](https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-fsrm/592dad39-f14e-4c5b-b7bc-a1c0bc4724b3) blocks file I/O exceeding its limit and accounts for a filesystem tree using implementation-specific mechanisms. Microsoft's [FSRM overview](https://learn.microsoft.com/en-us/windows-server/storage/fsrm/fsrm-overview) describes it as a Windows Server role service with NTFS support. | A possible separately provisioned host capability, not a portable default for the first compiler. A quota on one tree also does not account for a tool writing elsewhere. |

Therefore the reviewed baseline should enforce a bounded *accepted candidate
length* after the tool has stopped writing, and report oversized output as a
controlled prepublication failure. It must handle disk-full errors and preserve
the old executable, but this alone does not bound temporary disk consumption
while the tool runs. A future hard-quota claim requires an explicitly selected
host facility, accounting scope, writer confinement, privilege/deployment
requirements and the burst, sparse-file and descendant tests above. This is a
contract disposition, not evidence of an implemented validator or quota.

For the circular-initialization warning, test the checked dependency graph at
increasing sizes, including a simple acyclic chain and the same chain with one
closing edge. The future build must warn on the detectable cycle, not reject
it, and must not report a cycle for the acyclic control. At jobs 1, 2 and 4,
record graph vertices, dependency edges, actual visits, allocations, retained
bytes and warnings, with forced alternative worker completion orders. Check the
reviewed shared budget and traversal work bound; do not infer complexity from
elapsed time or silently drop a warning when a budget is exhausted. Test a
controlled resource failure separately from a nonfatal warning.

`additional/check-initializer-graph-scale.ps1` generates simple 32-, 64- and
128-module acyclic chains and corresponding rings, then tests frontend admission
at jobs 1 and 4. Both local stage CLIs passed 12 checks each. For each stage:

```powershell
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/additional/check-initializer-graph-scale.ps1 -Compiler <stage>/ube.exe -OutputDirectory bootstrap/out/initializer-graph-scale
```

The generated fixtures have not been built or run as native executables and do
not measure warning-analysis work, memory, determinism or cancellation.

The selected analysis in `NATIVE-BUILD-DIAGNOSTICS.md` now fixes the units:
module roots, executable nodes/calls, ByRef formals/mappings, dependency pairs
and component traversal. Instrument root-body visits, false-to-true formal
transitions and examined outgoing mappings separately. Add recursive forwarding
with no root seed, with one seed and with repeated call-site seeds; body discovery
must not rescan every body on each propagated bit, and already-true formals must
not requeue their outgoing mappings. Every qualifying incoming edge must still
participate in canonical witness selection. Check its stated work/storage
bounds, reused root scratch and shared byte accounting; the policy model does
not measure production allocation or source traversal.

For the same generated chain/ring fixture set,
`additional/check-initializer-scale-graph.ps1` independently checks the manifest
source order and generated source text, then checks every retained dependency's
source anchor and resolved declaration target. Both targeted 25f stage
observers passed all 12 size/cycle/job combinations. Three controls per case
changed the first dependency, the cycle-closing dependency or acyclic terminal
literal, and a source anchor; each was rejected. The observation stream matched across jobs 1 and 4 within each
combination. For each observer, use the fixture directory printed by the
generator, for example:

```powershell
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/additional/check-initializer-scale-graph.ps1 -Observer <observer-path> -FixtureDirectory bootstrap/out/initializer-graph-scale/24fbf04b3b084ad39ed93a820f0a7dd6
```

This checks the retained dependency links for those generated cases. It does
not execute warning analysis, establish a work bound, or prove all possible
module or procedure graphs are represented correctly.

The separate `check-sparse-candidate.ps1` host probe created a sparse test file,
wrote one byte near its end, and queried Windows file information after a flush.
On this filesystem it reported a logical length of 33554432 bytes and an
allocation size of 65536 bytes; it removed the test file afterward. The command
returned 0:

```powershell
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/verifier/check-sparse-candidate.ps1 -Clang 'C:\Program Files\LLVM\bin\clang.exe' -OutputDirectory bootstrap/out/sparse-candidate
```

This demonstrates that these two accounting quantities can differ on the
tested host. It does not establish a filesystem quota or measure all temporary
files, metadata, compression, deduplication, or storage consumed by a real
linker. An unsupported sparse-file operation causes the probe to fail rather
than be counted as evidence.

At an instrumented barrier during lowering, keep a nonempty checked graph and
source owners live while at least one worker holds scratch and an unpublished
result. Record their charges and the simultaneously live total, including
allocator overhead if the selected accounting claims to cover it. Separately
observe the tool-handoff overlap, including the retained input and diagnostic
buffers that actually coexist. Verify that live categories are neither omitted
nor double-charged as ownership transfers. If a shared process-wide limit is
selected, exercise below, exact and above the observed combined requirement and
verify controlled failure and preserved output below it. Deliberately omit a
live category in a comparator control and require that control to fail. Record
external tool and OS allocations separately unless the selected limit explicitly
includes them; do not imply their inclusion from a compiler allocator counter.

For each independently configurable quantity (including generated output,
pending work, structural depth, symbols, tool arguments and candidate storage),
prepare a fixture whose actual measured consumption is known. Run with a limit
below that consumption, exactly equal to it, and above it; include zero and an
empty or minimum valid input when applicable. The exact case succeeds only when
all other limits are generous; the below case fails in a controlled manner.
Use a deliberately wrong expected high-water mark as a negative comparator
control. Verify the unit and whether the bound counts live, cumulative, reserved
or committed quantities before interpreting a boundary result.

For the selected serial baseline, observe the current module buffer, prepared
and published snapshot arrays, maps/stacks and warning-analysis state at their
actual overlap points. Check old/new resize capacity together. Retained checked
owners are measured separately, not charged to the lowering payload cap. Use
multiple modules to verify cumulative emitted bytes and reuse of the buffer;
do not require snapshots from separate modules to remain live. Jobs 1/2/4 must
produce the same lowered bytes and resource outcome, while preserving the
existing frontend concurrency gates.

The next three paragraphs are conditional gates for later parallel lowering,
not requirements to add parallel lowering to the selected baseline or evidence
that a serial run establishes concurrent accounting.

For shared budgets, distinguish retained results from temporary worker scratch.
Use at least two modules whose retained outputs must coexist and whose combined
actual charge exceeds the budget. At jobs 1, 2 and 4, require controlled failure
without oversubscription, leaked reservations, partial output or a changed
pre-existing executable. At the exact combined budget, require success and
compare generated bytes and execution result across worker counts.

Separately choose modules whose temporary scratch fits when processed serially
but would exceed the shared limit if both workers held their peak scratch at
once. A conservative reservation must not reject a build whose actual serial
consumption fits. The scheduler may delay admission or fall back to serial work;
require success and the same result as jobs 1 without exceeding the limit.
With a sufficiently larger budget, coordinate two workers at a barrier to prove
the simultaneous-accounting case actually ran, and repeat with completion order
reversed. The harness must observe the barrier and actual peak usage; a run that
serialized workers does not prove concurrent accounting. This follows the
existing semantic controller's no-false-budget-rejection rule, not an assumption
that every per-worker peak must coexist.

One test-controlled accounting example makes the serial fallback observable.
Assume the test instrumentation charges exactly the listed units and no others:
20 units of earlier retained output; module A uses 40 scratch and retains 10;
module B uses 50 scratch and retains 15. If a result is allocated while its
worker still holds all scratch, A's overlap is 70 and B's later overlap is 95;
the final retained total is 45. With a shared limit of 100, serial execution
therefore fits, whereas admitting both workers while they hold their full
scratch would require at least 110 before either result is allocated. Pause at
the scratch and result-allocation boundaries and observe the real charges; the
numbers are a synthetic scheduling oracle, not proposed production defaults.
At limit 100 require successful serial fallback and peak at most 100. At a
sufficiently high limit, require both workers at their scratch barrier, observe
the simultaneous charge and run both completion orders. An implementation may
use different actual sizes, but then the harness must derive an equivalent
case from measured charges rather than pretend these illustrative units were
allocated. Account for real allocator metadata and every other live category
whenever the production limit claims to include them.

Inject failure after a successful reservation but before ownership transfer,
and separately while a worker is cancelled or drained. Verify every reservation
is released exactly once and no consumer uses released source or output storage.
In a subsequent independent build in the same process, verify the full budget
is available again. Exercise allocation failure and checked size arithmetic
overflow separately; neither may wrap into a smaller allocation or publish a
partial executable. For each precommit failure, compare the old destination
bytes or continued absence and account for tools and owned temporary files as
specified in `FAILURE-ORACLES.md`.

Measure actual visits, allocations, growth-copy and zeroed bytes on increasing
inputs, as well as peak retained memory and per-worker scratch. Compare jobs 1,
2 and 4 against the serial reference, and inspect counts rather than inferring
complexity from elapsed time. Include many small appends and many modules to
expose quadratic copying or a whole-project scan per emitted node. These checks
do not set a numeric budget by themselves and do not claim a parallel speedup.
