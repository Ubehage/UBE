# UBE workplan

This is the repository-wide resumable checklist for active goals and handoffs.
Owner-defined release requirements live in `Release-Requirements.md`; long-term
sequencing lives in `project-docs/Roadmap.md`; module-specific work may use a
nearer roadmap or progress file.

## Status markers

- `[ ]` not started
- `[~]` in progress
- `[x]` complete and verified
- `[!]` blocked, with the reason and required decision recorded

## Current checkpoint

- [x] Preserve and verify the self-hosting UBE Compiler v2.
- [x] Add ordered multi-module compilation and cross-module resolution to v2.
- [x] Reorganize documentation into public, normative-language, and project
  documentation areas.
- [x] Complete and statically verify the public documentation snapshot for the
  frozen UBE 1.0 definition, with specified behavior separated from verified
  Compiler v2 behavior and unresolved public APIs represented by status pages.
- [x] Define and freeze the UBE 1.0 language contract for Compiler v3.
- [x] Create `compiler/UBE_Compiler_v3/` with its architecture, roadmap, and
  v2-buildable project scaffold.
- [x] Establish `source-library/` as the separate root for UBE library source,
  with preview, portability, ownership, and resumable-work boundaries.
- [~] Develop and compile v3 using the preserved v2 compiler.
  - [x] Preserve the explicit RP0 scaffold baseline.
  - [x] Complete RP1: bounded multi-module compiler shell, project/source
    validation, host/target descriptions, compatibility identities, and the
    API-empty `UBECore` project boundary.
  - [x] Complete RP2: native and compatibility source envelopes, frozen UBE
    1.0 tokenization, conditional compilation, stable source mapping,
    deterministic token output, bounded recovery, and malformed-input tests.
  - [ ] Begin RP3 with the bounded, owned syntax representation.

## Handoff protocol

For active work, record:

- the exact objective and authoritative specification;
- current status and completed checklist items;
- decisions and assumptions;
- files changed;
- verification commands and results;
- remaining failures or blockers;
- the exact next action.

Update this file when repository-wide work changes state. Do not duplicate a
detailed module checklist here; link to the module's roadmap or progress file.
