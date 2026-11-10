# Counted byte-buffer operations

This dependency increment implements the existing `Array.Length` and
`Memory.CopyBytes` contracts from language-spec.md section 8 through validated
Intrinsic declarations. It uses the fixed rank-one arrays already admitted by
AGGREGATES.md and introduces no allocator or external target dependency.

## Binding

An Intrinsic Function has a header, one matching
`Attribute ProcedureName.UBE_Primitive = "Role"` line, and its matching End
Function. It has no executable body. The parser retains the attribute's source
span, target identifier and decoded role. The binder checks the target, role,
result and every parameter before publishing the binding. Names are matched
case-insensitively; the role is attached to the declaration identity rather
than inferred from its spelling. Ordinary functions with the same name retain
ordinary behavior. Metadata on an ordinary procedure, missing/duplicate
metadata, mismatched targets and signatures are rejected. Unsupported roles
receive explicit diagnostics.

| Role | Required signature |
|---|---|
| Array.Length | Function(ByRef Values() As T) As Long |
| Memory.CopyBytes | Function(ByRef Source() As Byte, ByVal SourceStart As Long, ByRef Destination() As Byte, ByVal DestinationStart As Long, ByVal Count As Long) As Boolean |

Here T is one concrete admitted scalar or finite record type; there is no
generic source syntax. Intrinsic declarations can be renamed or qualified
normally. An executable entry cannot be intrinsic. Library declarations named
Main carry no entry role and follow ordinary declaration rules.

## Execution

Length reads the actual descriptor and returns its element count, independently
of lower bounds and element cell width. CopyBytes interprets starts and counts
as logical byte offsets from each array's first stored element. The current
private representation uses one i64 cell per Byte value; it does not confuse
logical byte offsets with physical byte offsets into those cells.

CopyBytes validates the complete source and destination spans before writing.
Negative Count returns False with Err 5. Invalid starts or spans return False
with Err 9. Zero count accepts an offset at the array's end. Overlapping copies
move the original input correctly in either direction. The operation allocates
nothing, preserves both descriptors, and leaves the destination unchanged on
failure. Success returns True and preserves the incoming Err value.

False is a usable Boolean result under the explicitly record-only primitive
contract. It does not transfer to an On Error handler or abandon the containing
statement. Argument evaluation/conversion failures retain their ordinary
language FAIL behavior. Native primitive wrappers return fresh success with
their Boolean result; sticky Err never determines that success flag.

UBECore contains the concrete Byte primitive declarations and an ordinary
AppendBytes function. AppendBytes validates the used-length/capacity, invokes
CopyBytes and publishes the new used length only after success. It raises a
language error when the append cannot complete, demonstrating the explicit
boundary between primitive status and caller-visible FAIL. This policy belongs
in UBE source, not in the compiler's primitive implementation.

## Scope and acceptance

The counted-buffers gate executes actual UBECore source with renamed primitive
declarations, ordinary-name counterexamples, varied bounds, overlap, invalid
spans, sticky Err, error handlers and append publication at O0/O2. Exact results
and commands belong in compiler/Progress.md. Earlier bootstrap gates remain
required regressions.

The full roles also define neutral empty arrays; constructing those values is
outside the current fixed-array profile. Runtime-typed invalid element storage
is likewise outside this statically typed Byte boundary. Dynamic arrays,
ReDim/Erase, allocation recovery, managed roots, file I/O, broader intrinsic
roles and public native layouts remain separate unimplemented dependencies.
This allocation-free increment makes no allocation-failure or collection claim.
