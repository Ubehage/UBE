# UBE development plan

**Direction authorized:** 2026-11-10. Reconcile the agreed contracts, define a
bounded bootstrap subset, prove error flow early, then implement incrementally.

## Preserve the product contract

The final compiler is written in UBE and emits native 64-bit code through LLVM.
VB6 is the temporary bootstrap host. Ordinary algorithms belong in UBECore;
the compiler owns syntax, types, control flow, verification and lowering.
Windows is the first qualified target. No new dependency, compiler generation,
GUI framework or alternative language semantics is introduced by this plan.

Existing working-tree removals remain in place. Historical implementations and
their test results are not a passing baseline for the restart. Source recovery
from history requires a focused reason and review, not wholesale restoration.

## Execution order and acceptance

| Work | Deliverable | Gate before advancing |
|---|---|---|
| Reconcile decisions | Normative error contracts and affected manual pages agree on fresh FAIL, default statement skipping, caller handlers and explicit cleanup | Scoped contradiction audit, documentation validator, recorded unresolved decisions |
| Define bootstrap source boundary | `../lang-doc/bootstrap-profile.md` and compiler acceptance plan | Every admitted feature has an observable oracle; exclusions are diagnosed rather than guessed |
| Prove native failure flow | `../bootstrap/tests/failure-flow/` prototype | Exact assertion results at O0 and O2; success with stale Err; no assignment on FAIL; no handler re-entry; explicit cleanup; preserved earlier effects |
| Implement source-to-native scalar path in VB6 | Repository-owned `.UBE` project loader with multiple ordered modules from the outset, source reader, parser, semantic checks and LLVM emission | Assert manifest validation and ordered multi-module loading first; then compile actual UBE fixtures and match the same oracles, including negative/recovery cases; hand-authored IR is not sufficient |
| Extend bootstrap dependencies | Checked arithmetic, source buffers, arrays/records, library calls and explicit OS I/O | Value/ownership, input-bound, allocation-failure and error-propagation tests for each dependency |
| Build compiler in UBE | UBE compiler sources and UBECore dependencies using the qualified profile | VB6 bootstrap builds it; it recompiles itself; deterministic artifacts and common conformance corpus agree |
| Complete language and product | Remaining language, standard library, debugging, IDE, samples and documentation | Their existing normative requirements and release gates pass on each claimed target |

The native prototype is test-only evidence about the proposed lowering behavior.
It does not freeze a public or internal ABI, establish multi-thread safety, or
justify adding a second production implementation. Its assertions become
regressions for real source compilation rather than a permanent substitute.

## Immediate scope control

The first production implementation accepts a small explicit scalar source
profile; it does not claim support for the entire EBNF. It must reject valid
but unsupported UBE with a useful diagnostic. Parser recovery, bounded input
and controlled failure belong in this first implementation, not a later polish
pass. Debug source locations must survive the initial pipeline even before
full debug-info emission is qualified.

The owner requires `.UBE` project files containing multiple modules from the
first bootstrap implementation. The same loaded project and source buffers
feed the later parser and semantic pipeline. Project loading is not deferred
until after a single-file compiler, and a loading-only check must never claim
that procedure bodies have been parsed or compiled.

Keep state per compilation/request. Do not introduce global mutable compiler
state that would prevent later parallel compilation. Actual parallel build
support is a separate tested capability, not inferred from this rule.

### Final compiler concurrency requirement

Owner clarification, 2026-11-10: the final UBE-written compiler must be
multithreaded, and all of its code must be thread-safe. This is a compiler
architecture requirement from the start, independent of the later IDE.
The VB6 bootstrap may remain sequential; it need not implement a worker scheduler.

The final compiler must execute independent compilation work concurrently,
including independent work within a multi-module project where dependencies
permit. Merely launching several single-threaded compiler processes does not
satisfy this requirement. Dependency-sensitive work must wait for its inputs;
parallelism must not change name resolution, initialization order or language
semantics.

Mutable state belongs to an explicit compilation/request or work item. Sharing
immutable data is preferred; shared mutable caches, symbol data, diagnostics,
allocation facilities and output publication require explicit ownership and
synchronization. All compiler code, including library/backend interfaces used
by workers, must be safe under its documented concurrent calling contract.
Non-thread-safe dependencies must be isolated or serialized at that boundary.
Do not rely on a process-global current project, current procedure or last error.
Worker failures must return to the owning request without contaminating another
request's diagnostics or error state.

Thread safety and useful parallel execution are distinct acceptance obligations.
The compiler must produce deterministic results and diagnostics regardless of
worker scheduling. A single-worker mode provides a comparison baseline.
The required concurrency evidence is specified in `../compiler/ACCEPTANCE.md`;
the current bootstrap tests do not establish it. This requirement concerns the
compiler implementation; generated programs retain their separately specified
threading semantics.

Do not implement Adaptive, assembly lowering, complicated Resume targets,
cross-thread failure transfer or foreign callback behavior until their remaining
contracts are closed. They do not block proving the agreed scalar failure flow.

## Decision and evidence ownership

- `../Workplan.md`: repository-wide current position.
- `../compiler/Roadmap.md`: compiler dependency order.
- `../compiler/Progress.md`: exact next task, executed gates and limitations.
- `../compiler/ACCEPTANCE.md`: source-compiler acceptance requirements.
- `../lang-doc/error-handling.md`: approved language behavior.
- `Error-Handling.md`: unsettled boundaries and reconciliation audit.

A checklist item is complete only after its stated assertion gate passes.
Specification review, native feasibility and source-compiler conformance are
different claims and must be reported separately.
