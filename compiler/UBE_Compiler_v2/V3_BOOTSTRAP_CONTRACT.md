# V3 bootstrap contract

UBE Compiler v2 is the transitional compiler used to develop and compile the
initial UBE Compiler v3. V3 is the first public-release target; this document
defines the deliberately smaller source contract its first implementation may
use before v3 grows its own language support. The owner approved extending v2
as needed for bootstrap, including the managed-value prerequisites recorded
below; this is not an independent expansion toward a public v2 release.

## Project contract

- Input is one UTF-8 `UBE-Project 1` `.UBE` manifest of `Kind = "Exe"`.
- The manifest contains one or more ordered, project-relative `.bas` `Source`
  entries. Paths are normalized, may not escape the project directory, and may
  not repeat after case-folded normalization.
- All listed modules form one declaration universe. Source order is stable but
  does not restrict references: a procedure may call a later module, and a
  module may use a `Type` declared in another module.
- Exactly one supported `Sub Main()` or `Function Main() As Long` is required.
- `.UBG`, `.UBR`, classes, forms, controls, and project structures are reserved
  for v3 and are not part of the bootstrap link unit.

## Source contract

The initial v3 compiler may use the subset already exercised by v2's own
self-compilation and conformance corpus: procedures and functions, explicit
parameters and result types, `ByVal`/`ByRef`, `Byte`, `Integer`, `Long`, `Boolean`,
and bootstrap `String`,
compiler-defined `Type` records, one-dimensional dynamic arrays, member and
array access, `Dim`, assignment, explicit `Call`, `ReDim`/`ReDim Preserve`,
block `If`/`Else`, `While`/`Wend`, supported expressions, `Print`, and
contextual procedure/while exits.

The initial v3 source must not depend on classes, project structures,
`ParamArray`, `For`/`Next`, `ElseIf`, `Do`/`Loop`, `Select Case`, `With`, or
numeric conversion/ABI combinations not covered by the v2 conformance suite.
V2 diagnoses the reserved structured statements instead of silently ignoring
them. These features are implemented by v3 after the first v2-built v3
compiler can test and reproduce them.

## Proof required before changing this contract

The owner requested a usable current-source v2 on 2026-10-30. The required
Byte/Integer storage addition and its limits are specified in
`FOUNDATION-PLAN.md` and checked by `bootstrap/build-v2.ps1`; results are in
`FOUNDATION-VERIFICATION.md`. Byte is unsigned i8; Integer is signed i16.
Checked integer conversions apply at assignment, ByVal-call and result
boundaries; exact ByRef types remain mandatory. Byte arithmetic promotes to
Integer. The subsequent approved managed addition qualifies independent
Byte-array and array-containing record assignment, ByVal and results, including
nested roots, collection, scope cleanup and failure-atomic copying. Counts/
indices are signed Long and rank remains one in this bootstrap subset. Inline
recursive records diagnose; general objects, builtin String lifecycle and opaque
managed representations remain unqualified. Exact tests, binding signatures
and limits are in `../../std-lib/MANAGED-STORAGE-EVIDENCE.md`.

The private StringFromByte domain remains 1..255. Raw zero bytes belong in Byte
arrays. No public String/Byte API or native-type extension grammar is added by
this repair. The compiler's own source continues to use its original narrow
Long/Boolean/String subset, so stage zero need not gain unrelated features.

Every added v2 prerequisite needs parser, semantic, lowering/backend, malformed
input, and native execution coverage through both v2 stages. Every v3 bootstrap
build must continue to run the v2 fixed-point and v1 preservation suite. A
feature desired for public UBE belongs in v3 unless the owner-approved bootstrap
work requires it. This approval does not authorize a replacement architecture.

## Owner-authorized native scalar addition - 2026-10-30

Under delegated design authority, the next foundation goal adds opaque nominal
`Type Name As Byte|Integer|Long` values and explicit intrinsic Pack/Unpack
metadata. Qualified native layout, zero/copy, exact calls/results, equality,
declaring-module binding ownership and malformed-input rejection are covered
by 66 assertions through both v2 stages. Eight ordinary-record assertions
preserve the baseline; that scalar snapshot passed 204 checks.
The compiler's own source remains stage-zero compatible. This does not qualify
managed representations, general module privacy or foreign ABI. Adopted
contract and evidence: `../../std-lib/NATIVE-TYPE-PROPOSAL.md` and
`../../std-lib/tests/native-type/NATIVE-EVIDENCE.md`.

## Owner-approved managed storage addition - 2026-10-30

The recorded source gate passes 276 assertions: 136 core, 66 native scalar,
eight ordinary-record, six managed-substrate, 52 compiled managed-value and
eight UTF-8 decoder checks. Child reports bind an immutable source manifest
before the candidate becomes selected. This proves the bounded ordinary-array/
record behavior, not the complete language or a full Library manifest build.

Array.Length, Array.TryResize, Memory.Collect, Array.TryCopy and Memory.CopyBytes
use explicit UBE_Primitive attributes and validated concrete signatures.
Length/resize/copy use the exact declared array element type; CopyBytes is
restricted to Byte arrays and signed Long zero-based payload offsets/counts.
Try operations return fresh Boolean status independently of stale Err. No new
EBNF syntax, raw address API or arbitrary foreign binding is introduced.

## First fresh-v3 source consumer

The active next consumer requires bounded direct source Library references and
validated native MODULE envelopes, package/module identities and Main Startup.
The exact accepted/rejected subset is in `tests/source-reference/CONTRACT.md`;
this is not general package lookup or standalone shared-library output.

Five explicit roles add counted UTF-8 byte arguments/paths, recoverable raw
file open/read/close and error recording: File.TryOpen, File.TryRead,
File.TryClose, Process.TryArgument and Error.Set. Their signatures, resource
ownership, failure behavior and temporary platform adapter boundary are in
`../../std-lib/FILE-BYTES-CONTRACT.md`. Existing registered intrinsics and all
seven earlier role signatures retain their meanings. The fresh consumer's
source policy stays in `../UBE_Compiler_v3/SOURCE-INPUT-CONTRACT.md`.

Qualification now passes all 470 combined checks, including every earlier gate.
Native Main admission has a private wrapper-owned observer, so failure before
the source body produces a controlled nonzero process status without inspecting
stale Err. Ordinary Try admission still preserves ByRef outputs and returns a
neutral Boolean; callers initialize their failure fallback. Exact evidence and
current identities are in `../UBE_Compiler_v3/SOURCE-INPUT-EVIDENCE.md`.
