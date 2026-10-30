# Preserved UBE sources

`source-library/` is the previous UBECore library, archived at the owner's
request on 2026-10-30. Its complete working-tree contents were moved intact,
including uncommitted changes, tests, manifests, and contributor instructions.
`source-library.snapshot.json` records every preserved file's size and SHA-256.

The active standard-library project is [`../std-lib/`](../std-lib/README.md).
The archived implementation is historical material, not its implementation
base or an automatically accepted API contract.

Historical compiler build and test scripts explicitly use this archive.
Their use does not select the new standard library. Source-relative entries
inside the archived `.UBE` manifests retain their original structure.

Archived documents and instructions retain their original wording and status
claims. Their repository-relative links were written for the original
`source-library/` location; interpret those historical links from that location.
They do not set the active development direction. See the root
[`Workplan.md`](../Workplan.md) and [`std-lib/ROADMAP.md`](../std-lib/ROADMAP.md).
