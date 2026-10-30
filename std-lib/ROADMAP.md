# UBECore workplan

## Owner decision — 2026-10-30

Build a fresh UBECore in `std-lib/`, growing with the compiler's needs.
Preserve the existing library as an archive rather than building on its
implementation. This is the active library direction; prior compiler and
library checklists are retained as history.

The owner approved the early native-datatype proof and bounded stage-zero/v2
bootstrap investigation, and assigned the fresh compiler the v3 name.
Its design and workplan are under `../compiler/UBE_Compiler_v3/`; previous
v3/v4 sources, previews and handoffs are under `../compiler/archived/`.

## Current position

- [x] Archive all 28 previous library files without changing their bytes.
  The archive snapshot records SHA-256 values, sizes, and directories.
- [x] Establish a fresh `UBECore.UBE` project with an empty identity module,
  contributor guidance, and a separate design/workplan.
- [x] Inventory the finished VB6/VBA7 runtime surface and UBE-defined additions,
  including datatypes, callables, objects/constants, compiler/substrate
  boundaries, and unresolved compatibility decisions. The owner requested
  this inventory and explicitly included VBA7 on 2026-10-30; see `INVENTORY.md`.
- [ ] Select the smallest suitable bootstrap tool and language subset; prove
  its required behavior with small independent native programs.
- [ ] Define the primitive/type-mechanism ledger and prove one small library-
  defined native datatype before substantial higher-level type implementation.
- [ ] Define the first byte/text storage and construction contracts, including
  failures, ownership, Unicode boundaries, and sharing behavior.
- [ ] Implement that first facility in UBE and a library-only test runner.
- [ ] Establish meaningful work/allocation/copy/memory measurements and
  appropriate concurrent-instance tests before compiler use.

## Subsequent needs

Add collections, lookup/hashing, sorting, file/path facilities, platform
adapters, and concurrency facilities only as concrete consumers require them.
Their order, APIs, and representations have not been approved by this setup.
Do not resume compiler feature expansion by duplicating missing library code.

## Evidence and limits

The archive move was checked against a snapshot taken immediately before it:
all 28 file counts, sizes, SHA-256 values, and directory paths matched.
`archive/source-library.snapshot.json` retains that snapshot.

The setup acceptance procedure checks the archive against the snapshot, resolves
every archived/new manifest Source entry, checks historical script paths and
PowerShell syntax, checks the empty new API boundary, and checks diff hygiene.
It does not establish language, library, bootstrap, or native execution support.
The new project has not been compiled or executed.

Setup verification command:
`rtk proxy powershell -NoProfile -File bootstrap/out/verify-library-layout.ps1`.
It passed: 28 archived file hashes/sizes, the exact directory set, four
manifests with 20 source paths, four parsed PowerShell scripts, eight historical
script input paths, the historical JSON dependency path, and zero public
declarations in the fresh project. Generated results are recorded in
`bootstrap/out/library-layout-verification.json`. These are setup artifacts,
not a library build gate. `rtk proxy git -c core.safecrlf=false diff --check`
also passed for tracked changes.

## Exact next action

Use `INVENTORY.md` to choose the first byte/text storage and construction
capabilities and identify their required primitives/type mechanisms with the
fresh compiler's workplan. Choose and test the
bootstrap tool/subset for those operations, then record the first API contract
and independent acceptance cases before writing implementation code.

## Inventory handoff — 2026-10-30

The owner requested a finished-library overview covering the VB6 runtime and
UBE additions, and explicitly included VBA7. `INVENTORY.md` links four detailed
catalogs with 710 rows. These include named APIs and types, grouped constants
and component members, unnamed capabilities, and historical private hooks.
Counts are not unique public-function counts. The archive was read only as a
documentary source; no implementation was imported or changed.

`rtk proxy powershell -NoProfile -File std-lib/tools/check-inventory.ps1`
passed: 175 function/alias baseline names, 73 historical intrinsic names,
five document structures, duplicate-key checks, 52 local link targets, reference
definitions, and whitespace. Microsoft primary sources establish VB6/VBA
lineage; local normative sources govern UBE behavior. Cross-review corrected
ownership/signature descriptions and added previously missing named coverage.

Exact public signatures, constant values, per-class UI/member matrices,
LongPtr/PtrSafe compatibility, Variant missing/error states, and other recorded
compatibility decisions remain open. The inventory is a planning baseline;
it does not freeze or implement those APIs. Nothing was compiled or executed.

## Compiler archive handoff — 2026-10-30

Historical references in the inventory and its checker now select
`compiler/archived/UBE_Compiler_v3/` and `UBE_Compiler_v4/`. The archive integrity
gate also checks the previous 28 library files against their original snapshot.
The previously recorded setup runner under bootstrap/out describes the former
layout; use the maintained archive gate for the current compiler paths:
`rtk proxy powershell -NoProfile -File compiler/archived/verify.ps1`.
The inventory gate remains `std-lib/tools/check-inventory.ps1`.
