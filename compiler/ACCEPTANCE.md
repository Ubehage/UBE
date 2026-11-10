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

This gate covers declared fixed bounds and finite records under AGGREGATES.md.
Replacement now shares the dynamic-storage machinery; allocation/lifetime
failure assertions belong to the separate gate below. Neither gate qualifies
managed roots, public layouts or self-hosting.

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

## Growing storage and retained-alias gate

`../bootstrap/tests/dynamic-storage/check.ps1` must compile actual UBE source
at O0/O2 for empty arrays, scalar/record growth, preserved coordinate
intersections, neutralization, independent copies and replacement bounds.
Prepared element aliases must keep original storage through later arguments,
callee replacement and assignment RHS evaluation, including abandonment.

Inject allocation failure at the narrow target wrappers: assert one retry,
record-only False versus assignment FAIL, unchanged destinations, sticky Err
on success and owner/borrow cleanup. Check production storage quotas and
failed target-release recovery. Successful context disposal must leave no live
allocations. Reject invalid signatures and unsupported syntax with controlled
diagnostics. Missing or failing import tools must preserve earlier artifacts.
The existing aggregate, counted-buffer, integer, native, semantic, parser and
loader gates must pass on the same final bootstrap binary.

## Counted file input/output gate

`../bootstrap/tests/file-io/check.ps1` must compile ordinary UBECore file
algorithms and exact attributed primitives through the multi-module pipeline,
then run actual file operations at O0/O2. Independent host readback must compare
every byte, including zero and non-ASCII byte values. The restored contracts
are `../std-lib/FILE-BYTES-CONTRACT.md` and FILE-OUTPUT-CONTRACT.md.

| Case | Required observation |
|---|---|
| Empty and bounded input | Exact result length/data; EOF is usable zero progress |
| Partial input/output | Ordinary UBE advances by confirmed progress, without repeated or omitted bytes |
| Zero write progress | Whole-output algorithm terminates with a fresh failure |
| Rejected read | Existing destination and result remain unchanged |
| Existing output path | Exclusive creation fails; earlier bytes remain identical |
| Bad span/path/mode/token | Controlled status and no accidental OS I/O |
| Aliased outputs | Rejected before mutation; a live token is not overwritten |
| Prior Err | Success preserves it while Failure becomes zero |
| Allocation failure | Bounded retry and no leaked metadata, scratch or OS handle |
| Read/write/flush failure | Exact fresh status; confirmed write progress is not represented as rollback |
| Close failure | Token remains live for retry; successful close clears it |
| Rejected open plus close failure | Caller receives the live owner for cleanup |
| Context isolation | A foreign or stale token cannot name another context's live owner |
| Disposal with live file | Reports incomplete disposal without silently closing user-owned resources |
| Explicit Raise after cleanup | Fresh FAIL reaches caller while cleanup has already completed |

Use narrow target-wrapper fault injection, assert that every injected path was
actually reached, and observe native calls, packed-byte copies and live-resource
counts. Add changed-input/omitted-operation controls so a vacuous success cannot
pass. Signature negatives must reject wrong types, ranks and passing modes and
preserve earlier emitted output. Run relevant prior gates on the same final
VB6 executable. Sequential acceptance does not qualify native concurrency.

## Source-scanning dependency gate

`../bootstrap/tests/source-scanning/check.ps1` must compile and execute the
actual UBE-written scanner and portable UTF-8 helper, with source bytes read
through UBECore file input. Run at O0/O2 and compare numeric token kinds,
original byte spans and physical UTF-16 positions against independent expected
values. Include comments, continuation lines, quoted escapes, numeric spellings,
UTF-8/BOM, malformed input, source/token limits and repeated independent scans.
Failure must report a located diagnostic without publishing partial tokens.

The same gate must execute loop/operator and condition-failure probes: all Do
forms, nearest Exit Do, eager Or, width-correct Not and checked subtraction;
default failed If/ElseIf and pre/post While/Until conditions skip the complete
construct, ordinary failed body statements skip only themselves, and enabled
or active handlers follow their defined routes. Changed runtime input must
invalidate the observations. The separate syntax-check.ps1 asserts exact
constant folding, loop admission and controlled malformed/unsupported
syntax. Run prior gates on the same final VB6 binary.

This qualifies a bounded scanner component, not a complete UBE parser,
self-hosting, managed String representation or concurrent compilation.

## UBE module-parser and source-storage gates

`../bootstrap/tests/module-parsing/check.ps1` must execute the actual UBE
scanner, token helpers and parser at O0/O2. Assert authored expression grouping,
call-argument order, nearest Else, Do forms, declarations and intrinsic metadata,
including exact physical spans. Traverse every retained node of real compiler
and UBECore modules to check reachability, parent/sibling consistency, acyclic
links and bounded source spans. Retaining a second module must not replace the
first. Invalid input must produce a located diagnostic with zero public count
and root while preserving prior node storage. Changing a source operator must
invalidate an unchanged structural assertion. Recursive Type declarations are
syntax cases only; they do not qualify runtime recursive storage.

The separate token-check gate covers reserved/contextual words, punctuation,
bracket decoding and numeric/module-name boundaries. The parser allocation
gate must fault growth and publication, observe both allocation attempts,
preserve every old record field, retry successfully and release all owners.
Syntax-nesting rejection and native call-depth refusal must complete within
deadlines without publishing partial output.

`../bootstrap/tests/source-storage/check.ps1` must exercise real byte patterns
across the old boundary, exact transfer boundary, multiple transfers and 1 MiB
input. Assert partial progress, invalid transfer rejection, old-output
preservation and balanced ownership. A block larger than the charged quota must
be rejected before native allocation or unsigned quota subtraction. Keep native
frame/record limits and the existing quota unchanged. Run prior gates on the
same final VB6 executable. Test-only driver support must not hide a production
link dependency; inspect production-only O0/O2 output separately.

## UBE declaration-binding gate

The next UBE semantic component binds declarations and signatures, not complete
program expressions. `../bootstrap/tests/declaration-binding/check.ps1` must
run real retained multi-module inputs at O0/O2 and assert exact declaration
identities, regions, visibility, nominal type edges, parameter order/modes and
entry selection. Include the compiler's actual source and legal forward/self/
mutual Type references without claiming recursive storage or computed layout.

Require located rejection for duplicate folded names, ambiguous/inaccessible/
unknown type names, a selected non-Type declaration and invalid entry signatures.
Test module order, separate label regions, independent project state, repeat
binding and changed-input negative controls. Whole-program expression validity,
constant evaluation, primitive authority and lowering remain distinct gates.

Project-storage checks must prove that failed append preserves every previously
committed module and publishes no partial new module, even if capacity grows.
Binding allocation faults must preserve all previous symbol fields, reset public
count/entry, release temporaries and support retry. Corrupt extents, links and
resource exhaustion must produce bounded failure; injected native depth refusal
must not create silent success. Keep existing scanner/parser/storage acceptance
and inspect production-only assembly for unexpected test-provided dependencies.

## UBE expression and constant-binding gate

The next pass must resolve and type-check executable expressions over retained
declaration identities. Its native O0/O2 gate must assert selected symbols,
scope, nominal type/rank, scalar result/conversion types, writable storage,
ByVal/direct-ByRef/grouped-temporary argument modes and checked constant values.
Include actual compiler/library bodies and independent multi-module requests;
an unresolved call in a body must now be rejected rather than ignored.

Exercise qualification, visibility, ambiguity, suffix consistency, function
results, field/index references, label targets and trusted Err fallback with
ordinary user shadowing. Check exact integer extremes, contextual and suffixed
literals, promoted operations, intermediate overflow, final conversions and
earlier-constant ordering. Fixed bounds require checked constants; known-invalid
indexes must fail where bounds remain proven. Dynamic replacement or unvalidated
intrinsic effects may conservatively invalidate bounds proofs, never runtime
index guards. Primitive authority and storage layout remain separate gates.

Changed source/runtime inputs must invalidate exact unchanged assertions. Fault
every observed candidate/index/publication allocation, verify old binding fields
and zero public count, then retry and require zero live allocations at disposal.
Test malformed input, semantic-depth limits and native entry refusal. Run prior
declaration/parser/scanner gates and inspect production native output separately
from test support. No full-program validity claim may bypass pending passes.

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
