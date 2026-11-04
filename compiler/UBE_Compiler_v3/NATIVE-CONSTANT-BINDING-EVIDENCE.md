# Anonymous constant contribution evidence

The anonymous read-only contribution prerequisite now passes focused two-stage
and retained-artifact acceptance. It maps the complete constant section without
using patched instruction operands. Relocation arithmetic and complete instruction
correspondence remain unfinished; the native-executable goal remains active.

## Commands and qualified results

Run from the repository root:

~~~powershell
rtk proxy powershell -NoProfile -ExecutionPolicy Bypass -File compiler/UBE_Compiler_v3/tests/native-executable/objects/check.ps1 -DiagnosticOnly
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/objects/check-constant-bindings.ps1 -ReaderReport bootstrap/out/native-objects/a6f4780d59004cde9a02f707e8383836/report.json -NamedReport bootstrap/out/native-named-relocations/0c9070fbe2e5457f861dfccc5faeaa0d/report.json
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/objects/check-named-relocations.ps1 -ReaderReport bootstrap/out/native-objects/a6f4780d59004cde9a02f707e8383836/report.json -BindingReport bootstrap/out/native-extent-bindings/1ee39e22ed974005bec0d08bcd718b3f/report.json
~~~

All three commands passed on their first qualification runs.

| Gate | Report under bootstrap/out | Groups | Commands | Summed child milliseconds |
| --- | --- | ---: | ---: | ---: |
| Component readers | native-objects/a6f4780d59004cde9a02f707e8383836/report.json | 74 | 151 | 431165 |
| Constant contributions | native-constant-bindings/c076a07022014cadbc30d8f4a84a065d/report.json | 96 | 96 | 3128 |
| Named targets retained | native-named-relocations/373505fd300841b0b31f96476b3429dd/report.json | 736 | 736 | 30812 |

The combined reader gate passed 29,376,033 assertions per stage and retains its
existing binary, symbol, inventory, binding, unwind, instruction, function-index,
leaf and named-target tests. The new hand-specified cases cover lengths 1/7/8/9/31,
unaligned file positions, explicit address alignment, the final possible match,
zero/own auxiliary section numbers, and an empty neighboring section. Thirty-three
candidate failures cover unsupported fields/attributes, auxiliary targets,
missing/mutated/padding-only data, duplicate and overlapping byte matches, wrong
alignment, and virtual/file aliases through writable sections. Six invalid owner
cases per configuration, exact/one-below observed byte/event budgets, every
cancellation admission, no-allocation/no-copy/Err preservation, root refusal and
unchanged old outputs pass. Corrupting either published byte count is detected
through each stage.

The actual gate covers all eight O0 private error-support objects previously
identified by their rejected anonymous references. The independent oracle reads
SDK field offsets and compares complete byte sequences; it does not reuse the
production chunk comparator or relocation values. The expected 31 bytes are the
independently specified stack-error description and source strings, including
their terminators. Both readers agree on complete object/image ranges and the
two code references per object: 16 contribution observations and 32 reference
associations. Incorrect bytes, duplicate placement, writable image data, wrong
auxiliary length and a changed expected RVA supply 80 rejected controls. Candidate
and mutated executable files are read as data, not executed.

The named-target refresh retains all 736 groups: 11,392 named target observations,
32 explicit anonymous-target rejections by that separate API, and 448 rejected
controls. Anonymous mappings now have their own qualified consumer; they are not
silently accepted by the named-target routine.

## Identities, bounds and integration

NativeConstants.bas is 10,099 bytes, SHA-256
04E551504036E1614C99D6BC44B9AF1AF3F7E2D420F416B14476728727ABDE51.
Both raw component LLVM files are 1,604,099 bytes, SHA-256
3A44A0566007863E06B06CBE3006C4A83C97C245A36FB2F8EE1E2D0C2851EB82.

The bootstrap selection remains df15817344774026bebebfd1e9ae8eaf. Exact source,
tool, executable, expected-transport and candidate identities are in the reports.
The component and constant gates rechecked 93 and 115 input records respectively;
the named-target refresh rechecked 387. A final SHA-256 audit of all 260 distinct
captured paths found no changes. rtk proxy git diff --check passed with only
line-ending notices.
DiagnosticOnly uses those pinned historical compiler tools to compile the current
component sources; this is not a current full-source bootstrap qualification.
NativeConstants is registered in the production manifest and maintained reader
gate. The existing full-bootstrap reader gate consumes it; the full bootstrap
was not rerun for this prerequisite.

NATIVE-CONSTANT-BINDING-IMPLEMENTATION.md specifies eligibility, complete unique
placement, overlap rejection, checked result arithmetic, ownership and failure
semantics. Comparisons reuse the existing bounded little-endian reads. No numeric
cap, declaration/body/argument bound, payload allocation, worker pool, external
inspector, language behavior or production source-consistency policy changed.
The preexisting 600-second whole reader-gate deadline remains unchanged.

## Next comparison diagnostic and limitations

bootstrap/out/native-fixup-correspondence-diagnostic.json records a focused
diagnostic over 112 generated code sections and 128 exact object/image input
identities. Retained named function anchors give a common section placement in
each observed object. Across 146,088 code bytes, all 5,712 code relocations match
REL32 or SECREL arithmetic; all bytes outside their fields match as well. The
diagnostic also resolves the anonymous constant by its complete unique bytes.
Its input hashes match the retained extent-binding report.

That result changes the next implementation target; it does not qualify a
production fixup checker. Production must still tie code placement to the frozen
retention records, admit and evaluate every relocation, reject overlapping fields,
compare the remaining bytes, and preserve the shared budget/atomic-failure rules.
Anonymous contributions must be bound once per distinct input contribution and
cross-object alias/overlap policy must be enforced during integration.

Pointer-cell contents, import/TLS semantics, complete unwind/stack/reserve analysis,
startup/API/refusal closure, debug validation, tool/build ownership, held-file
identity, publication and final source-cohort acceptance remain required.
Neither constant content nor a matching target address proves those properties.
