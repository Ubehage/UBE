# UBE Compiler v4 agent task packets

## Mandatory packet format

Before starting any numbered task, copy its packet into `Progress.md` and fill
in: objective, prerequisites checked, files in scope, smallest reproduction,
expected artifacts, new test inventory, focused commands, cumulative inherited
gates, measurements, risks, and exact next action. Keep one active task. If
work reveals a new prerequisite, record it in the roadmap and stop broadening
the task silently.

`TESTING.md` applies to every packet. For each new capability, explicitly list
the positive, interaction, rejection, boundary, stress, failure-injection,
regression, differential, native, and determinism cases. Marking a category not
applicable requires a recorded reason. No agent may call a build working merely
because the compiler executable was produced or one showcase program passed.

Every handoff must state:

- what changed and why;
- decisions and rejected alternatives;
- tests run with exact results;
- relevant input/output hashes and work counters;
- remaining failures, partial artifacts, and cleanup status; and
- the first command or inspection the next agent should perform.

## Task 0 — architecture and reuse decision

**Read:** all v4 documents; v3 `DESIGN.md`, `BOOTSTRAP_SPLIT.md`,
`MULTITHREADED_COMPILER_PLAN.md`, and Phase 5 investigation; source-library
design/rules; normative grammar and versioning documents.

**Do:** turn each open architectural choice into a small question with a
representative fixture and measurable acceptance criteria. Prototype syntax
representations outside the production manifest. Produce record/ownership
diagrams, phase API sketches, estimated memory, library placement decisions,
and the dependency-minimal test case/build-record format required by
`TESTING.md`.

**Do not:** create production source, edit frozen semantics, optimize v3, or
select a design because it resembles v3.

**Proof:** owner approval recorded in `DESIGN.md`; prototype commands and data
are reproducible; `REUSE_PLAN.md` has no unclassified dependency needed for the
first vertical slice.

## Task 1 — reusable foundation and library split

**Read:** approved Task 0 decisions and all source-library local instructions.

**Do:** implement the smallest independently useful APIs required by Task 2/3,
one ownership domain at a time. Add positive, boundary, allocation/failure,
thread, portability, and cleanup tests. Keep public and compiler-support APIs
separate and version their declarations.

**Do not:** move parser/semantic/backend policy to a library, create a catch-all
helper module, expose compiler records publicly, or wrap an intrinsic without a
removal/fallback decision.

**Proof:** APIs build as separate projects; documentation matches declarations;
v3 can compile their bootstrap slice; intrinsic count and dependency manifest
are explicit.

## Task 2 — scaffold and session shell

**Read:** approved phase interfaces, dependency manifest, v3 CLI/diagnostic
tests, and generation naming/build policy.

**Do:** create the exact manifest/startup structure, immutable session records,
limits, diagnostics, cancellation, and explicit resource cleanup. Use fake
phase adapters to prove failure propagation and atomic publication. Create the
deterministic cumulative test runner before expanding the compiler surface.

**Do not:** add real parsing or LLVM, put generated output in the source tree,
or make the driver own phase-private arrays.

**Proof:** v3 builds the shell; malformed arguments, missing/corrupt inputs,
injected allocation/tool/write/cancel failures, and repeated invocation all
return controlled results with no false artifact or live resource.

## Task 3 — minimal vertical slice

**Read:** the thin-slice grammar/semantic/ABI fixtures and every approved phase
record contract.

**Do:** implement the smallest genuine path through every phase. Give each
phase a dump and validator. Add one valid native program and minimal invalid
cases at every boundary.

**Do not:** special-case the fixture by source spelling, merge phases for
convenience, or add unsupported language breadth.

**Proof:** v3/v4 behavior agrees; LLVM validates and native output runs; phase
dumps are deterministic; mutation/ownership tests demonstrate isolation.

## Task 4 — projects, sources, preprocessing, lexer

**Read:** normative lexical/project rules, v3 RP1/RP2 fixtures, Unicode data
provenance, and source/path library contracts.

**Do:** load once, preserve bytes/spans, use per-source ownership, and make
preprocessing/source mapping explicit. Add arbitrary-byte and size-series
fixtures with bytes/tokens/work counters.

**Do not:** use host locale, flatten sources into a mutable global buffer,
silently normalize paths by target rules, or copy source arenas between workers.

**Proof:** full lexical differential gate, malformed UTF-8 and preprocessing
recovery, path/environment failures, bounded memory, and linear scaling pass.

## Task 5 — compact parser and recovery

**Read:** Task 0 parser decision record, normative grammar, v3 RP3 corpus, and
deep-nesting crash regressions.

**Do:** implement every production systematically, generate/check tables when
approved, retain exact spans, and guarantee recovery progress. Test truncated
input at each construct boundary and node/memory growth by input size.

**Do not:** construct syntax for trivia/grammar machinery not required by the
approved representation, dispatch by folded rule strings in hot loops, recurse
without a proven depth bound, or claim coverage from self-parsing alone.

**Proof:** grammar coverage report is complete; valid and invalid differential
snapshots pass; nodes/bytes per token and parse work remain within Task 0 budgets.

## Task 6 — declarations, names, and types

**Read:** frozen semantic/type/conversion rules, v3 RP4 fixtures, and library
Unicode/collection contracts.

**Do:** collect in canonical order, intern/fold once, index every ownership and
lookup relation, then freeze. Force collision tests and compare output under
different internal hash seeds if supported.

**Do not:** let procedure analysis create global declarations/types, expose
hash iteration order, linearly rescan all symbols from hot queries, or use text
where a frozen ID exists.

**Proof:** semantic declaration/type snapshots match; duplicate/unknown/layout/
conversion failures are exact; lookup counters and scaling fixtures pass.

## Task 7 — function-local semantic analysis

**Read:** complete frozen semantics and RP4/RP6/RP7/RP8 semantic failures.

**Do:** give each procedure private output, immutable global inputs, explicit
summaries, and deterministic diagnostics. Implement feature groups in small
vertical slices with one negative test per rule and one interaction test per
shared invariant.

**Do not:** serialize the frozen universe per function, copy overlapping token
ranges per expression, merge by completion order, or repeatedly walk unrelated
bodies for whole-program checks.

**Proof:** semantic corpus parity and randomized analysis order pass; memory is
bounded by frozen state plus active private arenas; counters demonstrate local
work plus explicit summary checks.

## Task 8 — function-local IR and verifier

**Read:** v3 IR model/verifier invariants, native behavior fixtures, managed
metadata contracts, and Phase 5 counter lessons.

**Do:** lower one function at a time with local IDs, adjacency indexes, explicit
failure/cleanup edges, and checked builders. Verify before publication; merge
only verified results in canonical function order.

**Do not:** allocate global final IDs in workers, scan all edges for each block,
let backend repair invalid IR, or omit synthetic invalid-IR tests.

**Proof:** every invariant has a rejection fixture; accepted IR behavior matches
v3; verifier probes and lowering lookups satisfy recorded linear bounds.

## Task 9 — target and backend

**Read:** target/ABI/versioning docs, v3 RP5/RP8 backend fixtures, LLVM contract,
and external tool failure tests.

**Do:** isolate target tables, emit local function/debug fragments, canonicalize
metadata in one owner, validate LLVM before publication, and invoke tools with
separate bounded arguments. Test cleanup at every process/file failure point.

**Do not:** embed host assumptions in IR, scan all functions per function, build
a shell command line, retain partial outputs, or accept unverified metadata.

**Proof:** LLVM/ABI/debug/native comparisons pass on claimed boundaries;
instruction-visit counters are linear; tool corruption/timeout/cancel/full-disk
tests leave no false-success artifact or handle.

## Task 10 — complete projects and runtime behavior

**Read:** RP6–RP8 implementation notes, format/version contracts, source-library
boundaries, and runtime ownership rules.

**Do:** add one independently gated feature family at a time through semantics,
IR, backend, library/runtime, native tests, and corrupted-input tests. Preserve
deterministic initialization/shutdown and exact external ownership contracts.

**Do not:** fold runtime algorithms into compiler code, relax package hashes or
compatibility checks, rely on GC for external resources, or batch unrelated
feature families into an unauditable port.

**Proof:** all inherited package, ABI, managed, error, concurrency, event,
component, optimization, debugger, and target gates pass with v4.

## Task 11 — deterministic parallel execution

**Read:** approved ownership model, v3 multithreading plan and postmortem, and
all phase work/memory baselines.

**Do:** begin with a sequential executor and injected failures. Parallelize one
already-local phase at a time, vary schedules deliberately, merge by stable ID,
and record speedup plus peak memory on representative workloads.

**Do not:** copy whole-program state to workers, share mutable arenas, hold locks
across callbacks/tools, advertise requested jobs as effective jobs, or retain a
parallel path that loses to one job on its representative workload.

**Proof:** byte-identical outputs/diagnostics and cleanup across job counts,
random schedules, worker failures, cancellation, and repeated stress; accepted
performance and memory thresholds are recorded.

## Task 12 — self-hosting and fixed point

**Read:** all bootstrap contracts, comparison policy, dependency identities,
and previous-generation clean gates.

**Do:** extend rather than replace the trust manifest. Start from clean outputs,
prove the v3-built stage, repeat with v4 stages, build the exact library slice,
and compare every approved artifact and corpus result.

**Do not:** consume a pre-existing v4 binary, weaken comparison to pass a
mismatch, modify v3 broadly, or delete earlier artifacts/history.

**Proof:** documented offline commands reproduce the chain and fixed point with
recorded hashes; prior generations still pass their gates.

## Task 13 — hardening and release

**Read:** release requirements, never-crash rule, dependency policy, supported
matrix, and every known limitation from `Progress.md`.

**Do:** fuzz and inject environmental failures at each boundary, retain minimal
regressions, audit reachable panic/assert paths, and measure all agreed
workloads. Reconcile public docs strictly with executable evidence.

**Do not:** dismiss a crash as invalid input, set thresholds from one favorable
run, claim unsupported portability, download build dependencies, or mark the
release gate complete with unexplained flakes.

**Proof:** clean offline release rehearsal passes the complete matrix; hashes,
provenance, licenses, limitations, support procedures, and measurements are
published; no known uncontrolled failure remains.
