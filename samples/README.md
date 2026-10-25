# UBE sample-program roadplans

This directory contains the implementation roadplans for the thirteen sample
programs selected for distribution with the UBE compiler and IDE. Each sample
will live in its own directory so its project, source, tests, fixtures, and
reader documentation remain self-contained.

The roadplans describe future work; they do not claim that every required
compiler or library capability is implemented. Before starting a phase, verify
its capability gates against the language specification, compiler roadmap, and
source-library status.

## How to use these roadplans

Use the status markers defined in each `ROADPLAN.md`. Update a roadplan in the
same change that completes or materially changes one of its items. A capability
gate becoming available does not complete the sample work behind that gate; its
implementation, failure handling, tests, comments, and reader documentation
must still be verified.

The recommended delivery order is dependency-driven:

| Wave | Samples | Main capability unlocked or exercised |
|---|---|---|
| 1 | 1 | Console project, core syntax, and smoke-test path |
| 2 | 2-5 | Native forms, visual designer, events, parsing, and formatting |
| 3 | 6-8 | Files, collections, structured models, and safe persistence |
| 4 | 9 | Custom drawing, timers, grids, and callback lifetime |
| 5 | 10 | Bounded threads, cancellation, synchronization, and UI dispatch |
| 6 | 11-13 | Defensive binary/system adapters and advanced native integration |

A later wave may begin early when its gates exist, but it must not invent a
private API that bypasses the compiler, `UBECore`, project format, or native UI
contracts merely to make a sample run.

## Beginner

1. [Hello, UBE!](01-hello-ube/ROADPLAN.md)
2. [Temperature Converter](02-temperature-converter/ROADPLAN.md)
3. [Pocket Calculator](03-pocket-calculator/ROADPLAN.md)
4. [Guess the Number](04-guess-the-number/ROADPLAN.md)
5. [Multiplication Table](05-multiplication-table/ROADPLAN.md)

## Intermediate

6. [Text Statistics](06-text-statistics/ROADPLAN.md)
7. [Personal Expense Tracker](07-expense-tracker/ROADPLAN.md)
8. [Contact Book](08-contact-book/ROADPLAN.md)
9. [Conway's Game of Life](09-game-of-life/ROADPLAN.md)
10. [Parallel Log Analyzer](10-parallel-log-analyzer/ROADPLAN.md)

## Advanced system tools

11. [Executable Inspector](11-executable-inspector/ROADPLAN.md)
12. [Multithreaded Duplicate File Finder](12-duplicate-file-finder/ROADPLAN.md)
13. [System Monitor](13-system-monitor/ROADPLAN.md)

## Rules shared by every sample

- Follow the normative language specification and use only implemented,
  documented behavior.
- Never panic or crash on malformed input, missing files, unavailable platform
  facilities, allocation failure, or ordinary I/O errors.
- Keep third-party dependencies at zero.
- Give every module, procedure, and advanced section the comments required by
  `../COMMENTS.md`.
- Include a reader-facing `README.md`, a `.UBE` project, source files, and
  deterministic automated tests where practical.
- Clearly label platform-specific code and keep it behind a narrow adapter.
- Prefer safe, bounded inputs and resource use. The advanced tools remain
  read-only and never alter inspected files or processes.
- A sample is complete only when it builds through the supported UBE toolchain,
  passes its tests, handles documented failure cases, and opens from the IDE's
  sample browser when that integration exists.
