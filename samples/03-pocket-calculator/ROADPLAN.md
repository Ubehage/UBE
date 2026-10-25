# Pocket Calculator roadplan

Status markers: `[ ]` pending, `[~]` active, `[x]` verified, `[!]` blocked.

## Outcome

Create a native windowed four-operation calculator demonstrating functions,
arithmetic operators, selection, validation, and recoverable error handling.

## User experience

The designed form provides two operand fields, an operation selector for add,
subtract, multiply, and divide, a Calculate button, a read-only result, and an
inline status message. Clear and Close are keyboard accessible. A failed
calculation never replaces the last valid result with misleading data.

## Project shape

```text
03-pocket-calculator/
|- PocketCalculator.UBE
|- src/Main.bas
|- src/CalculatorForm.frm
|- src/Calculator.bas
|- tests/CalculatorTests.bas
`- README.md
```

## Capability gates

- [ ] Native form/designer support covers text input, selection controls,
  buttons, events, read-only output, focus, and accessibility metadata.
- [ ] The compiler supports the selected numeric type, `Select Case`, functions,
  and explicit recoverable error flow.
- [ ] `UBECore` exposes documented invariant parsing and formatting operations.

## Implementation phases

### 1. Calculation core

- [ ] Define an operation value that cannot represent an unknown operator.
- [ ] Implement one pure calculation function with an explicit success/failure
  contract; do not use exceptions or process termination for division by zero.
- [ ] Specify numeric overflow, underflow, non-finite results, negative zero,
  and result-formatting behavior before implementing the UI.
- [ ] Keep control references and display strings out of `Calculator.bas`.

### 2. Designed form

- [ ] Create the form in the visual designer with meaningful control names,
  aligned labels, logical tab order, and a default Calculate action.
- [ ] Validate each operand independently and focus the first invalid field.
- [ ] Map the selected operation to the core function with exhaustive selection.
- [ ] Display friendly inline errors for malformed operands, unavailable
  operations, division by zero, and numeric range failure.
- [ ] Make Clear deterministic and safe after either success or failure.

### 3. Tests and explanation

- [ ] Unit-test all operations with positive, negative, zero, fractional, and
  boundary values.
- [ ] Add regressions for zero divisors, malformed input, numeric overflow, and
  repeated recovery after an error.
- [ ] Add project/form smoke validation and UI automation when a stable harness
  exists.
- [ ] Document functions, selection, the error-result contract, and exercises
  such as adding remainder or memory buttons.
- [ ] Check all comments against `../../COMMENTS.md`.

## Acceptance criteria

- [ ] Every operation gives a deterministic result for documented inputs.
- [ ] User mistakes never crash, hang, close, or corrupt the form.
- [ ] Logic tests run without constructing native UI.
- [ ] The sample has no third-party dependency and no undocumented intrinsic.

## Non-goals

Expression parsing, operator precedence, scientific functions, calculation
history, and arbitrary precision are outside this sample.
