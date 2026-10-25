# Conway's Game of Life roadplan

Status markers: `[ ]` pending, `[~]` active, `[x]` verified, `[!]` blocked.

## Outcome

Create a native windowed Conway's Game of Life simulation demonstrating
two-dimensional grids, arrays, algorithms, state transitions, timers, and
custom visual rendering. The original terminal-rendering idea is adapted to a
designer-hosted grid because all samples except the first are windowed.

## User experience

The form displays a finite cell grid that can be toggled while paused. Start,
Pause, Single Step, Clear, Randomize, and speed controls expose the simulation
state. Generation and live-cell counts update after each committed step. The
window remains responsive, and closing it always stops pending timer work.

## Project shape

```text
09-game-of-life/
|- GameOfLife.UBE
|- src/Main.bas
|- src/LifeForm.frm
|- src/LifeGrid.bas
|- src/LifeRenderer.bas
|- tests/LifeGridTests.bas
`- README.md
```

## Contracts to decide before coding

- [ ] Choose fixed-dead or wrapping edges and document the decision visibly.
- [ ] Set minimum/maximum grid dimensions, timer interval limits, random-fill
  density, and memory bounds.
- [ ] Define resize behavior: preserve, clear, or recreate the grid explicitly.

## Capability gates

- [ ] The language/runtime supports bounded two-dimensional arrays or a safe
  documented one-dimensional backing representation.
- [ ] Native UI support provides a designer-hosted drawing surface, pointer and
  keyboard events, invalidation/paint callbacks, and a UI-thread timer.
- [ ] Random generation is available through a documented library adapter.

## Implementation phases

### 1. Pure simulation model

- [ ] Store current and next generations separately so evaluation order cannot
  change results.
- [ ] Implement bounded neighbor counting and the standard birth/survival rules.
- [ ] Swap/commit generations only after a complete successful step.
- [ ] Expose safe operations for query, toggle, clear, randomize, and count.
- [ ] Check dimensions, indices, generation counter, and allocation failures.

### 2. Renderer and designed form

- [ ] Build the controls and drawing host in the visual designer with resize,
  focus, keyboard access, and accessible action names.
- [ ] Render only from a stable model snapshot during paint callbacks.
- [ ] Convert pointer coordinates to cells with checked bounds and ignore clicks
  outside the grid.
- [ ] Drive stepping from a UI timer without reentrant steps; Pause must prevent
  any later queued tick from mutating state.
- [ ] Stop and detach timer/callback state before form destruction.

### 3. Tests and documentation

- [ ] Unit-test underpopulation, survival, overpopulation, birth, edge policy,
  empty grids, still lifes, oscillators, and a glider where applicable.
- [ ] Test invalid dimensions/coordinates, maximum grid, counter range failure,
  allocation failure, repeated start/pause, and close-during-tick behavior.
- [ ] Keep core tests timer-free and deterministic by calling a single-step API.
- [ ] Document rules, double buffering, edge policy, state machine, performance
  limits, and build/run steps; review comments against `../../COMMENTS.md`.

## Acceptance criteria

- [ ] Known patterns evolve exactly and deterministically.
- [ ] Painting never mutates the model and stepping never depends on paint rate.
- [ ] UI actions remain responsive at maximum documented size and speed.
- [ ] No timer or callback accesses state after the form closes.

## Non-goals

Infinite universes, pattern-file formats, GPU rendering, multithreaded stepping,
and a full cellular-automata editor are excluded.
