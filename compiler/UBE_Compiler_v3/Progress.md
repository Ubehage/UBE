# UBE Compiler v3 progress

## Current objective

Establish the shared UBECore/compiler foundation contract and the bounded
bootstrap proof. The owner approved the library-defined native datatype and
stage-zero/v2 recommendations on 2026-10-30 and named this fresh compiler v3.

## Current state

Documentation only. No production manifest, compiler source, native datatype
mechanism, API implementation or compiler executable has been created.
`../archived/` holds the previous v3/v4 trees, release previews and compiler
handoff documents. Exact pre-archive working-tree bytes are retained separately
from recorded relocation-only script/metadata changes.

The fresh UBECore remains in `../../std-lib/`. Its inventory is documentary
scope with open API/compatibility decisions. The VB6 bootstrap-port idea stays
deferred. No old compiler's phase model or verification claim is inherited.

## Evidence and limits

The archive/setup gate checks original and relocated file hashes, allowed text
replacements, manifests, preview hashes and PowerShell syntax. The inventory
gate checks named coverage and document structure. These gates do not compile
the new compiler, establish bootstrap fitness or prove runtime behavior.

`rtk proxy powershell -NoProfile -File compiler/archived/verify.ps1` passed
367 original/archived file checks, 13 recorded relocation-only changes,
nine preview hashes, 28 library archive files, six manifests/132 inputs and
21 script syntax/root checks. `std-lib/tools/check-inventory.ps1` passed its
175 reference names and 73 historical hooks. No compiler/runtime gate ran.

## Next action

Define the minimum machine/storage/type mechanisms needed by the first UBECore
datatype and byte/text slice, then select independently specified bootstrap
fixtures from that ledger. Keep unresolved syntax/ABI choices explicit.
