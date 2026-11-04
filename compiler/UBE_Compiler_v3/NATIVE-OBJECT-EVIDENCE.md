# Native binary reader evidence - 2026-11-03

This qualifies the bounded binary readers described in
[NATIVE-OBJECT-IMPLEMENTATION.md](NATIVE-OBJECT-IMPLEMENTATION.md), within the
existing First checked native executable deliverable. It does not qualify
complete object/image admission or stack/debug safety.

The subsequent definition-range and immutable integer-data consumer is now
qualified in [NATIVE-BINDING-EVIDENCE.md](NATIVE-BINDING-EVIDENCE.md), including
192 actual object/image table comparisons and retained reader gates. The
checkpoints below retain their original scope and source identities.

The pre-tool expectation owner subsequently passes the 34-group component gate
and retains the generated-reader/data-binding gates; see
[NATIVE-EXPECTATION-EVIDENCE.md](NATIVE-EXPECTATION-EVIDENCE.md). Its real checked-
project integration remains pending.

## Bounded primary-symbol inventory

The production inventory in NativeInventories.bas now consumes the existing
budgeted Core sorter and lookup. Its ownership, failure and accounting contract
is [NATIVE-INVENTORY-IMPLEMENTATION.md](NATIVE-INVENTORY-IMPLEMENTATION.md).
This extends the reader checkpoint below; complete object-to-image binding is
still unfinished.

Commands:

```powershell
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/objects/check.ps1 -DiagnosticOnly
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/objects/check-generated.ps1 -ReaderReport bootstrap/out/native-objects/d10cca44063e467abf63912c49855440/report.json -FramesReport bootstrap/out/native-frames/157eecd5aacd410fade78655207ec826/report.json
```

PASS: the component report
`bootstrap/out/native-objects/d10cca44063e467abf63912c49855440/report.json`
contains 30 groups, 63 commands and 90,745 ms summed command time. Both bootstrap
stages pass 4,196,129 assertions and produce identical 1,022,384-byte raw LLVM,
SHA256 `09B9E25CA0487F91F3249A14C3B53CD78FD92FA106A66A24C56728E425C671BE`.
The generated-input report
`bootstrap/out/native-object-inputs/3325c64aaeb04e76ad7413ba2069630e/report.json`
passes 224 groups and 336 commands in 9,262 ms. It checks both reader stages
against the independent SDK oracle over the 112 retained generated binaries.
Every primary symbol is also compared with its indexed record and found exactly
once among its equal-name keys; auxiliary slots reject. Every non-ABSOLUTE object
relocation target must belong to the primary inventory, including all 65,536
relocations of the assembler fixture in the component gate.

Synthetic expectations cover compact-key ordering with raw COFF record indices,
auxiliary exclusion, missing/absolute/undefined/duplicate definitions, distinct
query owners, malformed auxiliary extents and empty symbol tables. Outputs stay
unchanged on failed queries. The four-record/two-primary fixture requires 59
examined bytes and 58 work events, 232 retained payload bytes and a 240-byte peak
in both parser and global ledgers. It observes six allocations and eight copied
payload bytes, with no name or input copy. Exact/one-below limits independently
exercise parser payload, global payload, inspected bytes and work. Each allocation
refusal leaves accurately charged disposable partial ownership. Cancellation is
injected at every preparation and lookup admission; independent event and actual
byte-read observers agree with returned counters on failure as well as success.
Clearing the inventory succeeds even with the root registry full. The final
assertion requires zero live allocations and zero roots.

Five adverse controls per stage reject omitted byte observations, omitted shared
work observations, accepting auxiliary relocation targets, corrupt symbol skips
and corrupt relocation widths. The private allocator observer is generated only
inside the test output directory; production runtime source is unchanged.

Current production identities:

| Source | Bytes | SHA256 |
| --- | ---: | --- |
| src/NativeInspection.bas | 4399 | 1417DC76EED0CB718E17337494BA990DCA9ED86E81DDC0C3207F3D0023FEA8D6 |
| src/NativeInventories.bas | 15757 | 84A6096BDE56B412DCD34E759E55064058E762C65F0AC65EFD8BEC72807397EB |

The first two reports, `33ef0e39a47c47a9975d8c502b6fd44a` and
`205efb3d87194d27acdd71afe3dc4f9c`, failed incorrect harness expectations:
collection returns whether work was performed, and zero-length array release
does not require a free root slot. Correcting those expectations required no
production change. Intermediate passing report `4dabe21efbe04c65a851c3a20383ff46`
predates the added query/empty-owner assertions and two new adverse controls.
A subsequent test-script edit had a parse error before any gate ran; that edit
was corrected before the final report. All final captured input identities match.

No numeric cap or language behavior changed. DiagnosticOnly uses the retained
qualified bootstrap tools with current component sources; it is not a refreshed
source bootstrap or current whole-compiler qualification. Next bind explicit
compiler-owned expected identities to these inventories and compare retained
object extents/fixups with linked image bytes. Required auxiliary interpretation,
overlap/held-file checks, full stack/recovery/debug analysis, native-builder
integration and the final source-cohort/retained gates remain open.

## Earlier names, symbols, relocations and generated binaries

After the shared Core byte-key extension, fresh current reader and generated-input
gates pass in `bootstrap/out/native-objects/fcea462e08aa452994b9e6fa3c9f8016/report.json`
and `bootstrap/out/native-object-inputs/00d02d40103d4cd28ca249bc223a8008/report.json`.
They retain 26 and 224 groups respectively. Exact dependency/consumer commands
and limits are in ../../std-lib/BYTE-KEY-BUDGET-EVIDENCE.md. The reports below
retain the earlier reader checkpoint and its unchanged reader-source identities.

The maintained reader command below now passes 26 groups and 55 commands in
`bootstrap/out/native-objects/5555ef1b6da347a7a0634197bd395a5f/report.json`.
Summed command time is 62,555 ms. Each bootstrap stage passes 2,098,219 native
assertions. Both raw files are 918,731 bytes with SHA256
`BE46621F734EB3D605D000FD2CD5A7AA05D1B2EA5D2B63D6A8CBFA2994A5C76A`.
All captured inputs retain their identities.

NativeSymbols.bas (9,194 bytes), SHA256
`EC5CA15ECA51428885B8BE1A52F775628CC808E443D132C488A0CCEED497F9DC`,
adds borrowed literal/indirect names, primary symbol fields with checked signed
section references and auxiliary extents, and selected AMD64 relocation
descriptions. Synthetic expectations cover invalid decimal/union offsets,
missing terminators, eight-byte literal names, final-byte strings, opaque
auxiliary skipping, truncated/excess auxiliary counts, target-index bounds,
all twelve selected relocation kinds, exact/one-below patch extents and budgets,
cancellation, allocation denial and full-root refusal with valid descriptors.
Earlier outputs and input/Err state are preserved where contracted.

Real artifacts are compared with an independent Windows IMAGE_* structure
oracle: names and primary symbol records match exactly; every relocation is
decoded, and per-section counts and 64-bit field digests agree. The extended
relocation fixture contains 65,536 real symbolic entries. The digest comparison
is an aggregate regression check, not an adversarial identity proof. Deliberate
bridge corruptions of auxiliary skipping and relocation width are rejected,
alongside the retained omitted-byte-observation control, through both stages.

The generated-artifact integration command is:

```powershell
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/objects/check-generated.ps1 -ReaderReport bootstrap/out/native-objects/5555ef1b6da347a7a0634197bd395a5f/report.json -FramesReport bootstrap/out/native-frames/157eecd5aacd410fade78655207ec826/report.json
```

PASS: 224 groups and 336 commands in
`bootstrap/out/native-object-inputs/9d69205d98f14a47b94055c495a2b06d/report.json`.
Both reader stages inspect 112 retained binaries: three checked-source modules,
common entry, actual Windows platform support, frame metadata and linked image
for every generator-stage/reference/O0-O2/Full-None combination. Artifact hashes
and current reader inputs match before and after verification. These are the
historical generated outputs of the passing frame-binding gate; this does not
rebuild or qualify the current whole compiler. The new native-object-inputs
gate is registered after native-objects in the full bootstrap, with a 180-second
outer deadline. The full refreshed bootstrap remains pending.

At this earlier checkpoint the next action was to build the bounded inventory for
object-to-image retention and relocation/fixup binding. The inventory checkpoint above now establishes primary membership; numeric
indices alone at this earlier checkpoint did not. Required auxiliary interpretation, overlap checks, linked instruction/
unwind proof, complete recovery reserve and debug/publication gates remain open.

## Earlier header/section checkpoint

```powershell
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/objects/check.ps1 -DiagnosticOnly
```

PASS: 22 groups, 47 recorded commands, 52,785 ms summed command time.
Report: `bootstrap/out/native-objects/7f14020842e04dc39004c0bb3f913ae4/report.json`.
Each pinned bootstrap stage passes 2,098,001 native assertions, including the
large root-capacity exercise. Both raw LLVM files are 862,825 bytes with SHA256
`C9D30E87852ED6837E1C6E09249D6547D86C368B116E80A026AF03BDCF2406BA`.
All captured test inputs still match their identities after the gate.

The runner records exact selected compiler, Clang, runtime and Unicode artifacts.
DiagnosticOnly uses the retained source-built v2 cohort
`df15817344774026bebebfd1e9ae8eaf`; it is not a refreshed complete bootstrap.
The gate is registered as native-objects in `bootstrap/build-v2.ps1`, with a
180-second outer deadline. That full bootstrap remains pending.

## Independent assertions

- Core decoding covers every width 1..8 at every fitting offset in a 32-byte
  vector, independent C unsigned accumulation, signed 64-bit boundary patterns,
  bad widths/offsets, truncation and nil storage. It checks old-result/Err/input
  preservation, actual descending byte visits, no payload allocation/copying,
  allocator denial, full managed-root pressure and final cleanup.
- Hand-authored COFF and PE headers and sections cover target/profile fields,
  optional/section/symbol/string bounds, alignment, initialized/zero-filled
  storage, malformed offsets/counts, extended relocation records and image
  address overflow. Exact and one-below byte/event budgets, maximum counters,
  invalid internal state and cancellation have independent expectations.
  The ordinary synthetic COFF header reads 16 bytes in six events; PE reads
  58 in 17; each ordinary section reads 40 in ten. Failure preserves old output.
- Eight real object/image artifacts span O0/O2 and Full/None. A separate C
  oracle uses Windows IMAGE_* structures rather than the production offset
  calculations. Every reported header/section field must agree exactly.
  The artifacts include code, initialized and zero-filled data, relocations,
  symbols and debug sections. No generated executable is run by this gate.
- A real assembler object has exactly 65,536 repeated symbolic relocations.
  Its extended count and effective relocation-array start agree with both the
  assembler source inventory and the structure oracle.
- Omitting physical read observations must fail the native visit assertion
  through both stages. Test-only wrappers preserve the original UBE bodies;
  checked signatures and record layouts establish the C bridge.

## Production identities and implementation limits

| Source | SHA256 |
| --- | --- |
| std-lib/src/portable/BinaryBytes.bas | ED9E4867D4CE171FC983385F9DAC75EB3ED8DBF8FCE9BEED7D1DA37D4EBFDAC1 |
| src/NativeInspection.bas | E6D7D2B9FFBD8F4B7254312503A72BCF67A08BC494C0D0F3DBAFC12257F7C549 |
| src/NativeObjects.bas | 495CA9D9F2C0EA9E864D4E3A920425DA481792E3596E22CFBC73407B891C6ADE |

Format flags use division/modulo and alignment validation uses at most 32
doublings, within the existing bootstrap subset. The reader reuses the existing
SemanticLongLongMaximum helper; the component fixture extracts its exact body,
records its source identity and does not substitute another implementation.
No production numeric cap or language rule changed.

Initial reports `8f2ef8148bc4406eb4ae64f4bf31f81c` and
`5ee13ec02e644a50be66736949c71a75` rejected unsupported integer And expressions.
Report `aa91e918a85c44cfbbdf46831ca49f06` rejected the valid synthetic PE because
the bootstrap emitted the direct maximum literal as an i32 operand. The focused
diagnostic observed 58 reads and controlled failure 1506; using the existing
maximum helper corrected the reader. These were development failures, not
successful qualification. The earlier passing 20-group report
`0e83c21b26a042f195070e80531a49ad` predates the added address/assembler boundaries.

At this earlier checkpoint, names and symbols were still pending; the current
reader and generated-artifact evidence above supersedes that next action. Region
overlap checks, held-file ownership, linked instruction/unwind analysis, complete
recovery reserve and startup/API/refusal closures, DWARF validation, builder
integration and final source-cohort/retained gates remain unfinished.
