# Object-to-image definition retention evidence - 2026-11-03

Production NativeBindings now consumes frozen NativeExpectedDefinition rows to
bind each surviving object definition to its linked image. The allocation,
ownership, failure and scope contract is in NATIVE-BINDING-IMPLEMENTATION.md.
TrySelectNativeDefinition reuses the existing bounded inventory lookup with an
explicit optional-absence result; the required TryFindNativeDefinition API retains
its previous missing/ambiguous rejection. No prefix establishes ownership.

## Commands and results

```powershell
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/objects/check.ps1 -DiagnosticOnly
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/objects/check-retention.ps1 -ReaderReport bootstrap/out/native-objects/367c38a934424f138f59fb5ef7d94052/report.json -GraphReport bootstrap/out/native-graph/3ae0e5a87d014b82a61adaae0cc28595/report.json -SupportReport bootstrap/out/explicit-link-inputs/318209f12b5b4f0282acf596c47e6386/report.json
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/objects/check-bindings.ps1 -ReaderReport bootstrap/out/native-objects/367c38a934424f138f59fb5ef7d94052/report.json -FramesReport bootstrap/out/native-frames/157eecd5aacd410fade78655207ec826/report.json
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/objects/check-generated.ps1 -ReaderReport bootstrap/out/native-objects/367c38a934424f138f59fb5ef7d94052/report.json -FramesReport bootstrap/out/native-frames/157eecd5aacd410fade78655207ec826/report.json
rtk proxy powershell -NoProfile -File bootstrap/out/check-retention-script-syntax.ps1
```

| Gate | Passing report under bootstrap/out | Groups | Commands |
| --- | --- | ---: | ---: |
| Component | native-objects/367c38a934424f138f59fb5ef7d94052/report.json | 38 | 79 |
| Linked retention | native-retention/c1913cf3e481487f99f4991c876ff6f3/report.json | 416 | 576 |
| Retained integer data | native-data-bindings/0512dd5654a6402cb731bcf979d01caa/report.json | 192 | 192 |
| Retained generated readers | native-object-inputs/f529dfaf4874450a95fed51f074027b7/report.json | 224 | 336 |

The component passes 8,394,970 assertions per bootstrap stage in 148,876 ms summed
command time. Both raw outputs are identical: 1,214,053 bytes, SHA256
`5A8AA13DEA9B33821FF827676EE089A9FD1152EC3FAE185536B3B905770A0B77`.
NativeBindings.bas is 11,811 bytes, SHA256
`09C97A3901B8FE5548AED1A5FE46597190CDAB4CC39FC8B38057580FDE742602`.
NativeInventories.bas is 16,575 bytes, SHA256
`624F12AE9FBD7C25056999110E168BF5B7E480E8A904E81D909C10BDFDE559E3`.
All captured input hashes match: 67 component, 245 linked-retention, 137 data
binding and 186 generated-reader inputs. The two script parser checks and
changed-file whitespace checks pass.

## Independent coverage

Synthetic object/image pairs have independently specified section offsets,
addresses, names and storage spans. They exercise readable executable function
anchors, immutable initialized tables, mutable initialized globals and zero-fill
storage. Either side is independently changed to test missing names, undefined
symbols, duplicates, wrong symbol types, absent read/execute permission, wrong
write permission, out-of-section values and unusable initialized extents.
Required absence rejects; optional absence in the object publishes neutral fields.
A present object definition remains required in the image regardless of the
pre-object optional flag. Invalid expected rows reject with controlled failure.

Every measured inspection event is exercised as a cancellation point; exact and
one-below byte/event budgets distinguish success from controlled exhaustion.
The independent hooks confirm actual read/event accounting, no payload allocation
or copying, unchanged input bytes and Err, and unchanged prior results on failure.
Full root-registry pressure returns a controlled failure. Corrupted returned object
indices and presence flags are rejected. Existing inventory/range/integer-data
regressions continue through the same gate after the shared lookup refactor.

The real-artifact test consumes the frozen 54-row tables and all nine output units
from the preceding qualified graph report, without deriving expectations from the
image. It validates their retained hashes, then freshly links 16 images: both
generator stages, both root/reference layouts, O0/O2 and Full/None. It uses the
reviewed explicit 20-item startup/archive sequence and pinned Clang/LLD, with
configuration/default directives disabled and no stripping or debug-only retention
flag. Independent test-only llvm-nm inventories establish presence in each object.
Both production reader stages must return the same per-row presence and successfully
bind every surviving definition to the image with the required type, permission
and data extent. This covers 288 output-unit comparisons and 1,728 expected rows.
Missing Main, missing an ordinary non-Main procedure, wrong function type and an
out-of-section symbol value produce 128 rejected image mutations. The linked gate
completes in 22,928 ms summed command time. Images use controlled frame values and
reserve 256 and are not executed by this retention gate.

## Diagnostic corrections

The first component report, `2bc7e5006c9f4e819310c43e5aa7f3df`, rejected the
optional-absence C assertion. A focused recompile against those exact production
bodies, `bootstrap/out/check-retention-diagnostic.ps1`, demonstrated that all
returned fields were neutral; the oracle had compared the padding following the
Long presence flag. The assertion now compares defined fields. No production
change was needed. The diagnostic result is `bootstrap/out/retention-diagnostic.json`.

Report `5253945b883c40b1b248bb053519776e` passed positive first-stage checks, but
the presence mutant was rejected earlier by failure-result preservation than the
runner's intended absence-message match. The maintained control now writes zero
to the successful presence result and requires the independent present-definition
assertion to reject it. Neither a timeout nor a mismatched assertion is accepted
as proof of the intended negative control. No crash occurred in either diagnosis.

## Remaining acceptance work

This qualifies symbol/anchor and expected storage-span retention. A procedure
range currently contains one initialized byte at its anchor; it is not a claimed
code extent or instruction comparison. Complete code extents, backend-generated
auxiliary/section ownership, relocation target resolution, object-to-image byte
and fixup equality, stack/reserve derivation, producer/CU/debug validation, held
candidate identity, native builder and publication remain required.

The component runs inside the existing bootstrap native-objects gate. The linked
matrix is currently an explicit maintained command using retained graph and reviewed
support evidence; whole-bootstrap wiring must use the integrated current toolchain
resolution evidence, without hardcoding this historical report path. DiagnosticOnly
qualifies current component sources with retained bootstrap tools. This turn does
not regenerate the full compiler graph or refresh the whole source bootstrap.
