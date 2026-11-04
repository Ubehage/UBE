# Native frame metadata and object binding

This implements the existing NATIVE-STACK-REVIEW.md requirement to bind complete
call footprints to exact non-LTO objects. It does not introduce another target,
inspection tool in production, or a different safety criterion.

`NativeFrames.TryEmitNativeFrameData` borrows an immutable caller-owned zero-based
array from the existing array storage mechanism, in
the existing frame order: F ordinary procedures, M source initializers, then the
module-wait slot. The build owner retains the checked identity mapping, exact
objects and analysis evidence. A successful emitter call is not proof of that
evidence. The ordinary build must reject missing/dynamic/unclassified footprint
or reserve evidence before publishing a candidate.

The emitter validates positive F/M, checked count arithmetic, exact array length,
and at least eight bytes for every complete call footprint and reserve. Eight
bytes account for the x64 call return address even for a verified zero-frame
leaf; this is a minimum shape check, not reserve derivation. It writes two
immutable globals through the existing bounded writer. A failed partial output
is private and disposable. It owns no scratch arrays, retains no borrowed owner,
performs no host I/O and changes no Err state. Separate callers can run with
independent writers; the array must remain immutable during the call.

Each frame slot charges one metadata work event, F+M+1 total, against the shared
work limit and cancellation cadence. Two generated identities and all actual
output bytes are charged. Declaration/import and body traversal bounds are
unchanged: these are separately indexed metadata entries, not declaration
rescans. Numeric caps remain unchanged.

The retained checked module objects contain normal Windows x64 unwind entries
for stack-using functions and omit entries for some leaf functions. The focused
binding gate must cross-check static stack reports with the actual unwind/prologue
evidence, explicitly classify leaves, and add the return address. It must retain
the measured objects, link separate generated data without LTO/recompilation,
check the linked values, and reject understated/missing/duplicate metadata.
Static own-frame sizes alone do not establish call-site transients or the full
startup/API/recovery closure. Those obligations remain required.

## Emitter qualification

```powershell
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/initialization/check.ps1 -DiagnosticOnly
```

The retained two-stage report is
`../../bootstrap/out/native-initialization/1b0d3bc34a644986853863443ae457a8/report.json`:
358 groups, 1,096 commands, 272,872 ms of recorded command time and 2,097,703
emitter/resource assertions per stage. The frame-specific assertions cover exact
bytes/order, count/size/overflow rejection, exact/below work/identity/output/payload
limits, allocation failure, cancellation before work and at the 4,097th visit,
Err preservation, borrowed input retention and complete cleanup. Existing
initialization/platform/entry checks remain passing.

Both raw images are identical: 973,546 bytes, SHA-256
`6DCA78DA59470783FF86FED8FA8FA26ECEC4F679793C79B3D8098E210DF808CC`.
NativeFrames.bas is 2,782 bytes, SHA-256
`899E9F696DFAD5AAA4D2D5F333702055C5B40DBEF0DAC20D44C27C997EAE5245`.
These are pinned historical bootstrap tools on current source, not a refreshed
whole-bootstrap acceptance result.

Two initial harness compilation failures are retained in native-initialization
reports `5cf7abdeb03a442498037a17c58156c9` and
`0e745c2b49e745c0b9fea981ffe4de99`. The first required explicit casts from test
byte storage to int64_t; the second required a dedicated test entry-name macro
instead of nesting conflicting main macros. Neither changed production code.
The corrected focused emitter probe passed 2,097,703 assertions before the full
rerun. The focused object diagnostic
`../../bootstrap/out/frame-object-diagnostic/e57f9eb4e1d24c2292e1dd79df93740a/report.json`
passes static/unwind/leaf comparisons for the three retained checked modules at
O0/O2 and reads back the production emitter's six-slot test metadata object.

`tests/native-executable/frames/check.ps1` consumes hash-pinned checked-module
outputs and the exact production emitter's separately built test transport.
It is registered after the graph and initialization gates in bootstrap/build-v2.
The test uses existing LLVM inspectors; no textual inspector is introduced into
production. It distinguishes metadata/object identity checks from the unfinished
production bounded binary inspector, linked instruction/fixup verification,
call-site transient analysis, derived reserve and startup/API safety proof.

## Object/data binding qualification

```powershell
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/frames/check.ps1 -GraphReport bootstrap/out/native-graph/927756dfc68f45b8b2f9770a039ca4e8/report.json -EmissionReport bootstrap/out/native-initialization/1b0d3bc34a644986853863443ae457a8/report.json
rtk proxy powershell -NoProfile -File bootstrap/out/check-frame-scripts.ps1
rtk proxy powershell -NoProfile -File bootstrap/out/check-platform-scripts.ps1
rtk proxy git -c core.safecrlf=false diff --check
```

Report `../../bootstrap/out/native-frames/157eecd5aacd410fade78655207ec826/report.json`
passes 36 groups and 548 commands in 23,778 ms. It covers both bootstrap emitters,
single-package/direct-reference checked programs, O0/O2 and Full/None flags:
16 independent object/data/image bindings. The default 60-second bootstrap
proof deadline is retained. All captured input hashes match after completion.
The two parser-script checks and the whitespace check pass. No live command
handles remain for this checkpoint.

Each binding compiles actual previously checked module/entry LLVM plus the real
Windows platform support once, with no LTO. It compares the complete function
definition inventory with static stack reports, checks nonzero own-frame sizes
against unwind allocation/push operations, and requires disassembly evidence for
zero-frame leaves. It maps all 14 ordinary procedures, three initializers and
the wait procedure to their existing slots. Every complete call footprint adds
eight bytes for the return address. The tested values range from 8 to 192 bytes;
an O2 source leaf and initializer with zero own frames still require eight bytes.

The UBE emitter writes the separate immutable metadata object from those indexed
values. Both object and final-image symbol locations and stored values are
checked independently. All measured code-object hashes remain unchanged through
linking. Actual checked Main returns 129, performs the expected initialization
and Main effects, and preserves Err 77/revision through real Windows setup.
Four report mutations (missing, duplicate, dynamic and inconsistent size) are
rejected. Removing eight bytes from a non-leaf footprint is rejected in both
the metadata object and linked image before executing the altered image.

This gate reuses qualified checked-body outputs whose production source hashes
still match, while compiling current NativeFrames through the component gate.
It does not claim a complete current compiler rebuild from the changed manifest.
The 256-byte reserve is deliberately controlled test data. Object identity and
linked data comparisons do not yet verify every linked instruction/relocation,
call-site adjustment, prologue transient or Windows API stack path. Full flags
do not substitute for source-level debug metadata qualification.

The bounded production readers, symbol inventory and immutable integer-data
consumer now perform these table comparisons directly in UBE;
NATIVE-BINDING-EVIDENCE.md records 192 current comparisons against these retained
objects/images, including understatement rejection. Complete expected-identity
retention and linked instruction/fixup comparison still remain, with this gate
retained as an independent oracle. Derive the complete recovery reserve and qualify startup,
fatal and wait closures before calling the selected design stack-safe. The
native-executable goal, builder integration and refreshed bootstrap remain open.
