# Archived compiler implementations

The owner archived the previous v3 and v4 implementations on 2026-10-30 and
assigned `compiler/UBE_Compiler_v3/` to the fresh, library-first compiler.
This directory is the owner-requested archive location.

| Preserved material | Location |
|---|---|
| Previous v3 source, manifests, tests and plans | `UBE_Compiler_v3/` |
| Previous v4 source, support package, prototypes, tests and plans | `UBE_Compiler_v4/` |
| Previous v3 release previews and their hash ledger | `release-previews/` |
| Previous compiler-level README, roadmap and progress | `compiler-history/` |

`originals.zip` retains the exact pre-archive working-tree bytes of all 367
files, including uncommitted work and contributor instructions. Its entries use
the original repository paths. `snapshot.json` records original and archived
SHA-256 values, directories, and each relocation-only text replacement.
Thirteen archived scripts, test expectations and dependency metadata files
needed path/depth adjustments. All other archived file bytes are unchanged.
No source-language implementation was modified by this relocation.

Run `rtk proxy powershell -NoProfile -File compiler/archived/verify.ps1`
from the repository root to check exact originals, archived bytes, allowed
relocation edits, project source entries, script syntax, and preview hashes.
This is a structural/integrity check, not a compiler build or runtime gate.

Historical plans, generation numbers and completion claims describe these
archived implementations. They do not define the new v3's architecture or
status. Original documentation retains its original relative-link context;
interpret it using the original paths recorded in the snapshot. Current
library inventory links point to the actual archived source files.

`bootstrap/build.ps1` and the historical benchmark/package/IDE/sample test
entry points now select archived source or preview paths explicitly. Their
existing output names remain historical; none is an output of the fresh v3.
The full historical build/runtime gates have not been rerun for the move.

## Relocation acceptance — 2026-10-30

`rtk proxy powershell -NoProfile -File compiler/archived/verify.ps1` passed:
367 original snapshot files and archived hashes, 13 exactly reproducible
relocation-only changes, 354 unchanged archived files, nine preview hashes,
the previous library's 28 files, six production/library manifests with 132
resolved inputs, and syntax/root-path checks for 21 PowerShell scripts.
The fresh compiler contains only its five design/workplan documents.

`rtk proxy powershell -NoProfile -File std-lib/tools/check-inventory.ps1`
also passed its 175 reference-name, 73 historical-hook and document/link gates.
Neither procedure builds or executes a compiler or generated UBE program.
