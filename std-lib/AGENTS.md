# UBECore contributor instructions

This is the active standard-library project. Read `README.md`, `DESIGN.md`,
and `ROADMAP.md` before changing it. Language behavior comes from
`../lang-doc/language-spec.md`, its focused contracts, and the normative grammar.

- Start from the owner's fresh-library decision recorded in `ROADMAP.md`.
  Do not copy the archived library or v3/v4 support implementations into this
  project. Reusing a historical algorithm requires a focused review and new
  tests against the approved contract.
- Write ordinary implementation in UBE. Keep irreducible platform primitives
  explicit and documented; a bootstrap exception needs a removal condition.
- Keep the project manifest, module names, declarations, tests, and public
  documentation consistent. Add modules only for an actual implemented need.
- Use functional module names. Compiler parsing, diagnostics, semantic policy,
  IR, and backend policy do not belong in UBECore.
- Keep portable code under `src/portable/`. OS-specific constants, declarations,
  and adapters belong in separate platform libraries under `src/win-lib/`,
  `src/linux-lib/`, or `src/mac-lib/` when needed.
- Document each reusable declaration's inputs, result, failure behavior,
  ownership, copying, lifetime, and thread-safety contract near its definition.
- Give mutable state an explicit owner. Shared inputs must be immutable or
  protected by a documented synchronization contract. Thread safety does not
  mean serializing every operation through a global lock.
- Return controlled failures and preserve existing values when the contract
  requires it. Every crash fix needs a small synthetic regression.
- Verify behavior with independently specified expected results. Old compiler
  output, successful compilation, and self-hosting alone are insufficient.
- Measure actual work, allocations, copied bytes, and memory where relevant.
  Do not manufacture work counters from input size and call that scaling proof.
- Explicitly release external resources on success, failure, and cancellation.
- Keep generated artifacts below `../bootstrap/out/`. Do not add dependencies
  or change frozen language behavior without the owner's explicit approval.
- Update `ROADMAP.md` with evidence, limitations, and the exact next action.
