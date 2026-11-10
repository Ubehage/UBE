# Compiler acceptance gates

**Status:** predefined requirements; source-compiler execution pending.

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
is parsed there, but execution requirements below are still pending.

The native fixture in `../bootstrap/tests/failure-flow/` tests the feasibility
of the approved behavior. A real compiler must later accept matching UBE source
and reproduce the same outcomes, without consulting a test name or embedding
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

## Self-hosting gate, after source dependencies are implemented

Build the UBE-written compiler with VB6 bootstrap, then rebuild it through
successive UBE-generated executables. Compare deterministic generated outputs
and run identical positive, negative and recovery corpora with both. Report
actual differences; never treat a successful self-build alone as conformance.

## Current limits

The prototype does not qualify source parsing/lowering, complete Err metadata,
TLS/thread isolation, stack exhaustion recovery, managed-resource cleanup,
real external-resource release, foreign ABI or optimizer correctness outside
the asserted scenarios. Add focused gates before claiming those capabilities.
