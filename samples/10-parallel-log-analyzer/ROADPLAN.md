# Parallel Log Analyzer roadplan

Status markers: `[ ]` pending, `[~]` active, `[x]` verified, `[!]` blocked.

## Outcome

Create a native windowed tool that analyzes multiple log files concurrently and
merges their statistics deterministically. It teaches multiple source files,
threads, synchronization, cancellation, error propagation, bounded concurrency,
and stable result merging.

## User experience

The form accepts a set of files, displays queued/running/completed status, and
offers Analyze and Cancel. Results include per-file and combined line/severity
counts using a frozen sample log format. Individual failures are visible without
discarding successful results, and no source file is modified.

## Project shape

```text
10-parallel-log-analyzer/
|- ParallelLogAnalyzer.UBE
|- src/Main.bas
|- src/LogAnalyzerForm.frm
|- src/LogParser.bas
|- src/AnalysisWorker.bas
|- src/ResultMerge.bas
|- tests/ParallelAnalyzerTests.bas
|- tests/fixtures/
`- README.md
```

## Contracts to decide before coding

- [ ] Freeze the accepted UTF-8 log-line format, newline behavior, severity
  names, malformed-line policy, and counter ranges.
- [ ] Set limits for selected files, file size, line length, worker count, queued
  messages, memory, and displayed diagnostics.
- [ ] Define deterministic output order independently of worker completion order.

## Capability gates

- [ ] `UBECore` thread, atomic/lock, event, queue, cancellation, and error APIs
  have complete ownership and shutdown contracts.
- [ ] Read-only streaming files and decoding are implemented and fault-testable.
- [ ] Native UI support provides multi-file selection, table/progress controls,
  accessible status, and safe worker-to-UI message dispatch.

## Implementation phases

### 1. Sequential reference path

- [ ] Implement a pure line parser and a sequential per-file analyzer first.
- [ ] Produce one immutable result record per normalized selected path, including
  success, cancellation, or a bounded diagnostic.
- [ ] Implement checked combination and deterministic sorting as a separate
  merge operation.
- [ ] Use the sequential path as the behavioral oracle for parallel tests.

### 2. Bounded parallel engine

- [ ] Use a bounded worker count based on documented configuration, never one
  unbounded thread per file.
- [ ] Give each task isolated mutable counters; synchronize only task dispatch,
  cancellation state, and result publication.
- [ ] Publish each task result exactly once and merge only after ownership has
  transferred safely.
- [ ] On cancellation, stop scheduling new work, request active workers to stop
  at bounded intervals, drain/join them, and release every file handle.
- [ ] Convert thread creation, read, decode, allocation, queue, and join failures
  into controlled per-run outcomes.

### 3. Designed form

- [ ] Design file selection, bounded worker setting, Analyze/Cancel actions,
  progress, per-file results, combined results, and status.
- [ ] Tag each run so stale events from an earlier run cannot update a later run.
- [ ] Never access controls from workers; marshal immutable messages to the UI
  thread and bound pending messages.
- [ ] Prevent close from destroying state until cancellation and worker joining
  have reached a safe terminal state.

### 4. Tests and documentation

- [ ] Compare sequential and parallel output across worker counts and deliberately
  permuted completion orders.
- [ ] Test empty/malformed/Unicode/long-line files, duplicates, missing files,
  access denial, mid-read changes, counter overflow, and every resource limit.
- [ ] Stress repeated runs, cancellation at each lifecycle stage, injected worker
  creation/read/allocation failures, and close during work under timeouts.
- [ ] Verify every input remains byte-for-byte unchanged.
- [ ] Document the format, concurrency design, synchronization, deterministic
  merge, limits, and build/run steps; review `../../COMMENTS.md`.

## Acceptance criteria

- [ ] Parallel results exactly equal the sequential reference results.
- [ ] Output is stable regardless of scheduling or worker count.
- [ ] Cancellation and all failures terminate cleanly without leaked workers,
  handles, deadlocks, or UI use-after-close.
- [ ] The sample is read-only and dependency-free.

## Non-goals

Live log tailing, network sources, regular-expression engines, compressed logs,
or benchmarking claims are outside this sample.
