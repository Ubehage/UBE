# Personal Expense Tracker roadplan

Status markers: `[ ]` pending, `[~]` active, `[x]` verified, `[!]` blocked.

## Outcome

Create a native windowed, CSV-backed personal expense tracker that records
transactions and reports totals by category and month. It teaches custom types,
dates, dynamic arrays, parsing, validation, deterministic summaries, and safe
persistence.

## User experience

The designed form provides date, description, category, and amount fields; an
add action; a transaction table; month/category filters; summary totals; and
explicit Open, Save, and Save As actions. Unsaved changes are visible. Closing,
opening another file, or reloading never discards edits without confirmation.

## Project shape

```text
07-expense-tracker/
|- ExpenseTracker.UBE
|- src/Main.bas
|- src/ExpenseForm.frm
|- src/Transactions.bas
|- src/ExpenseCsv.bas
|- src/ExpenseReports.bas
|- tests/ExpenseTrackerTests.bas
|- tests/fixtures/
`- README.md
```

## Contracts to decide before coding

- [ ] Freeze the CSV dialect: UTF-8, newline policy, header, quoting, embedded
  comma/quote/newline behavior, and malformed-row diagnostics.
- [ ] Represent money with a documented exact type such as `Currency` or scaled
  integer; never use binary floating point for persisted amounts.
- [ ] Use invariant UBE dates in storage and define valid date and amount ranges.
- [ ] Set maximum file, row, field, and in-memory transaction limits.

## Capability gates

- [ ] The language supports the required custom type, date/money type, dynamic
  storage, and checked aggregation.
- [ ] `UBECore` provides CSV-building primitives, date and exact-number parsing,
  filesystem reads, and atomic replace/write facilities.
- [ ] The UI/designer supports table display, file dialogs, dirty-state close
  handling, validation, accessibility, and confirmation dialogs.

## Implementation phases

### 1. Transaction and report model

- [ ] Define a transaction record with explicit fields and validation invariants.
- [ ] Implement add, filter, category totals, month totals, and deterministic
  ordering without UI dependencies.
- [ ] Check every accumulation for range failure and report which summary could
  not be produced.

### 2. CSV persistence

- [ ] Parse into temporary state with row-numbered diagnostics; never partly
  replace the active model after a failed load.
- [ ] Serialize fields with the frozen quoting rules and deterministic ordering.
- [ ] Save to a sibling temporary file, flush, and atomically replace the target
  where supported; preserve the original and explain recovery on failure.
- [ ] Keep no hidden autosave and never overwrite a file merely because it was
  opened.

### 3. Designed form

- [ ] Build the form in the visual designer with logical grouping, resizing,
  keyboard access, and accessible table/summary labels.
- [ ] Validate a prospective transaction before mutating the model.
- [ ] Recompute visible summaries from the model after each accepted change.
- [ ] Track clean/dirty state from successful load/save boundaries.

### 4. Tests and documentation

- [ ] Test valid round trips, quoting edge cases, Unicode, all supported newline
  forms, empty datasets, leap dates, exact money, filtering, and tie ordering.
- [ ] Test malformed rows, duplicate/missing headers, range overflow, truncation,
  read-only destinations, full-disk/write/replace failure, and interrupted save.
- [ ] Prove failed load/save preserves both in-memory state and the last good
  on-disk file.
- [ ] Document the schema, safety model, privacy limitations, and build/run
  steps; review comments against `../../COMMENTS.md`.

## Acceptance criteria

- [ ] CSV written by the sample round-trips without information loss.
- [ ] Totals are exact, deterministic, and checked.
- [ ] No ordinary persistence failure loses the prior file or active edits.
- [ ] The sample uses no network, encryption claim, or third-party dependency.

## Non-goals

Bank synchronization, tax advice, authentication, cloud storage, receipt
images, multi-currency conversion, and financial forecasting are excluded.
