# Compiler acceptance gates

**Status:** bounded scalar source-compiler gates now pass; broader language and
self-hosting requirements remain pending. Exact commands are in Progress.md.

The current work is the scalar admission set in
`../lang-doc/bootstrap-profile.md`, under the authorized development plan.
No prototype gate by itself qualifies a UBE compiler.

## Project-loading gate

The first VB6 bootstrap must read a `.UBE` manifest and retain multiple source
modules in manifest order, resolving paths relative to the manifest rather
than the working directory. Assert deterministic output across repeated loads,
UTF-8 decoding, native source identities, and controlled rejection of duplicate
keys/paths/identities, missing files, path escapes, malformed text and unsupported
features. Exercise input limits and bounded completion. Loading checks do not
qualify procedure parsing, cross-module calls, entry-point resolution or code
generation; those require actual source-compiler gates below.

## Failure-flow oracle

The semantic gate in `../bootstrap/tests/source-semantics/check.ps1` now checks
resolved symbols, entry/signatures, scalar types, ByRef modes, constants, labels
and trusted error-support identities. The boundaries and deferred cases are in
`../bootstrap/SEMANTICS.md`. This qualifies static checks, not the execution
requirements below.

The lexer/parser gate in `../bootstrap/tests/source-parsing/check.ps1` now
asserts retained syntax-tree structure, source positions, admitted syntax,
malformed/unsupported input and resource bounds. The real failure-flow oracle
is parsed there; the separate native compiler gate executes it.

The native fixture in `../bootstrap/tests/failure-flow/` tests the feasibility
of the approved behavior. The real compiler gate in
`../bootstrap/tests/native-compilation/` now accepts matching UBE source
and reproduces the same outcomes, without consulting a test name or embedding
expected results. Each case must observe values, error state and control flow.

| Scenario | Required observation |
|---|---|
| Success returns zero with stale Err | Caller assigns zero; old Err retained; no handler executes |
| Explicit raise | Error recorded, current procedure returns FAIL immediately, statements after raise unexecuted |
| Failed call in assignment RHS | Old destination unchanged, remaining operands/calls unexecuted, next statement runs |
| Enabled caller handler | Handler entered exactly once; statement does not commit; ordinary following path is skipped |
| Failure received inside handler | Failed handler statement skipped; subsequent handler statement runs; no recursive entry; new Err recorded |
| Cleanup before raise | Explicit cleanup before raise observed; cleanup after raise never executed |
| Earlier ByRef side effect | Completed write retained even though call/statement later fails |
| Repeated identical error numbers | Each call returns a fresh FAIL; identical Err.Number does not suppress handling |
| Err.Clear | Visible record reset; later successful calls stay successful; saved handler resume state is not inferred from Err |
| Default / explicit Resume Next / GoTo 0 | Same failed-statement continuation when no label handler is enabled |
| Callee consumes a failure locally | It may continue and return success; its stale Err alone must not force its caller to fail |

## Source and semantic rejection gate

Assert diagnostics and locations for malformed/truncated input, illegal tokens,
missing declarations, duplicate folded names, missing/multiple/wrong-signature
Main, mismatched procedure endings, bad parameter types and writable ByRef
requirements. Unsupported valid language forms must be diagnosed as unsupported
rather than accepted with invented behavior.

Compile-time constant overflow and invalid conversion are rejected. Runtime
failure cases must use input not proven invalid by the applicable analysis.
Verify safe refusal at input/depth/diagnostic limits and after I/O failure.
Every crash fix adds the smallest regression that reproduces the prior crash.

## Generated-code and build gate

- Compile actual source fixtures at O0 and O2; compare defined observable
  behavior rather than assembly text or incidental instruction count.
- Assert the output PE machine is x64, exact exit/status, bounded completion
  and required observations. An executable merely launching is not a pass.
- Feed bad IR or a controlled failing backend into the driver and prove no
  success artifact is published. Do not overwrite an existing valid program.
- Compile the same inputs repeatedly and compare deterministic generated IR;
  per-invocation state must not leak into later compilations.
- Keep tool versions and commands in the handoff. No network fetches or
  undocumented installed prerequisites.

## Integer dependency gate

`../bootstrap/tests/integer-types/check.ps1` checks the next admitted storage
dependency: Byte, Integer and LongLong alongside Boolean/Long. Require exact
typed minima/maxima, constant rejection beyond the ranges, destination-context
literals, authoritative literal suffixes and declaration-consistent use suffixes.
Byte arithmetic promotes to Integer; explicit narrow arithmetic must still
overflow before conversion to a wider destination.

Exercise the admitted conversion matrix through assignment, ByVal arguments
and function results. Include runtime minima/maxima and destination boundaries
where representable by the source type, unsigned rejection of True, signed
extension, wide values and numeric-to-Boolean normalization. Run actual source
at O0/O2 using volatile harness inputs; assert value, fresh success, sticky Err
and unchanged destinations on failure. Direct ByRef requires exact declared
types; grouped arguments use checked disposable temporaries. Existing native
failure-flow, semantic, parser and loader gates must remain passing.

These tests qualify scalar value semantics, not foreign memory layout, arrays,
records, threading or self-hosting. Exact evidence belongs in Progress.md.

## Bounded source-buffer and finite-record gate

`../bootstrap/tests/aggregate-storage/check.ps1` must compile actual UBE source
that retains bytes, token records and tree records across multiple modules and
traverses them. Assert independent copies, nominal identity, nested fields,
direct ByRef aliases and caller-supplied array bounds. Exercise signed bounds
and runtime indexing at O0/O2 using volatile input, including a deliberately
changed input that the oracle must reject.

Invalid reads, writes and ByRef arguments must record Err 9, preserve existing
destinations, and skip remaining operands/arguments. Check enabled and active
handlers against the established FAIL contract. Reject unsupported aggregate
paths explicitly, qualify new storage/layout limits, and preserve prior output
after a failed emission. Existing integer, native, semantic, parser and loader
gates must pass on the same final executable.

This gate covers fixed owned scalar storage under AGGREGATES.md; it does not
qualify dynamic allocation, managed roots, public layouts or self-hosting.

## Counted-buffer primitive and UBECore gate

`../bootstrap/tests/counted-buffers/check.ps1` must compile actual UBECore source
through a multi-module project and run its primitives and append algorithm at
O0/O2. Assert actual descriptor lengths, logical byte offsets independent of
lower bounds, overlap in both directions, self-copy, zero-count end offsets,
full-span validation before writing and unchanged destinations on failure.
Distinguish record-only False from language FAIL, including sticky Err,
continued expression evaluation, enabled handlers and failing argument
conversion. Prove that append publishes used length only after success.

Inspection must assert role-to-declaration binding, renamed declarations and
ordinary-name counterexamples. Reject missing, duplicate, mismatched and
unsupported metadata/signatures with source locations; a failed emission must
preserve the earlier output. All existing bootstrap gates remain regressions.
Allocation, empty dynamic arrays, collector behavior and I/O are outside this
allocation-free gate.

## Final compiler concurrency gate

This gate applies to the UBE-written compiler, not the sequential VB6 bootstrap.
All compiler code must follow explicit ownership/synchronization contracts;
passing ordinary sequential tests is not evidence of thread safety.

- Demonstrate overlapping worker execution on independent work within a
  multi-module project. Separate compiler processes alone are insufficient.
- Compare generated IR/artifacts and ordered diagnostics with a single-worker
  baseline, across repeated runs, worker counts and varied task schedules.
  Normalize only documented nondeterministic packaging fields if applicable.
- Compile multiple independent requests concurrently in the same compiler
  process. Assert that symbols, source buffers, caches, temporary paths,
  diagnostics and failure status cannot leak between requests.
- Exercise dependency ordering, shared-data publication and competing output
  publication. No request may consume an unfinished declaration table or
  partially published artifact; failed builds retain the existing output.
- Inject worker failures and cancellation alongside successful work. Assert
  controlled completion, isolation of error state, bounded resource cleanup
  and absence of deadlock; another request must remain usable afterward.
- Review every mutable shared-state boundary and library/backend calling
  contract. Use race detection where available and repeat contention tests;
  report the tested schedules and limits rather than claiming that stress
  testing alone proves the absence of all races.

Performance measurements must accompany the overlap evidence, so useful
parallelism is assessed separately from correctness. No fixed speedup is
promised independently of workload and hardware. This gate is currently pending.

## Self-hosting gate, after source dependencies are implemented

Build the UBE-written compiler with VB6 bootstrap, then rebuild it through
successive UBE-generated executables. Compare deterministic generated outputs
and run identical positive, negative and recovery corpora with both. Report
actual differences; never treat a successful self-build alone as conformance.

## Current limits

The scalar compiler gate qualifies its admitted source parsing/lowering and
controlled recursion-depth refusal. It does not qualify complete Err metadata,
TLS/thread isolation, arbitrary OS stack-exhaustion recovery, managed-resource
cleanup, real external-resource release, foreign ABI, full debugging or
optimizer correctness outside the asserted scenarios. Add focused gates before
claiming those capabilities. The older hand-authored prototype alone remains
insufficient evidence of source compilation.
