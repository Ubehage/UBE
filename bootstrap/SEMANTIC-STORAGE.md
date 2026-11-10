# UBE intrinsic authority and finite storage facts

Status: native semantic acceptance and allocation/depth gates pass at O0/O2;
exact evidence is in compiler/Progress.md. This implements the planned
dependency in compiler/Roadmap.md after expression binding, not a new compiler
generation or an expansion of the language's current bootstrap profile.

## Distinct checks over retained source

`PrimitiveRoles.TryBindPrimitives` validates intrinsic declarations and returns
one role code per syntax node. Only validated procedure declaration nodes carry
a nonzero role. The source spelling of an ordinary procedure never confers
authority. Call lowering must subsequently follow the resolved declaration
identity; the role is not an alternative name lookup mechanism.

`AggregateLayout.TryLayout` computes one `StorageFact` per syntax node, with
`ElementCells`, `StorageCells` and `FieldOffset` as Long fields. It validates
expressions and declarations before computing layout. Primitive authority and
layout success are independent: callers must require both checks before treating
a program as ready for lowering. Neither pass emits native code.

Both public entries take the existing immutable source bytes, tokens, nodes,
modules, counts, package-name bytes and executable/library choice. They rebuild
their prerequisite facts internally rather than accepting caller-forged trusted
roles or symbol identities. Result arrays are caller-owned, assembled privately
and replaced only after full success. False publishes zero result count and a
diagnostic while preserving the old array. Unexpected runtime FAIL uses a
direct bounded diagnostic fallback without calling another failing helper.
No mutable process-global state is introduced.

## Intrinsic admission

The existing host validation in SourceSemantics and the UBECore primitive
contracts remain authoritative. Intrinsic functions require exactly one
`UBE_Primitive` attribute targeting their own declaration and no implemented
body. Ordinary procedures cannot carry that attribute. Intrinsic Main is
rejected for executable projects. Role spelling is decoded and case-insensitive;
unknown roles, incorrect return types, parameter counts, passing modes, nominal
types or shapes are rejected before a role is published.

| Code | Role | Result | Parameters in order |
|---|---|---|---|
| 1 | Array.Length | Long | ByRef T() |
| 2 | Memory.CopyBytes | Boolean | ByRef Byte(), ByVal Long, ByRef Byte(), ByVal Long, ByVal Long |
| 3 | Array.TryResize | Boolean | ByRef T(), ByVal Long, ByVal Boolean |
| 4 | Array.TryCopy | Boolean | ByRef T(), ByRef T() with identical nominal element type |
| 5 | File.TryOpen | Boolean | ByRef Byte(), ByVal Long, ByRef Long, ByRef Long, ByRef Long |
| 6 | File.TryCreateNew | Boolean | ByRef Byte(), ByRef Long, ByRef Long |
| 7 | File.TryRead | Boolean | ByVal Long, ByRef Byte(), ByVal Long, ByVal Long, ByRef Long, ByRef Long |
| 8 | File.TryWrite | Boolean | ByVal Long, ByRef Byte(), ByVal Long, ByVal Long, ByRef Long, ByRef Long |
| 9 | File.TryClose | Boolean | ByRef Long, ByRef Long |
| 10 | File.TryFlush | Boolean | ByVal Long, ByRef Long |
| 11 | Error.Set | Boolean | ByVal Long |

These are compiler implementation codes, not source keywords or a serialized
public ABI. Array parameters must have the exact dynamic rank-only shape. T
means an admitted scalar or nominal element type; a recursive nominal identity
does not bypass the separate finite-layout check. Existing conservative
expression bounds invalidation remains safe and is not weakened by this pass.
Array.TryResize and Array.TryCopy can replace array shape. File and byte-copy
roles can alter contents or external state but do not grant array replacement
semantics. Validating these identities does not remove runtime bounds checks.

Primitive diagnostics inherit declaration failures unchanged. This pass adds
Code 3 with Reasons 1 ordinary attribute, 2 attribute count, 3 target mismatch,
4 implemented/missing/duplicate body, 5 signature and 6 nominal TryCopy mismatch;
Code 8 Reason 1 for an unknown role; and Code 9 Reason 1 for invalid attribute
token metadata or misplaced primitive metadata. Runtime failure is Code 7
Reason 1. Locations identify the
offending declaration or attribute in its original source module.

## Finite storage admission

The private bootstrap representation uses one i64 cell per admitted scalar,
regardless of its language width. Records flatten fields in declaration order,
retaining nominal type identity; equal size does not imply type compatibility.
Self/cross-referencing nominal types remain valid declaration graphs, but cycles
cannot receive finite inline layouts in this profile. Reject them explicitly,
including unused declarations, as the existing host does. Limits remain 128
flattened cells per record and 64 recursive layout visits.

Arrays retain their checked bounds from expression binding. A fixed owner uses
four descriptor cells plus element count times element stride; a dynamic owner
uses four cells. Rank-only ByRef array parameters describe borrowed storage and
have zero owned payload cells. Bounds arithmetic must be checked before host
integer conversion or multiplication. Array fields, aggregate ByVal parameters,
aggregate results and managed representations remain outside this profile.
The module-storage limit remains 65,536 cells across the execution context.
Procedure frame slots, alias retention slots, expression temporaries and native
copy planning belong to later lowering, not these logical storage sizes.

Layout projects declaration/field sizes and expression element sizes into its
node result; indexed expressions describe one element, not the array descriptor.
Field offsets are relative to their immediate containing record. Non-value
nodes have zero size. Functions and synthetic scalar results describe one cell;
these are not final native frame allocations. Layout diagnostics add Code 8
Reason 40 for recursive storage, Code 6 Reasons 41 depth, 42 record cells,
43 module cells and 45 invalid fixed-size arithmetic, and Code 3 Reason 44 for
an empty record. Code 9 Reason 46 rejects invalid array shape tags or a fixed
shape on an array parameter before layout. Runtime failure is Code 7 Reason 1;
prerequisite failures retain
their existing codes and locations.

## Required evidence

The native gate must run actual compiler/library input at O0/O2, assert every
role signature family and precise field/array sizes, and reject forged source
attributes, wrong targets/bodies/signatures, nominal mismatches, cycles and
storage limits. Include exact boundaries, independent requests, malformed pools,
source-local diagnostics and old-result preservation. Changed source input must
invalidate an unchanged assertion. Production-only assembly must not depend on
test-only stack support.

The allocation companion must measure each pass's complete successful path,
fail every observed allocation site including retry, preserve all output fields,
retry successfully and return live storage to zero on disposal. Native depth
refusal must remain controlled. Re-run the relevant expression, declaration and
parser/scanner regression gates after final production changes. Record commands,
artifacts, limitations and the next handoff in compiler/Progress.md; do not claim
completion from a successful build alone.
