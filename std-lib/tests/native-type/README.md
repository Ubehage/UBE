# Native datatype proof inputs

The adopted opaque mechanism is in [NATIVE-TYPE-PROPOSAL.md](../../NATIVE-TYPE-PROPOSAL.md).
`baseline/` contains existing-language field-only records and ordinary procedures.
`proposed/` retains its original folder name and now contains the adopted native
acceptance corpus: ten native variants and 36 controlled rejection variants.
These test inputs are not included in `UBECore.UBE` and do not select a public API.

Expected native values, size/alignment and rejection diagnostics are specified
in `baseline/cases.json` before execution. Tests cover default zero, copies,
ByVal/ByRef, a record-valued result, shared declarations across two modules,
explicit fresh Boolean status with failed update preserving storage, and an
existing Err that remains unchanged. Different same-layout record types must
not assign or alias through ByRef. A second project renames the record and all
helper procedures to test that their spellings are immaterial.

The checker compares raw LLVM between the accepted v2 stages, then appends
test-only LLVM size/alignment queries to a separate copy. Those queries inspect
the compiler-defined record type through target GEP layout. The copy also
renames the generated entry wrapper so the C test entry can delegate to that
complete wrapper with Err seeded/checked immediately around it. Production
source/IR and all UBE procedures/runtime operations remain unchanged.

Run from the repository root:
`rtk proxy powershell -NoProfile -File std-lib/tools/check-value-record.ps1`.
This baseline cannot prove payload opacity, explicit representation metadata,
pack/unpack binding, native-type equality, managed lifecycle or the proposed
new grammar. A public record field remains directly accessible by design.

The native mechanism has a separate checker:
`rtk proxy powershell -NoProfile -File std-lib/tools/check-native-type.ps1`.
It tests Byte/Integer/Long representation, opacity, nominal identity, value
copy/call/result behavior, equality, explicit case-insensitive metadata,
declaring-module ownership, single evaluation and precise rejection. The
maintained `bootstrap/build-v2.ps1` gate runs both checkers before publishing
the accepted compiler selection. See [current evidence](NATIVE-EVIDENCE.md).
