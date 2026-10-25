# Guess the Number roadplan

Status markers: `[ ]` pending, `[~]` active, `[x]` verified, `[!]` blocked.

## Outcome

Create a native windowed guessing game that demonstrates random numbers, loops,
conditions, counters, explicit state transitions, and friendly validation.

## User experience

The form starts a game with a secret integer in a documented inclusive range.
The player enters guesses and receives Too low, Too high, or Correct feedback,
plus an attempt count. New Game resets all state. Input is disabled after a win
until a new game begins, and the UI never reveals the secret accidentally.

## Project shape

```text
04-guess-the-number/
|- GuessTheNumber.UBE
|- src/Main.bas
|- src/GuessForm.frm
|- src/GuessGame.bas
|- tests/GuessGameTests.bas
`- README.md
```

## Capability gates

- [ ] The designer/runtime supports native form controls, button/key events,
  enabled state, focus, and accessible status updates.
- [ ] `UBECore` provides a documented random-number generator and an explicit
  seeding or injectable-source contract suitable for deterministic tests.
- [ ] Numeric parsing and checked counter arithmetic are available.

## Implementation phases

### 1. Deterministic game model

- [ ] Represent lower bound, upper bound, secret, attempt count, and completion
  state explicitly.
- [ ] Separate secret generation from guess evaluation so tests can inject known
  secrets without weakening production randomness.
- [ ] Implement guess evaluation with exhaustive conditions and a result value
  for low, high, correct, and invalid-state outcomes.
- [ ] Define safe behavior if random generation fails or returns an out-of-range
  value; never continue with uninitialized state.

### 2. Designed form

- [ ] Create the form with the visual designer, including instructions, input,
  Guess and New Game buttons, feedback, and attempt count.
- [ ] Accept guesses only inside the inclusive range and do not increment the
  count for syntactically invalid or out-of-range input.
- [ ] Preserve input and focus on validation failure; select it after a valid
  non-winning guess for quick retry.
- [ ] Make Enter trigger Guess and keep New Game safe at every point.

### 3. Tests and documentation

- [ ] Unit-test boundary secrets, repeated guesses, first-try wins, low/high
  transitions, attempt counting, reset, and calls after completion.
- [ ] Test malformed, empty, overflowing, and out-of-range input.
- [ ] Add a bounded statistical test for the random adapter only if it can be
  stable across supported targets; never make distribution timing-dependent.
- [ ] Document conditions, the game loop as event-driven state transitions,
  random-number bounds, and deterministic testing.
- [ ] Review comments against `../../COMMENTS.md`.

## Acceptance criteria

- [ ] Every new game chooses a valid secret or reports a controlled failure.
- [ ] Attempt counts and feedback are correct for every transition.
- [ ] The game remains responsive and resource-stable over many resets.
- [ ] Tests require no live window and use no nondeterministic assertions.

## Non-goals

Scores, persistence, network play, animations, and cryptographic randomness are
not part of this teaching sample.
