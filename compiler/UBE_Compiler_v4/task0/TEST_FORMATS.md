# Compiler v4 test and evidence formats

## Decision

Test cases use the line-oriented `UBE-Test-Case 1` format. Verified builds use
the generated JSON `ube-v4-verified-build-1` record. Both formats are UTF-8
without a byte-order mark, use ordinal field names and comparisons, reject
unknown or duplicate singleton fields, and are hashed as their exact bytes.

The case format is an input contract, so it intentionally resembles the
dependency-minimal UBE project format and needs no general JSON, YAML, XML, or
third-party parser. JSON is retained only for generated evidence because the
repository already emits build manifests in that form and consumers do not
need it to select or execute a case.

## `UBE-Test-Case 1`

The first non-empty line is exactly `UBE-Test-Case 1`. Remaining non-empty
lines are `Name = Value`. A value is either an unsigned decimal integer or a
JSON-style quoted string. Only `\"`, `\\`, `\n`, `\r`, and `\t` escapes are
accepted. Lines beginning with `#` are comments; inline comments are forbidden.
Input paths use `/`, are relative to the case file, and may not escape its
directory. `Expected.ArtifactPath` is repository-relative, uses `/`, and must
remain below `bootstrap/out/`.
The manifest is limited to 1 MiB, 4,096 logical fields, and 65,536 UTF-16 code
units per physical line in the bootstrap runner. Later native runners apply the
same decoded-value limits in Unicode scalar terms and reject discrepancies
instead of truncating input.

Required singleton fields, in this order, are:

```text
Id
Task
Purpose
Compiler
Mode
Host
Target
Expected.Exit
Expected.Artifact
Differential.Level
Repeat
```

`Id` is lowercase ASCII letters, digits, and hyphens and is globally stable.
`Task` is the introducing roadmap task number. `Compiler` is an executable or
declared adapter identity, never a shell command. `Expected.Artifact` is
`required`, `absent`, or `not-applicable`. `Differential.Level` is `0` when no
oracle applies or 1 through 7 from `REUSE_PLAN.md`. `Repeat` is at least one.

The following fields may repeat while preserving declared order:

```text
Category
Input.Source
Input.Project
Input.Resource
Input.Library
Argument
LibrarySlice
Expected.Diagnostic
Expected.Note
Expected.SideEffect
JobCount
Schedule
Limit
Fault
CleanupAssertion
```

`Category` is one of `positive`, `interaction`, `rejection`, `boundary`,
`stress`, `failure`, `regression`, `differential`, `native`, or `determinism`.
Every capability inventory must name all applicable categories. An inapplicable
category is recorded with one of these singleton reason fields:

```text
NotApplicable.Positive
NotApplicable.Interaction
NotApplicable.Rejection
NotApplicable.Boundary
NotApplicable.Stress
NotApplicable.Failure
NotApplicable.Regression
NotApplicable.Differential
NotApplicable.Native
NotApplicable.Determinism
```

Optional singleton expectation fields are `Expected.Stdout`,
`Expected.Stderr`, `Expected.NativeResult`, `Expected.ArtifactPath`, and
`Differential.Normalizer`. Expected text is exact after the named normalizer;
an empty value means exact empty output. Diagnostic strings contain the exact
normalized code, severity, source span, text, and note ordering. Broad
substring matching is not part of the format.

`Expected.Artifact = "required"` requires `Expected.ArtifactPath`. An artifact
path with `absent` names the path whose nonexistence is asserted. An artifact
path is forbidden with `not-applicable`.

`Limit` and `Fault` name versioned runner controls, not environment-variable or
shell fragments. `Argument` is passed as one process argument exactly as
decoded. `CleanupAssertion` names an observable resource or partial-artifact
condition checked after the process returns.

## Runner contract

The cumulative runner:

1. discovers manifests by ordinal normalized relative path;
2. validates every manifest completely before executing any case;
3. rejects duplicate IDs, unknown keys, escaping paths, unsupported versions,
   missing inputs, invalid category coverage, and unavailable adapters;
4. creates an isolated output directory per case and repetition;
5. invokes executables with separate bounded arguments and no shell command;
6. records requested and effective jobs, limits, schedules, and faults;
7. checks exact exit, diagnostics, streams, artifacts, side effects, cleanup,
   native behavior, and the approved differential layer;
8. merges results in case-ID order regardless of execution order;
9. publishes the build record atomically only after all cleanup checks pass;
10. removes or marks all partial outputs on cancellation or failure.

Task suites are cumulative. Selection may narrow a diagnostic run, but a
verified build always includes the active task and every applicable earlier
suite. Changing a shared fixture invalidates and reruns all cases that name it.

## `ube-v4-verified-build-1`

The generated JSON object has the following ordered top-level members:

```text
format
roadmap_task
build_identity
status
bootstrap
inputs
environment
execution
cases
measurements
artifacts
cleanup
```

`bootstrap` identifies the v3 executable and trust hash. `inputs` contains
ordered v4 source/manifest, grammar, library, intrinsic, and runtime identities.
`environment` contains host, target, OS, architecture, and tool versions.
`execution` records requested/effective jobs and active fault/schedule controls.
Each `cases` entry records the case ID, manifest/input hashes, result, exit,
exact diagnostics, artifact hashes, normalizer, repetitions, and skip reason.
`measurements` records deterministic work counters separately from wall time,
CPU time, peak working set, and artifact size. `cleanup` records live-resource
and false-success-artifact checks even when an earlier case failed.

Hashes are uppercase SHA-256 hexadecimal strings. Paths are repository-relative
with `/`. Stable arrays are ordered by declared source identity or case ID, not
filesystem, hash-table, worker, or completion order. Timing values and absolute
host paths are evidence fields and never reproducibility inputs.

The record status is `passed` only when every selected required case passed,
no unexplained skip exists, cleanup succeeded, and no false-success artifact
remains. A failed or interrupted run may write a non-authoritative diagnostic
record with status `failed` or `cancelled`, but must not replace the last
verified record.
