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
`--jobs 1` is always supported. The default job count is chosen only after the
performance and memory gates below pass; until then it remains one.

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

- [ ] Add repeatable wall-time, CPU-time, peak-memory, phase-time, token,
  syntax-node, symbol, expression, and IR-size measurements.
- [ ] Record baselines for v3 self-compilation, `UBECore`, a many-source
  project, and a many-procedure project on the supported hosts.
- [ ] Profile the slowest phases and repair avoidable quadratic lookup or
  repeated traversal before deciding which phase receives workers.

### Phase 1: preserve the bootstrap trust chain

- [ ] Freeze and document the seed/production manifest split and its allowed
  dependency boundary.
- [ ] Prove v2 builds the sequential seed reproducibly and the seed builds the
  production compiler without a pre-existing production binary.
- [ ] Extend the build manifest with seed identity, requested/effective job
  counts, executor identity, and per-phase timing fields.

### Phase 2: bounded executor with sequential behavior

- [ ] Implement the task/executor API, cancellation, drain, worker registration,
  and worker-owned result arenas while the executor still runs one job.
- [ ] Add deterministic fault injection for worker creation, task publication,
  result allocation, cancellation, and merge failure.
- [ ] Prove every failure drains workers, releases captures/arenas/handles, and
  removes temporary output.

### Phase 3: parallel source front end

- [ ] Parallelize source preprocessing, lexing, and parsing behind a phase
  barrier.
- [ ] Translate worker-local indices into canonical manifest-order indices.
- [ ] Sort diagnostics by source identity, location, stable diagnostic code,
  and deterministic tie-break fields before printing.

### Phase 4: parallel procedure analysis

- [ ] Separate deterministic declaration/type freezing from procedure-body
  analysis.
- [ ] Audit semantic caches and tables so workers receive read-only views or
  private storage; remove hidden shared mutation.
- [ ] Merge bindings and expressions by stable procedure ID and validate the
  merged model with the existing whole-program checks.

### Phase 5: parallel IR and LLVM fragments

- [ ] Build and verify function-local IR concurrently using local numbering.
- [ ] Assign canonical global IR numbers during the serial merge.
- [ ] Emit function LLVM/debug fragments concurrently and concatenate them in
  canonical function order before atomic artifact publication.

### Phase 6: hardening and default enablement

- [ ] Run every inherited compiler, language, malformed-input, low-memory,
  runtime, library, and self-host gate with `--jobs 1`, `--jobs 2`, and the
  supported automatic job count.
- [ ] Add randomized scheduling/delay hooks and require repeated byte-identical
  outputs, exit codes, and diagnostic text across job counts.
- [ ] Stress cancellation, worker failure, full diagnostic buffers, collection,
  and shutdown while tasks are active; save every crash, hang, race, or mismatch
  as a synthetic regression.
- [ ] Enable multiple jobs by default only when representative 4-core hardware
  shows a material wall-time improvement without violating the agreed peak-
  memory threshold. Otherwise ship the executor and keep the default at one.

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

## First action when this work starts

Instrument the sequential RP8 compiler and publish a phase profile for its own
self-build. Do not design task granularity from intuition alone: choose the
first parallel phase from measured wall time and dependency boundaries.
