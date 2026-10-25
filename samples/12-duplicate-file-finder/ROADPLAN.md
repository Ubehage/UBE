# Multithreaded Duplicate File Finder roadplan

Status markers: `[ ]` pending, `[~]` active, `[x]` verified, `[!]` blocked.

## Outcome

Create a read-only native windowed tool that walks selected directory trees,
groups files by size, hashes candidates concurrently, and reports byte-identical
duplicates without offering deletion. It demonstrates filesystem traversal,
binary streams, large-file handling, threads, synchronization, cancellation,
deterministic merging, and bounded resource use.

## User experience

The designed form accepts one or more roots, configurable safe exclusions, and
a bounded worker count. Scan and Cancel control the run. Progress reports files
discovered, candidates hashed, and bytes read. Results group duplicate paths and
estimated redundant bytes; warnings report inaccessible or changed files. The
only result action copies a path or exports a report, never alters a source.

## Project shape

```text
12-duplicate-file-finder/
|- DuplicateFileFinder.UBE
|- src/Main.bas
|- src/DuplicateFinderForm.frm
|- src/TreeWalker.bas
|- src/HashWorker.bas
|- src/DuplicateMerge.bas
|- src/PlatformFileIdentity.bas
|- tests/DuplicateFinderTests.bas
|- tests/fixtures/
`- README.md
```

## Safety and behavior contracts

- [ ] Freeze symlink/reparse-point behavior; default to not following directory
  links and never escape a selected root through one.
- [ ] Define hard-link behavior using platform file identity when available so
  two names for the same underlying file are not reported as wasted copies.
- [ ] Define handling for sparse files, unreadable entries, case rules, path
  normalization, traversal cycles, files changed during scanning, and metadata
  races.
- [ ] Set hard limits for roots, depth, entries, path length, candidates, open
  handles, workers, queue entries, memory, hash bytes, warnings, and UI rows.
- [ ] Select a documented cryptographic hash from `UBECore`; hash equality must
  still be followed by chunked byte comparison before reporting duplicates.

## Capability gates

- [ ] `UBECore` provides read-only directory enumeration, file metadata/identity,
  binary streaming, incremental hashing, checked 64-bit sizes, and path APIs.
- [ ] Threads, bounded queues, cancellation, atomics/locks, and join behavior
  have documented failure and ownership contracts.
- [ ] Native UI support includes directory pickers, result trees/tables,
  progress, accessibility, worker dispatch, and safe report save.

## Implementation phases

### 1. Sequential reference scanner

- [ ] Walk roots deterministically with explicit pending-directory storage rather
  than unbounded recursion.
- [ ] Collect only bounded metadata and group regular files by exact size;
  singleton size groups never enter hashing.
- [ ] Record warnings as data, with normalized path and bounded diagnostic text.
- [ ] Build a sequential implementation first as the oracle for parallel tests.

### 2. Candidate verification pipeline

- [ ] Optionally compare a fixed prefix before full hashing if measurements show
  benefit; every read remains bounded and cancellation-aware.
- [ ] Hash files incrementally with a fixed-size reusable buffer and checked byte
  counters; never map an unbounded file into memory.
- [ ] Re-stat before and after hashing and reject unstable candidates whose
  identity, size, or modification facts change.
- [ ] For equal size and digest, perform chunked byte comparison before adding a
  reported duplicate group.

### 3. Bounded concurrency and deterministic merge

- [ ] Use a fixed-size worker pool and bounded task/result queues.
- [ ] Keep worker-local stream/buffer/hash state and publish immutable results
  exactly once; never share a stream across workers.
- [ ] Stop enqueuing on cancellation, wake blocked workers, drain or abandon
  tasks by contract, join every worker, and close every handle.
- [ ] Sort paths and groups by a documented normalized ordinal key after work
  completes so scheduling cannot affect output.
- [ ] Treat thread, queue, allocation, open, read, compare, and join failures as
  controlled run outcomes with partial results clearly marked incomplete.

### 4. Designed form and reporting

- [ ] Design roots, exclusions, worker limit, Scan/Cancel, progress, warning, and
  grouped result controls with keyboard access and resizing behavior.
- [ ] Use run IDs and UI-thread messages so stale workers cannot mutate a later
  run or a closed form; bound update frequency and queued messages.
- [ ] Export only a newly chosen report file via temporary-write and atomic-
  replace rules; never write inside scanned roots implicitly.
- [ ] Include a permanent notice that the tool does not delete or modify files.

### 5. Tests and documentation

- [ ] Test empty trees, unique files, empty duplicates, binary/large/sparse files,
  Unicode paths, identical prefixes, forced digest collision, and hard links.
- [ ] Test symlink cycles/escapes, deep/wide trees, permission denial, disappearing
  and changing files, path/size overflow, every configured limit, and export
  failure using isolated synthetic trees.
- [ ] Compare sequential and parallel results across worker counts and randomized
  task completion; stress cancellation and close at every lifecycle stage.
- [ ] Verify content and metadata of all scanned fixtures remain unchanged.
- [ ] Document algorithms, race limitations, hashing-versus-byte-compare safety,
  resource limits, and build/run steps; review `../../COMMENTS.md`.

## Acceptance criteria

- [ ] Every reported group is confirmed byte-for-byte identical and contains
  distinct file identities according to the documented hard-link policy.
- [ ] Results are deterministic across schedules and worker counts.
- [ ] The scan has bounded handles, threads, queues, memory, and update traffic.
- [ ] Cancellation/failure leaves no live worker or handle and never changes a
  scanned file.

## Non-goals

Deletion, deduplication, hard-link creation, file moves, automatic cleanup,
network shares as a promised target, and claims of race-free live-filesystem
snapshots are excluded.
