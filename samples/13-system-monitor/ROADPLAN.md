# System Monitor roadplan

Status markers: `[ ]` pending, `[~]` active, `[x]` verified, `[!]` blocked.

## Outcome

Create a read-only native windowed monitor for CPU, memory, process, and thread
information through a small platform-specific adapter. It demonstrates foreign
declarations, pointer-sized integers, structures, callbacks or polling,
threading, immutable snapshots, and separation of portable presentation from OS
integration.

## User experience

The designed form periodically displays system CPU/memory summaries and a
sortable process table with selected-process thread details where permitted.
Refresh can be paused and its interval bounded. Access denial and disappearing
processes are normal row-level outcomes. The sample never kills, suspends,
renices, debugs, injects into, or writes to a process.

## Project shape

```text
13-system-monitor/
|- SystemMonitor.UBE
|- src/Main.bas
|- src/MonitorForm.frm
|- src/SystemSnapshot.bas
|- src/SnapshotDiff.bas
|- src/PlatformMonitor.bas
|- src/platform/windows/WindowsMonitor.bas
|- src/platform/unix/UnixMonitor.bas       (later target phase)
|- tests/SystemMonitorTests.bas
|- tests/fixtures/
`- README.md
```

## Safety and data contracts

- [ ] Define each displayed metric, unit, sampling interval, unavailable-value
  representation, counter wrap/reset behavior, and rounding rule.
- [ ] Set limits for processes, threads, strings, adapter bytes, queued snapshots,
  refresh rate, memory, and diagnostics.
- [ ] Use stable process identity as PID plus a creation/start identity when the
  platform exposes it; never assume a PID remains the same process.
- [ ] Prefer documented read-only OS queries. Every native handle is least-
  privilege and closed on every path.
- [ ] Pin platform structures, calling conventions, pointer widths, API versions,
  and primary documentation before adding a target adapter.

## Capability gates

- [ ] Foreign declarations, calling conventions, pointer-sized/fixed-width
  integers, structures, arrays, and callback lifetime rules are implemented.
- [ ] Threads, events/queues, cancellation, immutable ownership transfer, and
  UI dispatch have documented contracts.
- [ ] Native UI support provides tables, sorting, selection, timers, progress or
  status, DPI/accessibility behavior, and high-frequency update control.

## Implementation phases

### 1. Portable snapshot model

- [ ] Define platform-neutral system, process, and thread snapshot records with
  explicit availability flags instead of magic sentinel values.
- [ ] Implement checked delta/rate calculations independently of native APIs,
  including zero/negative elapsed time, counter wrap/reset, and new/exited rows.
- [ ] Define deterministic default ordering and stable selection reconciliation.
- [ ] Expose a narrow adapter interface that returns a complete immutable
  snapshot or bounded diagnostics, never UI objects.

### 2. First platform adapter

- [ ] Implement Windows first, matching the project's initial native target;
  record exact supported OS/API minimums.
- [ ] Query only system/process/thread facts needed by the portable model and
  request only documented read/query rights.
- [ ] Copy native strings and structures into owned UBE values before closing
  handles or returning from callbacks.
- [ ] Validate all native counts, lengths, pointers, enum values, structure
  versions, and arithmetic before access or allocation.
- [ ] Convert access denial, process exit races, partial data, unsupported APIs,
  native allocation failure, and callback failure into controlled diagnostics.

### 3. Sampling and lifecycle

- [ ] Use one bounded sampler with cancellation, not one worker per process.
- [ ] Serialize refreshes so a slow sample cannot overlap indefinitely; coalesce
  or drop stale snapshots by documented policy.
- [ ] Publish immutable snapshots through a bounded queue and update controls
  only on the UI thread.
- [ ] On pause/close, stop scheduling, signal cancellation, detach callbacks by
  contract, join the sampler, drain messages, and then release form state.

### 4. Designed form

- [ ] Create summary, process, thread, interval, Pause/Resume, Refresh Now, and
  status controls in the visual designer with keyboard access and resizing.
- [ ] Preserve process selection only when its stable identity is still present.
- [ ] Apply sort and filter in portable code to a stable snapshot, not while the
  adapter is mutating data.
- [ ] Rate-limit screen-reader/live-status announcements and visual updates.
- [ ] Clearly label unavailable, denied, exited, and partial facts.

### 5. Additional platforms

- [ ] Add a Unix-like adapter only after its target, ABI, APIs, and fixtures are
  supported and documented.
- [ ] Keep conditional platform selection in project/build configuration and the
  adapter boundary, never scattered through form logic.
- [ ] Report unsupported platforms cleanly while leaving README/sample-browser
  metadata available.

### 6. Tests and documentation

- [ ] Test snapshot diffs and rates with synthetic counter sequences, process ID
  reuse, exits/starts, wrap/reset, unavailable fields, and extreme values.
- [ ] Test adapter decoding against synthetic native-data fixtures and a small
  controlled integration probe; do not assert volatile host totals exactly.
- [ ] Inject access denial, unsupported API, malformed native lengths/counts,
  allocation failure, queue pressure, cancellation, slow sampling, callback
  failure, and close-during-refresh under timeouts.
- [ ] Stress repeated pause/resume and refresh while checking handle/thread
  counts return to baseline.
- [ ] Document metric meanings, privilege behavior, platform coverage, privacy,
  lifecycle, limits, and build/run steps; review `../../COMMENTS.md`.

## Acceptance criteria

- [ ] Supported metrics are internally consistent and explicitly marked when
  unavailable; volatile ordering never makes tests flaky.
- [ ] Native adapters cannot expose unchecked pointers or outlive callback data.
- [ ] Refresh, cancellation, and close never leak, deadlock, use freed UI state,
  or leave a worker running.
- [ ] All OS interaction is read-only, least-privilege, bounded, and isolated
  behind the adapter interface.

## Non-goals

Process control, priority changes, debugging, memory inspection, kernel drivers,
remote monitoring, alerting services, historical persistence, and performance
benchmark claims are excluded.
