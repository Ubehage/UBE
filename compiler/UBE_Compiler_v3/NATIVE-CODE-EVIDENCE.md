# Retained code contribution evidence

Production whole-code contribution placement and byte comparison now pass
two-stage component and retained-artifact gates. TryValidateNativeCodeContribution
starts from a frozen retained function anchor, derives its complete ordinary
object section's image placement, rejects aliases/overlapping relocation fields,
checks every fixup through the existing target resolvers and compares every
remaining byte. It publishes complete scalar contribution ranges atomically.
This does not complete the First checked native executable goal.

## Commands and current results

Run from the repository root:

~~~powershell
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/objects/check.ps1 -DiagnosticOnly
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/objects/check-code.ps1 -ReaderReport bootstrap/out/native-objects/ff698de798c642e3b8ee7efd0902eae4/report.json -BindingReport bootstrap/out/native-extent-bindings/1ee39e22ed974005bec0d08bcd718b3f/report.json
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/objects/check-constant-bindings.ps1 -ReaderReport bootstrap/out/native-objects/ff698de798c642e3b8ee7efd0902eae4/report.json -NamedReport bootstrap/out/native-named-relocations/373505fd300841b0b31f96476b3429dd/report.json
~~~

All passed. DiagnosticOnly uses the retained pinned bootstrap executables; it
does not refresh the whole compiler's source-cohort qualification. The code and
constant artifact gates ran concurrently in separate output directories. Their
child timings below are observations, not a compiler performance claim.

| Gate | Report under bootstrap/out | Groups | Commands | Summed child milliseconds |
| --- | --- | ---: | ---: | ---: |
| Component readers | native-objects/ff698de798c642e3b8ee7efd0902eae4/report.json | 82 | 167 | 548147 |
| Complete code contributions | native-code/8a262de376da4271ba740fbebb165d7b/report.json | 1408 | 1410 | 67820 |
| Constant contributions retained | native-constant-bindings/2bd4783e9cf24224b1f89b1ad2a31d86/report.json | 96 | 96 | 3284 |

The component suite passed 33,573,187 assertions per stage. Six synthetic code
configurations cover unchanged code, mixed REL32/SECREL fields, ignored ABSOLUTE
records, empty neighboring sections, exact image boundaries and anchors at the
first/last object byte. Mutating each of the 64 linked bytes in every configuration
rejects, including non-relocated and trailing bytes. Twenty-one candidate cases
exercise out-of-order/overlapping fields, bad targets/kinds/spans, altered addends,
metadata aliases, unsupported section attributes/alignment, changed placement,
truncation and object/image section aliases. Eighteen caller-state mutations per
configuration, exact/one-below budgets, every cancellation admission, no
allocation/copy, ordinary successful Err preservation, immutable inputs, root
refusal and atomic old-result retention pass. Corrupting the published code count
or image placement is detected through both stages.

The shared TryCompareNativeByteSpan and TryValidateNativeContributionIsolation
helpers keep constant and code consumers on the same byte-read and overlap
rules. Direct checks cover equal/different/empty spans, eight invalid ranges,
metadata aliasing, malformed metadata arithmetic, budget/cancellation failure and
preservation of the equality result. Earlier constant, relocation, instruction,
leaf, unwind, inventory and binding assertions remain included. The affected
constant artifact matrix retains all 96 groups and its 80 rejected mutations.

The complete-code gate uses the frozen expected-row transports already retained
by the extent-binding gate. It composes TryBindNativeDefinition with the new
production consumer once per code section, checks the other frozen anchors
against the resulting placement, and requires coverage of every nonempty code
section in the object. Independent SDK offsets and frozen names supply expected
whole ranges. The 144 object/image pairs produce 288 positive unit comparisons,
including 64 empty comparisons: 224 contribution observations and 292,176 content
bytes across both readers. These contain all 11,424 relocation-field observations
previously covered by the scalar fixup matrix. Altered ordinary bytes, linked
fields, original addends, retained image anchors and overlapping relocation fields
provide 1,120 rejected controls, each failing in production comparison with 1506.
Candidate executable images are read as data, never executed by this gate.

Before the byte-loop consolidation, the first implementation also passed
native-objects/584eeb810c0946b7bad9cff569dfe1db/report.json (82 groups) and
native-code/03f73a90ff494f458d030c283ee0bf66/report.json (1408 groups). Those are
superseded source checkpoints. The current reports above include the shared
comparison and its direct regression cases.

## Identities and measured work

| Production source | Bytes | SHA-256 |
| --- | ---: | --- |
| NativeCode.bas | 9527 | 54AD87BD8B1355FDECE07EE496896DBB72A9606C0BEF9E4DE655421161C8D5D9 |
| NativeBindings.bas | 15464 | 3E3A9F5F5F7738BB0A1FE78CE9C854561EA9E3FC6064DC8618A7F95CA05FFEFB |
| NativeConstants.bas | 8665 | F4521827160D18E68BC460C3896639235BD748AC09378F29101D811FC9C5E0EF |
| NativeInspection.bas | 6092 | 07321A3360EFA57B199D774F3D98185B9005EB3C80E3E0EF8C5E373B91DDCFC5 |

Both raw component LLVM files are 1,702,135 bytes, SHA-256
50C4A2419CCA42D9B150674AC4D315338E385B6B390641339F5519B3994F2BDE.
The bootstrap selection remains df15817344774026bebebfd1e9ae8eaf. The component,
code and constant reports captured 99, 542 and 121 input records respectively.
A final SHA-256 audit of their 417 distinct captured paths found no changes.
git diff --check passed with existing LF-to-CRLF notices. The code gate's
PowerShell syntax check passed before execution. All test handles are terminal.

Production workspace is scalar with no payload allocation/copy. Code-content
comparison reads exactly twice the original section length; target resolution,
retention, section/metadata and relocation reads are additionally charged. The
positive complete-code matrix observed 9,279,120 inspection bytes and 3,438,320
events in total. Its largest unit used 212,696 bytes and 69,856 events, including
repeated target resolution. No cache is assumed or needed for this measured
corpus. All numeric caps, declaration/body/argument bounds and the enclosing
600-second component deadline remain unchanged. NATIVE-CODE-IMPLEMENTATION.md,
NATIVE-BINDING-IMPLEMENTATION.md and NATIVE-OBJECT-IMPLEMENTATION.md define the
ownership, failure and shared-comparison contracts.

## Diagnostic guidance for the next consumer

The retained placement diagnostic found 112 code sections and 146,088 bytes,
with a frozen anchor for each and ordered nonoverlapping relocation fields.
Grouping those ranges by their 16 images found no cross-object code overlap.
These observations are in bootstrap/out/native-code-placement-diagnostic.json
and native-code-ownership-diagnostic.json; they do not implement the complete
build owner's ownership check.

The following diagnostic commands ran after the maintained gates' source edits:

~~~powershell
rtk proxy powershell -NoProfile -File bootstrap/out/diagnose-code-instructions.ps1
rtk proxy powershell -NoProfile -File bootstrap/out/native-instruction-coverage-diagnostic/run.ps1 -ReaderReport bootstrap/out/native-objects/ff698de798c642e3b8ee7efd0902eae4/report.json
~~~

The pinned LLVM disassembler accounts for all 146,088 bytes as 36,192 instruction
lines across 112 objects. The two-reader diagnostic made 224 comparisons: 72,160
instructions were accepted with zero length/flow/signed-displacement disagreements,
and 224 were rejected with 1506. Each reader rejects the same 112 one-byte CC
(INT3) encodings. Raw relocation association identifies the immediately preceding
calls: 96 to ube.stack.abort and 16 through __imp_ExitProcess. The report and
rejected-encodings.json are under native-instruction-coverage-diagnostic; full
disassembly and mnemonic census are in native-code-disassembly-diagnostic.*.
This diagnoses a specific decoder-profile gap. It does not establish that traps
are reachable, harmless padding, or safely unreachable: function extents,
termination-call semantics and complete control flow must decide that.

Next qualify complete-build contribution ownership/anchor consistency and the
instruction/control-flow consumer, including the observed INT3 sentinels after
termination calls. Full operand/effective-target checks, pointer-cell/import/TLS
meaning, unwind/call-site/prologue/stack reserve and startup/API/refusal closure,
debug validation, tool/build ownership, diagnostic delivery, publication and a
fresh complete source-cohort acceptance remain required. The full goal remains
active and incomplete.

## Production ownership follow-up

The subsequent source cohort adds production anchor consistency, exact object
section coverage and complete retained-image owner/file/RVA uniqueness.
NATIVE-CODE-OWNERSHIP-EVIDENCE.md records the passing 86-group component and
2,208-group refreshed code gate, including all preceding byte/fixup comparisons
and the new ownership controls. Its source identities supersede this document's
earlier component hashes for current NativeCode; earlier reports remain
historical. Native build ownership and complete executable safety are still
unfinished.
