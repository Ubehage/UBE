# UBE sample programs to make

This file records the thirteen sample-program ideas accepted for future
distribution with the UBE compiler and IDE. The samples form a progression
from introductory Basic programs to advanced demonstrations of native system
programming.

Detailed implementation roadplans are maintained under [`/samples/`](samples/README.md).
The first program is a console application.
The others must be windowed programs, showcasing the visual designer and IDE.


## Beginner samples

### 1. Hello, UBE!

A first console program demonstrating comments, output, variables, strings,
and simple arithmetic.

### 2. Temperature Converter

An interactive converter for Celsius, Fahrenheit, and Kelvin demonstrating
user input, numeric conversion, procedures, validation, and formatted output.

### 3. Pocket Calculator

A small calculator demonstrating functions, arithmetic operators, selection,
input validation, and recoverable error handling.

### 4. Guess the Number

An interactive number-guessing game demonstrating random numbers, loops,
conditions, counters, and friendly input validation.

### 5. Multiplication Table

A configurable multiplication table demonstrating `For` loops, nested loops,
alignment, and reusable formatting procedures.

## Intermediate samples

### 6. Text Statistics

A text-file analyzer reporting line, word, and character counts and the most
frequent words. It demonstrates file handling, strings, arrays, and sorting.

### 7. Personal Expense Tracker

A CSV-backed transaction tracker producing totals by category and month. It
demonstrates custom types, dates, dynamic arrays, parsing, validation, and
persistence.

### 8. Contact Book

A contact manager supporting add, search, edit, delete, sort, import, and
export operations. It demonstrates multiple modules, encapsulation,
collections, and structured file storage.

### 9. Conway's Game of Life

A console simulation demonstrating two-dimensional grids, arrays, algorithms,
state transitions, timers, and terminal rendering.

### 10. Parallel Log Analyzer

A tool that processes multiple log files concurrently and combines their
statistics. It demonstrates multiple source files, threads, synchronization,
error propagation, and deterministic result merging.

## Advanced system tools

These tools must be read-only so that the distributed samples cannot damage
files or processes.

### 11. Executable Inspector

A defensive binary inspector for PE files on Windows and, eventually, ELF
files on supported Unix-like systems. It displays architecture, sections,
entry point, imports, and validated header information while demonstrating
binary I/O, fixed-width integers, bounds checking, structures, and endianness.

### 12. Multithreaded Duplicate File Finder

A read-only tool that walks directory trees, groups files by size, calculates
hashes concurrently, and reports duplicates without deleting them. It
demonstrates native threads, atomics or locks, cancellation, binary file
access, large-file handling, and bounded resource use.

### 13. System Monitor

A read-only display of CPU, memory, process, and thread information through a
small platform-specific adapter. It demonstrates native-library declarations,
pointer-sized integers, structures, callbacks, threading, and separation of
portable logic from operating-system integration.

## Shared expectations

Each sample will eventually have its own `.UBE` project and source directory
under `/samples/`, a short reader-facing README, helpful handling of invalid
input and unavailable facilities, comments conforming to `COMMENTS.md`, and
automated smoke tests where practical. Samples must not require third-party
packages.

The accepted scope and implementation phases for each program are linked from
the [`samples` index](samples/README.md).
