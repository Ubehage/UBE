# Hello, UBE! roadplan

Status markers: `[ ]` pending, `[~]` active, `[x]` verified, `[!]` blocked.

## Outcome

Create the only console sample in this collection: a small, welcoming program
that introduces comments, `Sub Main`, explicitly typed variables, strings,
console output, and simple arithmetic without hiding behavior behind helpers.

## Project shape

```text
01-hello-ube/
|- HelloUBE.UBE
|- src/Main.bas
|- tests/smoke.ps1
`- README.md
```

The finished program prints a greeting, shows a named string variable, computes
one clearly explained arithmetic result, and exits successfully without input.

## Capability gates

- [x] The supported compiler accepts the project manifest, native module header,
  `Sub Main`, strings, `Long` arithmetic, and console output.
- [x] Use the documented language-level `Print` statement for console output;
  do not wait for a future `UBECore` console API or call compiler-private
  runtime symbols.
- [ ] The build and smoke-test commands work from a clean checkout.

## Implementation phases

### 1. Skeleton

- [x] Create `HelloUBE.UBE` as an executable project with `Startup = "Main"`.
- [x] Create `src/Main.bas` with the native source header and module comment.
- [x] Keep all executable teaching code in `Main`; introduce no unnecessary
  abstraction in the first sample.

### 2. Teaching sequence

- [x] Add a comment explaining that apostrophe-prefixed text is not executed.
- [x] Print the product name and a short welcome message.
- [x] Declare and assign an explicitly typed `String` variable, then print it.
- [x] Declare two explicitly typed `Long` values, add them, and print the
  expression and result with deterministic formatting.
- [x] End naturally with exit code zero and no pause-for-key dependency.

### 3. Documentation and verification

- [x] Write a short README explaining every demonstrated construct and the
  exact IDE and command-line run steps.
- [x] Add a deterministic smoke test that builds, runs, checks the complete
  normalized output, checks exit code zero, and enforces a timeout.
- [x] Test execution from a path containing spaces and non-ASCII characters.
- [x] Review all comments against `../../COMMENTS.md`.

## Acceptance criteria

- [x] A new user can open, build, and run the project without editing it.
- [x] Output is stable across supported targets apart from documented newline
  conventions.
- [ ] Build or launch failure produces an actionable diagnostic, never a crash.
- [x] The sample uses no third-party package or undocumented runtime entry point.

## Non-goals

No input, window, file I/O, localization framework, or advanced formatting is
introduced here; later samples teach those concepts.
