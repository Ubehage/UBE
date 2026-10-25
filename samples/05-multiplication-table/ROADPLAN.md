# Multiplication Table roadplan

Status markers: `[ ]` pending, `[~]` active, `[x]` verified, `[!]` blocked.

## Outcome

Create a configurable native windowed multiplication table demonstrating `For`
loops, nested loops, alignment, reusable formatting procedures, and bounded UI
generation.

## User experience

The form accepts a table size within a documented safe range and renders row and
column headers plus products in an aligned, scrollable monospaced output area.
Generate replaces the previous table atomically; invalid input leaves the last
valid table intact. Copy and Reset may be included only when supported by the
documented native UI library.

## Project shape

```text
05-multiplication-table/
|- MultiplicationTable.UBE
|- src/Main.bas
|- src/TableForm.frm
|- src/TableFormatter.bas
|- tests/TableFormatterTests.bas
`- README.md
```

## Capability gates

- [ ] The compiler supports bounded and nested `For` loops and checked integer
  multiplication for the chosen maximum table size.
- [ ] `UBECore` provides integer-to-string conversion and the string operations
  needed for padding and line construction.
- [ ] The native designer/runtime provides numeric text input, scrollable
  read-only multiline output, buttons, fonts, events, and accessibility.

## Implementation phases

### 1. Pure table formatter

- [ ] Choose and document minimum and maximum dimensions based on overflow,
  memory, output-size, and usability limits.
- [ ] Implement a reusable left- or right-padding procedure without depending
  on UI controls.
- [ ] Compute column width from the largest possible product and header.
- [ ] Build output with nested `For` loops in deterministic row-major order.
- [ ] Detect allocation or conversion failure and return a controlled result;
  do not expose partial output as a complete table.

### 2. Designed form

- [ ] Design a resizable form with size input, Generate and Reset actions, an
  inline status label, and a scrollable monospaced output control.
- [ ] Parse and validate the size before starting generation.
- [ ] Build into temporary state, then replace displayed content only after
  successful completion.
- [ ] Keep the form responsive by enforcing the bound; add cancellation only if
  later limits make generation meaningfully long.

### 3. Tests and teaching material

- [ ] Test minimum, typical, and maximum sizes plus exact spacing and newlines.
- [ ] Test invalid, overflowing, negative, zero, and above-limit dimensions.
- [ ] Add regressions for multiplication overflow and output allocation failure
  when fault injection is available.
- [ ] Validate the project and designer metadata in a smoke test.
- [ ] Explain nested loops, formatting width, resource bounds, and extension
  ideas in the README; review comments against `../../COMMENTS.md`.

## Acceptance criteria

- [ ] Every accepted dimension produces a complete, correctly aligned table.
- [ ] Generation is deterministic and uses bounded memory and time.
- [ ] Failure preserves the last valid display and leaves the form usable.
- [ ] The window works at supported DPI settings and with keyboard navigation.

## Non-goals

Spreadsheets, printing, arbitrary-precision products, and unbounded table sizes
are outside the sample.
