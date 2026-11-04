# Native reference-pointer evidence

The implementation contract is NATIVE-REFERENCE-POINTER-IMPLEMENTATION.md.
TryBindNativeReferencePointer validates the exact linked pointer-cell name,
complete initialized resident read-only range, frozen referent VA and eight-byte
RIP-relative read. It publishes the full cell range only on success. It reuses
existing inventory lookup, range location, byte comparison and contribution
isolation; generated-target checks share the extracted anchor comparison.

## Qualification - 2026-11-04

Commands from the repository root:

~~~powershell
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/objects/check.ps1 -DiagnosticOnly
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/objects/check-instructions.ps1 -ReaderReport bootstrap/out/native-objects/99ff9f63d8e84eb39de473f50215e55e/report.json -BindingReport bootstrap/out/native-extent-bindings/1ee39e22ed974005bec0d08bcd718b3f/report.json -WholeCode
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/objects/check-instructions.ps1 -ReaderReport bootstrap/out/native-objects/99ff9f63d8e84eb39de473f50215e55e/report.json -BindingReport bootstrap/out/native-extent-bindings/1ee39e22ed974005bec0d08bcd718b3f/report.json
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/objects/check-fixups.ps1 -ReaderReport bootstrap/out/native-objects/99ff9f63d8e84eb39de473f50215e55e/report.json -BindingReport bootstrap/out/native-extent-bindings/1ee39e22ed974005bec0d08bcd718b3f/report.json -InstructionReport bootstrap/out/native-code-instructions/0cc1c410feb94cad90c1cee35e5c45ca/report.json -ReferencePointers
~~~

All passed. Report paths below are relative to bootstrap/out:

| Gate | Report | Groups | Commands | Summed child ms | Input records |
| --- | --- | ---: | ---: | ---: | ---: |
| Component | native-objects/99ff9f63d8e84eb39de473f50215e55e/report.json | 102 | 207 | 791043 | 109 |
| Complete instructions | native-code-instructions/0cc1c410feb94cad90c1cee35e5c45ca/report.json | 2240 | 2352 | 56663 | 260 |
| Retained leaves | native-instructions/5195a5c99f604176bd0a49f285ae5d6d/report.json | 128 | 160 | 4417 | 148 |
| Reference/generated/signed targets and fixups | native-fixups/6c937888715a49abb02b23a217434e4c/report.json | 3296 | 3300 | 155609 | 1135 |

Both stages pass 44,063,350 component assertions. The literal fixture includes
26 descriptor and 12 candidate-image mutations, complete output preservation,
immutable inputs and Err preservation, exact byte/event limits and every observed
cancellation point, allocation independence and actual root refusal. Corrupted
range and forced true/false controls reject through both stages.

Raw LLVM is identical: 1,887,194 bytes, SHA-256
1F6BF44B5FFDA5E81E823C0E58B993F8707D9F6D427C5C4DE4DCD079C08B342E.
NativeBindings.bas is 26,469 bytes, SHA-256
DABC4685410F6F0AFBA8880B5512CE5397B2A5CB77A6DFA12AA1C1ADCAFBBB15.

The complete instruction gate retains 36,192 instructions and 5,712 fields with
1,792 negative controls. The retained leaf gate keeps 2,496 observations and
64 rejections. The final target matrix retains all 32 reader/image frozen-owner
comparisons and 288 object/image comparisons. Both readers match all 1,880
reference-pointer uses in 64 objects (3,760 observations), alongside 3,128
generated references and the complete 5,712 signed-target/field corpus.
All 512 new reference-pointer mutations and 2,464 retained target/encoding
mutations reject (2,976 total). Reference associations are independently derived
from frozen names and image symbols/values; production binding checks the full
cell range, permissions, name and contents for each actual use.

The final SHA-256 audit confirms all 591 distinct input paths across these four
gates and the reference-cell/PE-directory diagnostics unchanged. See
bootstrap/out/native-reference-pointer-input-audit.json. Source consistency checks
are verification-only; production does not monitor or reject source changes.
PowerShell syntax and edited-file whitespace checks pass. Child times establish
bounded test completion, not compiler performance. The final two full probes took
181090 and 188061 ms; the summed component children took 791043 ms, within the
measured test allowances described below. No production resource cap changed.
The full bootstrap and final native build remain unqualified and were not rerun.

## Diagnostic history

The first-stage focused --reference-pointers fixture passed. The focused image
comparison passed 261 signed fields, 130 generated accesses and 108 pointer reads;
all four reference corruption controls rejected. The independently calculated
reference association transport matched. These diagnostics are under
bootstrap/out/native-reference-pointer-focused/df2a27c9f47f19eeb532b78335ccdcfe;
the maintained gates above supersede them for qualification.

The first full component run 437d29ed0fa04037a7d3ad975c2385b7 failed because its
stage0-probe.exe child exceeded the existing 180-second deadline (180094 ms).
The report records a timed-out child and terminal failure, not an observation
timeout or a passing run. A separate bounded 300-second run of that same binary
completed successfully in 193850 ms, with 44,063,350 assertions and empty stderr.
Its command/result is retained as component-duration.json in the focused directory.
The component now allows 240 seconds for each full probe only; all other child
deadlines are unchanged. The enclosing native-objects bootstrap allowance changes
from 720 to 900 seconds to accommodate both measured probes and the added controls.
Production limits and acceptance assertions are unchanged. The measured binary
pass was diagnostic; the fresh two-stage gate above qualifies the current inputs.

The next run 3c8348d3952d4c3f98ba0c655c1b8033 passed its full first-stage probe
in 180779 ms, then failed the new corrupted-range control because the harness
omitted --reference-pointers and launched the full suite under its ten-second
control deadline. The routing is corrected. Running that same corrupted binary
with the focused argument returns exit 1 at the complete cell-range oracle as
required. This failed gate is retained and is not qualification evidence.

The independent COFF diagnostic records all 288 producer reference-cell
definitions across 144 objects: zero offset, eight bytes, one ADDR64 relocation,
zero original addend, ordinary external data symbol and flags 0x40401040.
bootstrap/out/native-reference-pointer-diagnostic.json records its 145 inputs.
The earlier ownership diagnostic establishes the 1,880 code-reference census.

IAT/TLS metadata, subsequent pointer/register propagation, global data aliases,
image rebasing/loader semantics, complete control flow/stack/debug validation,
build ownership and complete native acceptance remain unfinished. The original
native-executable goal stays active.
