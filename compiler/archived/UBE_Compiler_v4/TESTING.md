# UBE Compiler v4 verified-build policy

## Rule

Every roadmap implementation step and every compiler build claimed to work
must be tested with small programs written specifically to prove, reject,
stress, and break the capability added by that build. Building the compiler
successfully is not evidence that the compiler works.

Tests accumulate. A later verified build must pass its new focused cases and
every applicable case from all earlier verified builds. A test may be replaced
only when the owning contract intentionally changes with owner approval; the
reason and equivalent or stronger replacement coverage must be recorded.

Task 0 prototypes are not compiler builds, but the same principle applies:
each design claim must be exercised by explicit valid, malformed, boundary,
and scaling fixtures with reproducible measurements.

## Required test set for each capability

Every implemented capability needs the smallest applicable cases from all of
these categories:

1. **Positive:** the smallest valid program demonstrating the feature and its
   observable result.
2. **Interaction:** a small program combining the feature with each existing
   subsystem whose invariants it can affect.
3. **Rejection:** invalid programs for every new diagnostic rule, including
   exact diagnostic identity, source span, exit status, and artifact behavior.
4. **Boundary:** empty, minimum, maximum, just-inside, and just-outside cases
   for relevant sizes, counts, numeric ranges, nesting, and resource limits.
5. **Stress:** generated but reproducible inputs large enough to expose poor
   scaling, leaks, unchecked growth, recursion, or repeated global work.
6. **Failure injection:** allocation, file, process, worker, cancellation,
   publication, and cleanup failures at every newly owned external boundary.
7. **Regression:** every discovered crash, hang, miscompile, nondeterministic
   result, leak, bad diagnostic, or false-success artifact becomes a minimal
   permanent test that fails before the correction.
8. **Differential:** when v3 implements the same contract, run the input through
   v3 and v4 and compare the approved observable layer.
9. **Native behavior:** when code generation is involved, validate the emitted
   representation, link it, run it, and check output, exit status, side effects,
   and controlled runtime failures.
10. **Determinism:** repeat the test with relevant hash seeds, job counts,
    schedules, source ordering permutations, and clean output directories, then
    compare every result that the contract requires to be stable.

A category may be marked not applicable only with a short reason in the task's
test record. It must not be silently omitted.

## Small-test rule

Prefer one program per behavior or failure. A useful regression should make it
obvious which contract broke without requiring a self-build or the complete
corpus. Large self-host, library, package, and stress gates remain necessary,
but they supplement rather than replace focused tests.

Each test case records:

- a stable case ID and one-sentence purpose;
- the task and contract it protects;
- every source/project/resource/library input;
- compiler command, mode, host, target, and required library slice;
- expected exit status;
- expected diagnostics, spans, notes, and ordering where applicable;
- expected stdout, stderr, native result, and side effects where applicable;
- whether an output artifact must exist or must not exist;
- differential comparison level and permitted normalization, if any;
- repetition, job-count, schedule, limit, or fault-injection parameters; and
- cleanup/resource assertions.

Do not make a test pass using a broad output substring when the relevant result
can be compared exactly. Do not bless changed output until the underlying
contract has been reviewed.

## Planned test organization

When Task 2 creates the production scaffold, it also creates the test runner
and a hierarchy organized by the roadmap task that introduced each contract:

```text
compiler/UBE_Compiler_v4/tests/
|-- task02-shell/
|-- task03-vertical-slice/
|-- task04-lexing/
|-- task05-parsing/
|-- task06-declarations-types/
|-- task07-semantics/
|-- task08-ir/
|-- task09-backend/
|-- task10-projects-runtime/
|-- task11-parallelism/
|-- task12-bootstrap/
`-- task13-hardening/
```

The frozen machine-readable formats and runner contract are defined in
[`task0/TEST_FORMATS.md`](task0/TEST_FORMATS.md). Checked-in inputs use
`UBE-Test-Case 1`, a dependency-minimal line format patterned after UBE project
files. Generated evidence uses `ube-v4-verified-build-1` JSON, consistent with
existing repository build records. Shared fixtures are permitted only when
their ownership is explicit; a change to a shared fixture reruns every
dependent case.

## Gate for every development build

An agent may use an unverified build for diagnosis, but must never present it
as a completed step, new baseline, or working compiler. A verified development
build must pass, in order:

1. v3 builds the current v4 source and required exact library slice.
2. Compiler startup and argument/environment failure smoke tests pass.
3. The active task's focused positive, rejection, boundary, and regression
   cases pass.
4. The active task's stress and failure-injection cases pass.
5. All applicable earlier v4 task suites pass.
6. The selected v3/v4 differential corpus passes.
7. Applicable IR, LLVM, native, ABI, package, runtime, and cleanup gates pass.
8. Repeated and multi-job runs satisfy the current determinism contract.
9. Work counters, wall/CPU time, peak memory, and artifact size remain within
   the accepted budgets for affected fixtures.
10. The generated build record is complete and no false-success artifact or
    live external resource remains.

During the earliest vertical slices, later unavailable layers are recorded as
not applicable. They become mandatory permanently when first implemented.

## Verified-build record

Each verified build produces a generated record outside the source directory,
under `bootstrap/out/`, containing at least:

- roadmap task and build identity;
- v3 bootstrap compiler identity;
- v4 ordered source and manifest hashes;
- grammar, library, intrinsic, runtime, host, target, and toolchain identities;
- exact test case IDs and input hashes;
- results, diagnostics, exits, artifact hashes, and permitted normalizations;
- requested/effective jobs and relevant fault/schedule parameters;
- deterministic work counters;
- wall time, CPU time, peak memory, and artifact size for performance fixtures;
- skipped cases with explicit reasons; and
- final cleanup and false-success-artifact status.

Timing values are evidence rather than reproducibility inputs. Stable semantic
and artifact fields remain subject to the approved comparison policy.

## Completion rule

A roadmap task is not complete until:

- its focused test inventory covers every new contract and failure path;
- the tests fail for the intended reason before the implementation or against
  an explicit fault/mutation where practical;
- the corrected implementation passes them;
- the cumulative suite passes;
- the verified-build record is preserved; and
- `Progress.md` lists the exact command, results, measurements, known limits,
  and first resumption action.
