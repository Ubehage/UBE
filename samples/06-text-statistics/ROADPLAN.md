# Text Statistics roadplan

Status markers: `[ ]` pending, `[~]` active, `[x]` verified, `[!]` blocked.

## Outcome

Create a native windowed text-file analyzer reporting line, word, and character
counts plus the most frequent words. It teaches file handling, string
processing, dynamic arrays or collections, sorting, and responsive UI work.

## User experience

The designed form lets the user choose one text file, start or cancel analysis,
and view summary counts and a ranked word-frequency list. The selected file is
never modified. A progress/status area reports empty files, unsupported
encoding, access failure, cancellation, and completion without closing the app.

## Project shape

```text
06-text-statistics/
|- TextStatistics.UBE
|- src/Main.bas
|- src/StatisticsForm.frm
|- src/TextAnalyzer.bas
|- src/WordCounts.bas
|- tests/TextAnalyzerTests.bas
|- tests/fixtures/
`- README.md
```

## Contracts to decide before coding

- [ ] Define supported encodings, newline forms, Unicode character counting,
  word boundaries, and case folding from documented UBE behavior.
- [ ] Define tie ordering for equally frequent words and the maximum displayed
  row count.
- [ ] Set limits for file size, token length, distinct words, memory, and UI
  result size, including the exact controlled failure for each limit.

## Capability gates

- [ ] `UBECore` has documented read-only streaming file and text-decoding APIs,
  string/case operations, collections or dynamic arrays, and sorting support.
- [ ] Native UI support includes a file picker, list/table display, progress,
  cancellation events, accessibility, and safe background-to-UI dispatch.
- [ ] If analysis runs on a worker thread, the thread, cancellation, ownership,
  and synchronization contracts are implemented and tested.

## Implementation phases

### 1. Analyzer core

- [ ] Implement incremental read and decode; never require the entire file in
  memory solely to count it.
- [ ] Count lines, characters, and words with checked counters and explicit EOF
  handling, including empty and final-non-newline files.
- [ ] Normalize words according to the frozen contract and accumulate counts.
- [ ] Sort by descending count and deterministic secondary word order.
- [ ] Poll cancellation at bounded intervals and cleanly close every handle.

### 2. Designed form and orchestration

- [ ] Design the form with path display, Browse, Analyze, Cancel, summary fields,
  ranked results, status, and logical keyboard order.
- [ ] Disable conflicting actions only while work owns their state; always
  restore them on success, failure, or cancellation.
- [ ] Publish only a complete result snapshot to the UI; stale worker completion
  must not overwrite a newer selection or analysis.
- [ ] Keep all native UI access on the UI thread.

### 3. Tests and documentation

- [ ] Test ASCII and non-ASCII text, all supported newlines, empty input,
  punctuation, repeated whitespace, long words, ties, and final lines.
- [ ] Test malformed encoding, missing/unreadable files, files that change while
  open, limit exhaustion, cancellation, and injected read/allocation failure.
- [ ] Verify source files are byte-for-byte unchanged after every test.
- [ ] Add project/form smoke validation and deterministic core tests.
- [ ] Document the text rules, algorithm, complexity, limits, and build/run
  steps; review comments against `../../COMMENTS.md`.

## Acceptance criteria

- [ ] Counts exactly follow the documented contracts and tie order.
- [ ] Large accepted files are processed with bounded memory and responsive UI.
- [ ] No failure leaks a file handle, worker, or partially published result.
- [ ] Analysis is read-only and uses no third-party package.

## Non-goals

Editing files, recursive directory analysis, language-aware tokenization, and
binary-file heuristics are outside this sample.
