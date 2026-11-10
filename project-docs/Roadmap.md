# UBE development roadmap

The long-term scope is a complete, self-hosting compiler, linked program
support, standard library, debugger and native IDE. The owner authorized the
restart sequence in [Development-Plan.md](Development-Plan.md) on 2026-11-10.
Compiler acceptance and resume state live in `../compiler/Roadmap.md` and
`../compiler/Progress.md`; no removed implementation inherits a passing status.

The roadmap is ordered by dependency. Later phases may be prototyped early,
but a phase is complete only when its exit criteria are satisfied.

## How to maintain this roadmap

Use these markers consistently:

- `[ ]` Not started
- `[~]` In progress
- `[x]` Complete and verified
- `[!]` Blocked; add a short explanation and link to the relevant issue or
  design note

Agents and contributors should update this file in the same change that
completes or materially changes an item. Keep completed items in place so the
file remains a useful history of the project's progress. Split an item when
only part of it is complete. Do not mark an item complete merely because an
initial implementation exists: its tests, diagnostics, and documentation must
also meet the stated exit criteria.

When a decision changes the language or architecture, update the normative
documents first or in the same change:

- [`../lang-doc/language-spec.md`](../lang-doc/language-spec.md) for lexical and semantic behavior
- [`../lang-doc/grammar/ube.ebnf`](../lang-doc/grammar/ube.ebnf) for syntax
- [`Development-Plan.md`](Development-Plan.md) and the compiler acceptance plan
  for the restart's compiler/bootstrap boundaries
- [`../lang-doc/project-files.md`](../lang-doc/project-files.md) for project, project-group, source-list,
  and binary-resource container behavior
