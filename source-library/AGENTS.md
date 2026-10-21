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
- `OS-specifics.md` for instructions on OS-specific code.

## Rules
Reference `agent-rules.md` for detailed rules on contributing to the source library.



Public API behavior must be reflected in `../docs/` only after its declaration
and semantics are frozen. Never label an API implemented without executable
evidence.
