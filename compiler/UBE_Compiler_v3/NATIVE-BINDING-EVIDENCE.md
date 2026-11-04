# Native definition/data binding evidence - 2026-11-03

This qualifies the production UBE definition-range and immutable integer-data
consumer described in [NATIVE-BINDING-IMPLEMENTATION.md](NATIVE-BINDING-IMPLEMENTATION.md).
It advances the existing object/image and frame-data requirements. It does not
qualify complete owned-definition retention, instruction/fixup binding, recovery
reserve derivation, stack/debug safety, native builder or publication.

## Commands and current reports

```powershell
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/objects/check.ps1 -DiagnosticOnly
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/objects/check-bindings.ps1 -ReaderReport bootstrap/out/native-objects/4a3c91f1f60c4980b3b45408487e6e9c/report.json -FramesReport bootstrap/out/native-frames/157eecd5aacd410fade78655207ec826/report.json
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/objects/check-generated.ps1 -ReaderReport bootstrap/out/native-objects/4a3c91f1f60c4980b3b45408487e6e9c/report.json -FramesReport bootstrap/out/native-frames/157eecd5aacd410fade78655207ec826/report.json
rtk proxy powershell -NoProfile -File bootstrap/out/check-binding-scripts.ps1
rtk proxy git -c core.autocrlf=false -c core.whitespace=blank-at-eol,blank-at-eof,space-before-tab,cr-at-eol diff --check
```

- Component report `bootstrap/out/native-objects/4a3c91f1f60c4980b3b45408487e6e9c/report.json`:
  PASS, 30 groups, 63 commands, 104,512 ms summed command time. Each bootstrap
  stage passes 6,293,679 assertions, including large root-pressure exercises.
- Data report `bootstrap/out/native-data-bindings/1ddb50c4c0d9429589f14568c6377382/report.json`:
  PASS, 192 groups/commands, 6,271 ms summed command time. There are 128 exact
  table/reserve comparisons and 64 rejection comparisons.
- Generated-input report `bootstrap/out/native-object-inputs/429f82a70a1445c69d935bc525f02148/report.json`:
  PASS, 224 groups, 336 commands. Both readers retain SDK comparisons across
  112 generated binaries and indexed primary/relocation membership checks.
- Four PowerShell syntax checks and the Git whitespace check pass. The new
  `native-data-bindings` gate is registered after native-object-inputs in the
  existing bootstrap runner, using the current reader and frame proof paths
  with a 180-second outer deadline. The complete bootstrap is not rerun here.

Both raw component LLVM files are identical: 1,058,505 bytes, SHA256
`7DFA9B602B54D4685A0EFBBEFC5DE91E6706B3A72AC777B4AB63E72919922337`.
NativeBindings.bas is 6,909 bytes, SHA256
`04724D37560A4D91CE7C852AC6838BCC84EBD13A8CAD6A2F7AC81412449953CE`.
The reports capture all source, bridge, contract, runtime and tool identities.
DiagnosticOnly compiles current component sources through the retained qualified
bootstrap tools; it does not refresh the whole source bootstrap or generator.

## Independent assertions

Known synthetic COFF/PE records specify the expected raw symbol index, section,
file position, section-relative offset, initialized byte count, RVA and absolute
address independently. Exact section-end requests pass; one byte beyond fails.
PE raw alignment padding cannot satisfy a logical extent. Entire object zero-fill
and partially initialized PE tails have explicitly checked file-range results;
immutable table validation rejects both. Empty requests/expected arrays reject
as invalid caller state. Missing and duplicate names, wrong COFF type, missing
read/data flags, write/execute permission and altered final integer bytes reject.
Both signed 64-bit boundary bit patterns survive little-endian comparisons.

Relocations ending at the data start or beginning at its end are disjoint and
accepted; crossing either edge rejects. ABSOLUTE padding is ignored. All value
and range failures preserve the earlier output. Exact/one-below byte/event caps,
cancellation at every admitted event, independently observed charged/actual reads,
no allocation or payload copying, incoming Err preservation and full-root refusal
are covered. The final process assertion requires zero roots/live allocations.
The previous reader/inventory adverse controls remain passing.

The actual-data gate uses the 16 retained generator-stage/reference/O0-O2/Full-None
frame bindings. Expected names and footprint values come from the independently
qualified frame report, not from candidate symbols or bytes. Production UBE
resolves and validates both `ube.stack.frames` and `ube.stack.reserve` in
metadata objects and final images through both reader stages. Its second query
uses separate expected-name bytes. The 256-byte reserve remains controlled test
data, not a derived safety bound. Every retained object/image with one footprint
understated by eight bytes is rejected by the production validator before any
execution. File I/O and expected-value transport are test-only; production
validation reads the supplied immutable owners without textual LLVM inspection.

Intermediate passing component report `bc86d6554fe94515a24b70d98bfa98a3` and
data report `9d9c20dc6d35414e8112bf98f821efc7` predate the added empty-input and
full-root assertions. Production source is unchanged between those and the final
reports. The generated objects/images are retained historical outputs, not a
current whole-compiler build. All final captured inputs still match their hashes.
No numeric cap, language rule or production runtime source changed.

## Remaining integration

Freeze the complete expected source/linkage identity table from checked lowering
and support emission before invoking tools. Use it to bind surviving owned
object definitions to the image, preserving the contract's distinction between
permitted elimination before object emission and unexplained loss during link.
Derive code extents and compare initialized bytes with checked relocation fixups;
do not treat equal names or these integer-table checks as instruction retention
proof. Required auxiliary interpretation, overlapping mappings, held candidate
identity, complete reserve/stack/debug analysis, diagnostics, builder/publication
and final current-source/retained qualification remain required by the active goal.
