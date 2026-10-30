# UBECore standard library

`std-lib/` is the fresh UBECore project, established by the owner on 2026-10-30.
The standard library will grow with concrete compiler needs and provide
reusable facilities for ordinary UBE programs.

The previous library is preserved separately in
[`archive/source-library/`](../archive/README.md). No implementation, intrinsic
declarations, or public APIs have been imported from it.

## Current state

[`UBECore.UBE`](UBECore.UBE) defines the project and includes one empty identity
module. There are no public APIs, runtime dependencies, or implementation
claims. This setup has structural checks only; a bootstrap compiler has not
been selected and the new project has not been compiled or executed.

The owner approved investigation of a bounded stage-zero/v2 bootstrap route
and an early proof of library-defined native datatypes. The collaborating
fresh compiler is [Compiler v3](../compiler/UBE_Compiler_v3/README.md); the
previous v3/v4 implementations are archived separately.

The historical `bootstrap/build.ps1` gate continues to select the archived
library. It does not build this project.

## Development

- [`INVENTORY.md`](INVENTORY.md): finished-library scope covering VB6, VBA7,
  UBE additions, and compiler-needed foundations, with ownership and open
  compatibility decisions separated from implementation claims.
- [`DESIGN.md`](DESIGN.md): ownership, compiler/library/platform boundaries,
  and evidence required before use.
- [`ROADMAP.md`](ROADMAP.md): current work and the next concrete deliverable.
- [`AGENTS.md`](AGENTS.md): contributor instructions.

The first implementation work starts by identifying the minimum bootstrap
tool and language subset, then defining byte/text storage and construction
contracts with independent executable tests. API design and implementation
remain pending.

The target inventory can be checked from the repository root with
`rtk proxy powershell -NoProfile -File std-lib/tools/check-inventory.ps1`.
This checks documentary coverage and links, not library behavior.
