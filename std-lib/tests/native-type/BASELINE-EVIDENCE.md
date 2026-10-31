# Existing-record baseline evidence

Historical snapshot recorded 2026-10-30 before the owner delegated the decision.
This is the existing-language prerequisite, not the new opaque mechanism.
The shared test adapter/checker subsequently evolved; current baseline and
native-mechanism identities/results are in [NATIVE-EVIDENCE.md](NATIVE-EVIDENCE.md).

Command from the repository root:

```powershell
rtk proxy powershell -NoProfile -File std-lib/tools/check-value-record.ps1
```

Result: eight acceptance assertions passed. Both exact accepted v2 stages
compiled/ran the original two-module program and a version with the type and
all helper procedures renamed. Each program produced the independently
specified stdout/exit and empty stderr. Raw LLVM was byte-identical between
stages for each source variant. Two rejection pairs had identical diagnostics,
controlled exit 1 and no LLVM artifact.

| Obligation | Checked result |
|---|---|
| Layout | Compiler-defined one-Byte record has target size/alignment 1/1. |
| Neutral value | Default field is 0, including a record-array element. |
| Assignment and ByVal | Copy remains 255 when original and ByVal parameter change. |
| ByRef | Mutation updates caller to 128. |
| Returned record | Returned 7 copies independently; later mutation to 8 does not change the copy. |
| Fresh status | TrySet returns True/False/True/False for 255/-1/0/256; False preserves destination. |
| Existing Err | Err 77 survives the complete native program; status does not infer failure from stale Err. |
| Type identity | Same-layout unrelated records cannot assign or bind through ByRef. |
| Names | Renamed type/procedures satisfy the same independent oracles. |

The checker preserves each raw compiler output, then makes a separate test
copy that renames only the generated entry symbol and appends LLVM GEP queries
for size/alignment. A C entry adapter checks those query results, seeds Err 77,
delegates to the complete generated entry wrapper and checks Err immediately
after it returns. UBE procedure bodies, type definitions and runtime operations
are not replaced by the adapter. The recorded C source is test infrastructure,
not library implementation or an additional product dependency.

Detailed report:
`bootstrap/out/value-record/90c58bc61cd548018b5809c780a6ace0/report.json`.
SHA-256: `778EF299CA200F080143C87C1D1F6F133C343F01149AFA9004185EBDE107C132`.
It records exact test/checker/helper input identities, original/generated source
and IR/executable artifact hashes, selected compiler/runtime/tool identities,
commands, process outputs and results. The checker verified the accepted v2
build's entire input identity list before using it; no compiler/runtime source
or production manifest changed for this proof.

Accepted v2 build manifest SHA-256:
`6E53635AC2B1DE3376BB2216B9783AF1B0AC0DA651E94A87F165BA069B4D3CD1`.
Stage-two executable SHA-256:
`CDC9DF7153E015BBAD958DE60E5C2B6B55F4EC382CF8588DACBA557435494E77`.
The selected source-built tools are those qualified by
[the v2 acceptance gate](../../../compiler/UBE_Compiler_v2/FOUNDATION-VERIFICATION.md).

One bootstrap limitation encountered during preparation: assigning only a
function result's field does not satisfy v2's explicit whole-result assignment
check. The final MakeRecord builds a local record and assigns that complete
value to its result, staying inside the tested subset. No compiler repair or
new rule was introduced to make this test pass.

Unproved: opacity, representation declarations, explicit Pack/Unpack metadata,
native-value equality, module privacy, managed storage/lifecycle, failure-status
ABI for fallible primitives, concurrency and performance/allocation budgets.
The public record field is accessible; it is not an opaque native datatype.
The owner subsequently delegated the design decision. The adopted
[contract](../../NATIVE-TYPE-PROPOSAL.md) and current evidence record supersede
that pending-decision status. The limits above describe this record-only proof.
