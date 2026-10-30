# Compiler v3 multithreading plan

This plan schedules compiler parallelization after the RP8 language, project,
library-bundle, debugger-metadata, and portability closure. It is Beta 1
performance work, not a new compiler generation or a change to UBE language
semantics.

The objective is to reduce wall-clock compile time on multi-core hosts while
preserving the trusted v2 bootstrap, byte-for-byte deterministic output,
bounded resource use, stable diagnostics, and the never-crash rule.

## Non-negotiable constraints

- `--jobs 1` remains the simple reference implementation and must produce the
  same observable results as every parallel job count.
- Worker completion order must never determine symbol IDs, type IDs, diagnostic
  order, IR order, metadata order, object contents, or artifact hashes.
- Expected thread, allocation, cancellation, and worker failures return a
  controlled compiler diagnostic and leave no partial success artifact.
- Workers operate on immutable inputs or worker-owned storage. Shared mutable
  compiler state has one explicit owner and is changed only during deterministic
  merge steps.
- Parallel work must not hide an inefficient algorithm. Profile and repair
  avoidable superlinear paths before adding workers.
- The preserved Compiler v2 and sequential v3 bootstrap remain reproducible.

## Bootstrap architecture decision

Preferred design: split the bootstrap chain into a sequential seed compiler and
the production compiler without adding RP7 language features to Compiler v2.

1. Preserve a v2-buildable `UBE_Compiler_v3_seed.UBE` manifest containing the
   sequential compiler subset required to build the production compiler.
2. Let the seed compiler build the full `UBE_Compiler_v3.UBE` project, whose
   driver and executor may use verified UBE 1.0 threading facilities.
3. Have the resulting production compiler rebuild itself twice. Stage-two and
   stage-three LLVM and normalized objects must satisfy the existing fixed-point
   policy.
4. Keep the seed build and `--jobs 1` production build as permanent gates.

Before implementation, record a short design decision comparing this split
against a compiler-private executor ABI. Extending Compiler v2 with `CallNew`,
managed captures, or general thread-aware shared state is the fallback only if
the seed/production split proves impossible; ordinary language growth must not
be copied into the transitional compiler merely for build speed.

## Parallel execution model

Add a compiler-owned bounded executor with an explicit `--jobs N` option.
`--jobs 1` is always supported and remains the default. Parallel compilation
is caller-selected; the compiler does not silently consume every detected
processor. The effective count is bounded by the number of runnable tasks and
both requested and effective counts are recorded.

The coordinator owns the build phase and publishes numbered immutable tasks.
Workers return results in worker-owned arenas. The coordinator merges results
strictly by stable source, declaration, procedure, or function ID, never by
completion order. Phase barriers prevent a worker from observing a partially
merged symbol/type universe.

Safe parallelization order:

1. **Source front end:** preprocess, lex, and parse independent source files in
   parallel. Merge token, syntax, and diagnostic records in manifest source
   order with stable offset translation.
2. **Procedure semantics:** collect declarations and freeze global scopes and
   types deterministically first; then analyze independent procedure bodies in
   parallel and merge bindings by stable procedure ID.
3. **IR construction and verification:** lower and verify function-local IR in
   parallel after whole-program semantic state is read-only. Allocate final
   function/block/value IDs during the ordered merge.
4. **LLVM emission:** generate function fragments independently, then emit
   declarations, globals, functions, metadata, and debug records in canonical
   order. Whole-program initialization, shutdown, foreign ABI, and package
   metadata remain serial until proven independently partitionable.
5. **Independent projects:** once RP8 freezes the dependency graph, build
   dependency-ready projects concurrently while preserving deterministic
   initialization and package order.

Do not begin with parallel filesystem reads, global declaration collection,
module initialization, final metadata numbering, artifact publication, or
diagnostic printing. These are ordering boundaries and are unlikely to dominate
until profiling proves otherwise.

## Implementation sequence

### Phase 0: measure and remove algorithmic bottlenecks

- [x] Add repeatable wall-time, CPU-time, peak-memory, phase-time, token,
  syntax-node, symbol, expression, and IR-size measurements.
- [x] Record baselines for v3 self-compilation, `UBECore`, a many-source
  project, and a many-procedure project on the supported hosts.
- [x] Profile the slowest phases and repair avoidable quadratic lookup or
  repeated traversal before deciding which phase receives workers.

Phase 0 completed on 2026-10-25. The checked-in baseline is
[`performance/PHASE0_BASELINE.md`](performance/PHASE0_BASELINE.md). The
32/64/128-source and 128/256/512-procedure series are approximately linear
after adding deterministic scope/name and IR owner/default-form indexes. The
512-procedure fixture fell from 34,840 ms to 14,935 ms; IR lowering fell from
18,741 ms to 1,871 ms. Source front-end plus parsing remains the first parallel
slice because it is the earliest safe independent boundary; function-local
LLVM, semantics, lowering, and verification remain later high-value slices.

### Phase 1: preserve the bootstrap trust chain

- [x] Freeze and document the seed/production manifest split and its allowed
  dependency boundary.
- [x] Prove v2 builds the sequential seed reproducibly and the seed builds the
  production compiler without a pre-existing production binary.
- [x] Extend the build manifest with seed identity, requested/effective job
  counts, executor identity, and per-phase timing fields.

Phase 1 completed on 2026-10-25. The decision and allowed dependency boundary
are recorded in [`BOOTSTRAP_SPLIT.md`](BOOTSTRAP_SPLIT.md). Both verified
Compiler v2 stages emit byte-identical seed LLVM; the linked seed builds
production stage one without a pre-existing production binary; and production
stages one, two, and three emit byte-identical LLVM. The generated
`v3-beta1-build-manifest.json` records `ube-v3-sequential-seed-1`,
`ube-v3-sequential-executor-1`, one requested/effective job, measured phase
timings, and all compared artifact hashes. Moving inherited tests onto the
seed-built production compiler also exposed a parser stack overflow; a
token-level parenthesis precheck now turns the synthetic deep-nesting case into
controlled `UBE3701` while preserving the internal grammar capacity.

### Phase 2: bounded executor with sequential behavior

- [x] Implement the task/executor API, cancellation, drain, worker registration,
  and worker-owned result arenas while the executor still runs one job.
- [x] Add deterministic fault injection for worker creation, task publication,
  result allocation, cancellation, and merge failure.
- [x] Prove every failure drains workers, releases captures/arenas/handles, and
  removes temporary output.

Phase 2 completed on 2026-10-25. Every compiler command now enters the bounded
executor, with one registered logical worker, one published immutable task, a
worker-owned result arena, explicit cancellation/drain, and coordinator-owned
merge. `--jobs 1` is accepted explicitly and remains the default; larger counts
remain controlled `UBE5300` failures until Phase 3 supplies a parallel worker
pump. Hidden deterministic fault sites cover worker creation, publication,
result allocation, cancellation, and merge. The clean gate proves every path
releases workers, captures, and arenas; merge failure removes produced output;
and explicit `--jobs 1` emits byte-identical LLVM.

### Phase 3: parallel source front end

- [x] Parallelize source preprocessing, lexing, and parsing behind a phase
  barrier.
- [x] Translate worker-local indices into canonical manifest-order indices.
- [x] Sort diagnostics by source identity, location, stable diagnostic code,
  and deterministic tie-break fields before printing.

Phase 3 completed on 2026-10-25. The production-only frontend uses up to 32
stable worker slots and bounds the effective count by both `--jobs N` and the
number of source files. Each worker owns preprocessing, token, grammar, parser,
syntax, link, and diagnostic storage; a grammar-ready barrier prevents one
worker from invalidating another worker's model, and result publication is
serialized because current instance-method lowering uses an implicit receiver.
The coordinator drains every batch and translates token, node, parent, child,
and link indices while merging in manifest order. Clean gates require identical
LLVM for jobs 1, 2, and 8 (with effective jobs capped by source count), identical
failure diagnostics and exit status, accurate requested/effective profile
metadata, deterministic frontend fault diagnostics, and no false-success
artifact. A generated 15,000-declaration regression also proves that large
managed token arenas cross the worker/coordinator boundary field by field
without entering the unsafe recursive aggregate-copy path. The v2-buildable
seed remains sequential and independently verified.

Performance audit on 2026-10-26: normal Phase 3 activation is suspended. Each
worker privately rebuilt the complete embedded grammar and copied its token
arena back to the coordinator. Compiler self-parse exceeded seven minutes with
eight jobs versus 166 seconds with one before termination of the test, and
UBECore also regressed. Production now preprocesses, lexes, and parses through
the canonical coordinator path while explicit frontend fault injection retains
coverage of worker creation, drain, merge, cleanup, and diagnostics. Re-enable
only after workers can consume immutable shared source and grammar views and a
representative performance gate proves a benefit.

### Phase 4: parallel procedure analysis

- [x] Separate deterministic declaration/type freezing from procedure-body
  analysis.
- [x] Audit semantic caches and tables so workers receive read-only views or
  private storage; remove hidden shared mutation.
- [x] Merge bindings and expressions by stable procedure ID and validate the
  merged model with the existing whole-program checks.

Phase 4 completed on 2026-10-26. The production compiler freezes the canonical
declaration, type, scope, link, symbol, and binding universe before launching
procedure workers. Each worker reconstructs a private read-only snapshot, owns
its lookup caches and result arenas, and publishes only after completion. The
coordinator drains every worker, merges by stable syntax identity, reassigns
canonical IDs, and runs the existing constant and whole-program validation.
The sequential seed and `--jobs 1` continue through the original semantic path.
Permanent gates compare semantic dumps and LLVM bytes for jobs 1, 2, and 8,
repeat eight-worker builds, exercise a 16-procedure interleaving regression,
verify actual effective-job profile metadata, and inject creation, wait, merge,
and transfer failures with cleanup and false-success-output checks.

Performance audit on 2026-10-26: normal Phase 4 activation is also suspended.
The original path serialized every syntax binding, used quadratic immutable
string accumulation and insertion sorts, copied overlapping token slices for
each expression, and reconstructed the complete frozen semantic universe in
every worker. The quadratic paths and an out-of-bounds insertion-sort guard
were repaired, but the remaining full-state transport still made UBECore
semantics 4.02 seconds with eight jobs versus 1.83 seconds sequentially.
Production therefore selects coordinator analysis and reports
`effective_jobs=1`; explicit semantic fault sites still exercise every worker
failure path. See `performance/PHASE5_INVESTIGATION.md`.

### Phase 5: parallel IR and LLVM fragments

- [x] Remove avoidable whole-program rescans before adding workers: IR edge
  validation now uses a source-block adjacency index, and LLVM function
  emission visits only canonical function instruction ranges with indexed
  managed safe points.
- [x] Add deterministic work-count profile gates that bound verifier edge
  probes and LLVM instruction visits independently of host timing.
- [ ] Build and verify function-local IR concurrently using local numbering.
- [ ] Assign canonical global IR numbers during the serial merge.
- [ ] Emit function LLVM/debug fragments concurrently and concatenate them in
  canonical function order before atomic artifact publication.
- [ ] Use immutable shared semantic/IR inputs rather than whole-project worker
  serialization, and require a reproducible self-host and UBECore speedup before
  normal worker activation.

The Phase 5 audit on 2026-10-26 reduced self-host IR verification from 143.723
seconds to 0.485 seconds and LLVM emission from 244.572 seconds to 63.280
seconds. Total wall time fell from 800.730 seconds to 467.140 seconds while the
seed-built and self-built LLVM hashes remained identical. The current profile
records 133,327 verifier edge probes for 92,021 edges and 148,253 LLVM
instruction visits for 148,601 instructions. Semantics and IR lowering are now
the dominant phases; worker design must not obscure another avoidable scan.

### Phase 6: hardening and default enablement

- [ ] Run every inherited compiler, language, malformed-input, low-memory,
  runtime, library, and self-host gate with `--jobs 1`, `--jobs 2`, and the
  largest explicitly supported representative job count.
- [ ] Add randomized scheduling/delay hooks and require repeated byte-identical
  outputs, exit codes, and diagnostic text across job counts.
- [ ] Stress cancellation, worker failure, full diagnostic buffers, collection,
  and shutdown while tasks are active; save every crash, hang, race, or mismatch
  as a synthetic regression.
- [ ] Keep the default at one, document explicit job-count selection, and show
  representative scaling without violating the agreed peak-memory threshold.

## Permanent release gates

- A clean checkout can build v2, the v3 seed, and the v3 production compiler
  offline using documented commands.
- Production stage-two and stage-three outputs satisfy the existing deterministic
  IR and normalized-object comparison policy at every tested job count.
- `--jobs 1` and parallel builds have identical diagnostics, exit status, and
  semantic artifacts for success and failure corpora. Reproducibility manifests
  may differ only in explicitly recorded execution metadata such as requested
  job count, effective job count, phase timing, and host measurements.
- No worker remains live after compiler return; no lock is held while invoking
  arbitrary compiler/user callbacks; no failed build leaves a false-success
  output.
- Performance results, hardware, job count, peak memory, toolchain, and input
  hashes are recorded so the claimed speedup is reproducible.

## Next action

Execute Phase 5: build and verify function-local IR concurrently with local
numbering, assign canonical global numbers during ordered merge, and emit LLVM
and debugger fragments in canonical function order.
