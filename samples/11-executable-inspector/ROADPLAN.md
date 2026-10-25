# Executable Inspector roadplan

Status markers: `[ ]` pending, `[~]` active, `[x]` verified, `[!]` blocked.

## Outcome

Create a defensive, read-only native windowed inspector for PE executables on
Windows and, in a later portable phase, ELF files on supported Unix-like
systems. It demonstrates binary I/O, fixed-width integers, structures,
endianness, offset arithmetic, bounds checking, and format-specific adapters.

## User experience

The designed form opens one file and displays detected format, architecture,
entry point, validated header facts, sections, and imports in navigable tables.
Warnings distinguish unsupported data from corrupt data. The tool never executes,
loads as code, repairs, rewrites, quarantines, or otherwise changes the file.

## Project shape

```text
11-executable-inspector/
|- ExecutableInspector.UBE
|- src/Main.bas
|- src/InspectorForm.frm
|- src/BinaryReader.bas
|- src/ExecutableModel.bas
|- src/PeParser.bas
|- src/ElfParser.bas              (later phase)
|- tests/ExecutableInspectorTests.bas
|- tests/fixtures/
`- README.md
```

## Safety and format contracts

- [ ] Open inputs read-only with sharing behavior documented for the target.
- [ ] Treat every integer, count, size, offset, alignment, name, and table link
  as hostile until checked against file bounds and configured limits.
- [ ] Use checked add/multiply/range helpers before allocation, seek, or slice;
  never validate `offset + size` with overflowing arithmetic.
- [ ] Bound file size, headers, sections, imports, symbols, strings, nesting,
  diagnostics, and displayed rows before allocating proportional storage.
- [ ] Freeze supported PE variants and machine types from primary format
  documentation before coding; do the same separately for ELF.
- [ ] Store only small redistributable synthetic fixtures in the repository.

## Capability gates

- [ ] Fixed-width unsigned integers, safe conversions, structures, arrays, and
  explicit little-endian decoding are implemented and tested.
- [ ] `UBECore` exposes seekable read-only binary streams with exact-read and
  controlled EOF/error behavior.
- [ ] The native designer/runtime supports a file picker, tree/table/detail
  views, accessible status, and safe background analysis if used.

## Implementation phases

### 1. Defensive binary reader

- [ ] Implement cursor-independent reads for byte arrays and little-endian
  integers that return controlled results rather than unchecked values.
- [ ] Centralize range, count, conversion, and null-terminated-string limits.
- [ ] Test every helper at zero, EOF, maximum integer, overflow, truncation, and
  injected I/O/allocation failure before parsing a real format.

### 2. PE identification and headers

- [ ] Validate DOS magic and `e_lfanew` before seeking to the PE signature.
- [ ] Parse COFF and optional headers by declared size, magic, and supported
  variant; do not cast file bytes directly to native structures.
- [ ] Decode machine/architecture, characteristics, image base, and entry point
  with unknown values preserved numerically.
- [ ] Reject impossible counts, overlaps, truncation, invalid alignment, and
  ranges outside the file with offset-aware diagnostics.

### 3. PE sections and imports

- [ ] Parse section records within configured limits and validate raw-data and
  virtual-address mappings before using them.
- [ ] Implement a single checked RVA-to-file-offset routine with tests for
  headers, section edges, zero-fill, overlap, and unmapped RVAs.
- [ ] Walk import descriptors and thunk/name tables with explicit termination
  and step limits; support ordinal and named imports.
- [ ] Preserve partial trusted facts only when the model clearly labels the
  parse incomplete; never present unchecked data as validated.

### 4. Designed form and worker lifecycle

- [ ] Build the form in the visual designer with summary, section, import,
  warning, and error views plus keyboard navigation and accessible labels.
- [ ] Parse into an immutable temporary model and publish it atomically only for
  the current file request.
- [ ] If parsing is background work, use run IDs, bounded messages, cancellation,
  join-before-destroy, and UI-thread-only control access.

### 5. ELF extension

- [ ] Add ELF only after PE is complete and supported Unix targets exist.
- [ ] Put ELF class, endianness, header, section/program-table, entry-point, and
  dynamic-import parsing behind the same format-neutral model.
- [ ] Add big-endian fixtures only when the compiler/runtime and supported
  targets define and test that behavior.
- [ ] Keep platform/format availability visible; unsupported formats are normal
  controlled outcomes.

### 6. Verification and documentation

- [ ] Generate minimal valid and one-fault-at-a-time malformed fixtures with a
  reviewed repository script; do not depend on host executables for assertions.
- [ ] Cover every accepted header variant and every bounds/count/string limit,
  including truncation at each structural boundary.
- [ ] Fuzz parsers under time, allocation, and recursion/iteration limits; every
  input must return a model or controlled diagnostic, never crash or hang.
- [ ] Verify fixtures remain byte-for-byte unchanged and no executable is loaded.
- [ ] Document supported facts, limitations, threat model, format references,
  and build/run steps; review comments against `../../COMMENTS.md`.

## Acceptance criteria

- [ ] Valid supported binaries produce accurate, deterministic inspected facts.
- [ ] Arbitrary bytes, corrupt headers, huge claims, and I/O failure cannot cause
  out-of-bounds access, excessive resource use, a crash, or a hang.
- [ ] The program performs no write or execution operation on the selected file.
- [ ] Format-specific code stays behind a narrow parser interface.

## Non-goals

Disassembly, decompilation, signature trust decisions, malware classification,
debugging, patching, symbol-server access, and exhaustive format coverage are
explicitly excluded.
