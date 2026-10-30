# UBE Compiler v3

This is the fresh compiler line designated by the owner on 2026-10-30. The
previous v3 and v4 implementations are preserved under
[`../archived/`](../archived/README.md). Their code, phase interfaces, version
claims and release-preview identities are not inherited by this project.

The compiler and [`UBECore`](../../std-lib/README.md) are developed together
from tested foundations, with reusable functionality implemented in UBECore.
The compiler owns language enforcement and a small machine/storage primitive
boundary. Higher-level datatype behavior belongs in library source wherever
practical. The datatype-definition mechanism must be demonstrated early.

## Current state

This directory contains design, contributor guidance and resumable work only.
There is no production manifest, startup module or compiler executable yet.
The next work is a bounded bootstrap-feature proof and the first foundation
contract, not another broad compiler scaffold.

An existing stage-zero/v2 route may be used temporarily after its required
language subset passes independent small tests. This permission does not
approve existing implementations or transfer their assumptions into the new
architecture. A VB6 bootstrap port remains a deferred owner idea.

## Read next

- [`DESIGN.md`](DESIGN.md): approved direction and unresolved mechanisms.
- [`Roadmap.md`](Roadmap.md): ordered prerequisite checklist.
- [`Progress.md`](Progress.md): current handoff and evidence limits.
- [`AGENTS.md`](AGENTS.md): implementation boundaries.
- [`../../std-lib/INVENTORY.md`](../../std-lib/INVENTORY.md): target library scope.
