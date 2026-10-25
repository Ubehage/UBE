# Temperature Converter roadplan

Status markers: `[ ]` pending, `[~]` active, `[x]` verified, `[!]` blocked.

## Outcome

Create a native windowed temperature converter for Celsius, Fahrenheit, and
Kelvin. It teaches text input, numeric conversion, procedures, validation, and
formatted output through a small form designed in the UBE IDE.

## User experience

The form contains a temperature input, source-unit and target-unit selectors,
a Convert button, a read-only result, a validation message, and keyboard-friendly
Reset and Close actions. Invalid input remains editable and never opens a modal
error loop. Temperatures below absolute zero are rejected.

## Project shape

```text
02-temperature-converter/
|- TemperatureConverter.UBE
|- src/Main.bas
|- src/ConverterForm.frm
|- src/TemperatureMath.bas
|- tests/TemperatureMathTests.bas
`- README.md
```

## Capability gates

- [ ] Project loading supports `Startup = "Main"`, `StartupForm`, form modules,
  and their designer metadata.
- [ ] The native UI library and IDE designer provide labels, text boxes, unit
  selectors, buttons, events, focus order, and accessible names.
- [ ] `UBECore` provides documented invariant numeric parsing and formatting.
- [ ] Floating-point arithmetic and recoverable error handling are verified by
  the supported compiler and runtime.

## Implementation phases

### 1. Pure conversion logic

- [ ] Define a small unit representation for Celsius, Fahrenheit, and Kelvin.
- [ ] Implement conversion through Celsius in `TemperatureMath.bas` using
  named procedures and explicit types.
- [ ] Reject non-finite values and source values below absolute zero, accounting
  for a documented floating-point tolerance at the boundary.
- [ ] Keep parsing, formatting, and UI state out of the conversion procedures.

### 2. Designed form

- [ ] Build `ConverterForm` with the visual designer and check in its textual
  designer metadata.
- [ ] Give controls meaningful names, labels, tab order, default/cancel behavior,
  and accessible descriptions.
- [ ] Parse only when Convert is invoked; on failure, show a concise inline
  message, retain the input, and return focus to it.
- [ ] Format successful output with a documented, locale-independent precision
  so tests are deterministic.
- [ ] Make Reset restore the initial state without recreating the form.

### 3. Verification and teaching material

- [ ] Unit-test identity conversions, freezing/boiling points, cross-unit
  conversions, absolute-zero boundaries, large finite values, and rounding.
- [ ] Test empty, whitespace, malformed, overflow, `NaN`, and infinity-like
  input according to the parsing contract.
- [ ] Add an IDE smoke test that opens the project and validates form metadata;
  add UI automation only when the repository has a stable native UI harness.
- [ ] Document formulas, event flow, build/run steps, and extension exercises.
- [ ] Review module, procedure, and non-obvious validation comments against
  `../../COMMENTS.md`.

## Acceptance criteria

- [ ] All six directional conversions and same-unit conversion work.
- [ ] Invalid input and unavailable UI facilities produce controlled feedback.
- [ ] Repeated conversion does not leak resources or accumulate rounding state.
- [ ] The sample is entirely native and uses no third-party package.

## Non-goals

Unit-system localization, scientific-unit libraries, charts, and saved history
are intentionally deferred.
