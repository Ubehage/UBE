# V3 bootstrap contract

UBE Compiler v2 is the preserved compiler used to develop and compile the
initial UBE Compiler v3. V3 is the first public-release target; this document
defines the deliberately smaller source contract its first implementation may
use before v3 grows its own language support.

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
parameters and result types, `ByVal`/`ByRef`, `Long`, `Boolean`, and `String`,
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

Every added v2 prerequisite needs parser, semantic, lowering/backend, malformed
input, and native execution coverage through both v2 stages. Every v3 bootstrap
build must continue to run the v2 fixed-point and v1 preservation suite. A
feature desired for public UBE, but not needed by the initial v3 compiler, is
implemented in v3 rather than expanding this frozen contract.
