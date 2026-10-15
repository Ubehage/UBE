# UBE source-library contributor instructions

This directory contains the separately compiled UBE source library. The
compiler projects do not own this code and must not copy library modules into
their generation directories.

Before changing this directory, read:

- `README.md` for the public purpose and current status;
- `DESIGN.md` for dependency and portability boundaries;
- `ROADMAP.md` for the active resumable checklist;
- `../lang-doc/language-spec.md` for language behavior; and
- `../project-docs/architecture.md` for repository-wide boundaries.

## Rules

- The library must be built as a UBE project with a checked-in `.UBE` project
  manifest. Do not treat this directory as a loose collection of source files.
- Put every implementation in a meaningfully named module organized by
  functionality. For example, memory operations belong in a module such as
  `Memory.bas`; string operations, file operations, threading operations, and
  other areas use their own clearly named modules.
- Do not create catch-all modules such as `Misc.bas`, `Helpers.bas`, or
  `Utilities.bas`. If a module begins to cover unrelated responsibilities,
  split it by public function and ownership domain.
- Keep module filenames, `UBE_Name` attributes, manifest entries, tests, and
  public documentation terminology consistent.
- Document every Sub, Function, Property, Event, custom datatype, and other
  callable or reusable declaration with nearby source comments explaining its
  purpose, inputs, result or observable effect, failure behavior, and any
  ownership or thread-safety requirements that apply.
- Add brief comments to complex code paths explaining what the code is doing
  and, especially, why that approach is required. Document invariants,
  portability constraints, unusual conversions, cleanup paths, and behavior
  that would not be obvious from the statements alone.
- Keep comments accurate when code changes. Do not use comments that merely
  translate each statement into English, preserve dead code, or make claims
  that are not verified by the implementation and tests.
- Write library implementation in UBE. A temporary bootstrap implementation
  requires an explicit roadmap entry and removal condition.
- Keep portable source separate from target adapters.
- Do not place parser, semantic-analysis, diagnostic, or backend policy here.
- Do not expose compiler internals as public library APIs.
- Do not assume Windows behavior in portable modules.
- Do not add a third-party dependency without the owner's explicit approval.
- User-owned files, sockets, handles, and similar resources remain the user's
  responsibility; library APIs must document ownership and cleanup.
- Non-test code must never panic or crash on malformed input or environmental
  failure. Add a focused regression test for every crash fix.
- Keep `ROADMAP.md` updated whenever work changes state or introduces a
  resumable handoff.

Public API behavior must be reflected in `../docs/` only after its declaration
and semantics are frozen. Never label an API implemented without executable
evidence.
