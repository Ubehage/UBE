# UBE Compiler v3 progress

The owner clarified source-change policy: UBE does not monitor source changes,
enforce a consistent on-disk snapshot, or reject or retry a build because sources
changed. A build may succeed with unintended behavior in its output. Keeping
sources consistent is the user's responsibility; the compiler remains a reader
of sources and writer of outputs. The native contract, review summary and
failure oracle record this decision. This is a documentation clarification,
not an implemented native-build capability. In particular, a source change
need not cause a compiler error: UBE has no obligation to discover the resulting
program inconsistency.

The combined ordinary-path publication prototype now has a retained 16-case
report in `bootstrap/out/anchored-publication/6918f780254e40e5881399bf3fbd6c58/report.json`.
In-place source edits and replacement saves both succeeded, and publication
preserved those edited source bytes. Initial source/output collisions rejected;
separate late hardlinks could be replaced. The exact command, tested assertions
and limitations are recorded in
`tests/native-executable/REPLACEMENT-PROBE-EVIDENCE.md`. This is host-prototype
evidence, not implemented compiler behavior or complete path qualification.

## Resumed with a new agent - 2026-11-04

The owner requested project orientation and continuation of the unfinished goal.
A bounded goal completed the documented next step: base-relocation validation
and required pointer write/value associations. The full native-executable
deliverable retains all its original obligations. Prior worktree changes are
preserved; no commit or push is part of this continuation.

NATIVE-IMAGE-RELOCATION-IMPLEMENTATION.md defines the exact association contract
and literal independent cases. A direct inspection of all 16 retained images
found two strictly ordered blocks and 49 non-overlapping DIR64 fields per image,
with one zero ABSOLUTE padding entry. The consumer uses one traversal and borrowed
scalar expectations, existing mapping/isolation and inspection budgets. The
implementation now passes all eight qualification gates, recorded in
NATIVE-IMAGE-RELOCATION-EVIDENCE.md: 132 component groups, 34 image groups,
1,568 pointer-field observations and 4,704 rejected image mutations, with all
affected instruction/leaf/unwind/extent/TLS-target gates retained. The final
audit confirms 652 unchanged input paths. Independent read-only review found no
blocking issue. No verification process remains running.

The measured component gate used 943668 ms of child work; its enclosing
bootstrap test allowance is now 1080 seconds, with the 240-second full-probe
allowance and production caps unchanged. A harness-only main-wrapper collision
and its passing rerun are retained in the evidence. The full bootstrap and
final native build remain unqualified on current source.

Next continue the documented global storage alias/residency and register/
control/dataflow obligations, including TLS provenance, trap termination,
CRT callbacks/startup/API effects and the unnamed constructor's function
identity. Complete reserve/stack/debug proof, native tool/build ownership,
warnings/diagnostics/publication and final source-cohort/native acceptance remain
required. Numeric pointer associations alone do not discharge those obligations.

## Earlier pause for a new agent - 2026-11-04T01:31:27.065Z

The owner explicitly requested stopping the active goal to hand over to a new
agent before context exhaustion. The full **First checked native executable**
objective is paused, not complete. Resume only when the owner resumes the goal;
keep its original scope and acceptance requirements intact.

### Last completed checkpoint

TLS storage association is implemented and qualified. Read
NATIVE-THREAD-STORAGE-EVIDENCE.md for the exact seven commands, source hashes,
report paths and limitations. It records 126 component groups (48,258,803
assertions per compiler stage), 4,064 target groups, all 592 TLS-index and 888
TLS-member references through both readers, and 640 new rejected TLS controls.
Instruction, leaf, object/image unwind and extent-binding gates passed. The
verification-only audit confirms 645 distinct unchanged input paths.

Primary reports under bootstrap/out:

- native-objects/8ecde2f7f8c14e389ad2b9dfd3ef4d9a/report.json
- native-code-instructions/7d168a969e0f4a3582ab8310b3d04733/report.json
- native-instructions/8f9b321a4b4741dfba8ab218d60ce95e/report.json
- native-unwind/03b3ae50f2d347a992799ae5bf6f0963/report.json
- native-image-unwind/f1f4f82b655b4bbbb7e62982f4ead257/report.json
- native-extent-bindings/9bc69abe9ea945a79ee433f182ad2e16/report.json
- native-fixups/fa118c9d682e4ebaadd45be7154e8816/report.json
- native-thread-storage-input-audit.json

All verification processes launched for this checkpoint have completed with
terminal results; no running test process needs to be resumed. No commits or
pushes were made. Preserve the existing worktree, including unrelated owner
changes; do not reset, clean or revert it. The full bootstrap and final native
build have not been qualified on the current source.

### Next work and unfinished investigation

The next task is bounded base-relocation validation and association of the
required pointer writes/values. NATIVE-IMAGE-POINTER-INVESTIGATION.md and
bootstrap/out/native-image-pointer-diagnostic.json classify all 49 absolute
fields in each of the 16 retained images. The diagnostic has 18 input identities;
its reproducible Node module is bootstrap/out/native-image-pointer-diagnostic.mjs.
It classifies roles and checks named relationships, not complete rebasing or CRT
behavior. The constructor entry lacks an exact retained target symbol; the
__ImageBase reference intentionally targets RVA zero. Keep those cases explicit.

The current continuation only read code/contracts and the official PE format;
it made no rebasing implementation or test changes. No rebasing contract has yet
been adopted or written. Define that contract and independent literal cases
before implementing the consumer. Reuse NativeObjects directory/span/range and
overlap helpers, NativeBindings contribution isolation, and NativeInspection
byte/event/cancellation accounting. Avoid duplicating those mechanisms.

Investigated design points, still choices to finish rather than implemented facts:

- Validate complete block bounds and DIR64 writes; reject unsupported encodings,
  duplicate/overlapping writes and writes that corrupt relocation metadata.
- Preserve required relocation membership and preferred-base value associations
  for generated cells, initializer entries, TLS fields/callbacks and explicit CRT
  cases. Do not infer safe arbitrary writes from the diagnostic role labels.
- Examine sorted-block/entry traversal and lookup without repeated full scans.
  Check actual tool output and budget consequences before choosing representation.
- The current layout reader does not reject IMAGE_FILE_RELOCS_STRIPPED. The
  rebasing proof must account for that flag. If a shared PE-header accessor is
  needed, extract the existing directory-reader checks and retain their exact
  prior behavior/costs rather than copying the header parser.

Existing full-probe and enclosing test allowances are 240 and 900 seconds;
latest summed component child time was 863958 ms. No production cap changed.
The owner has authorized necessary resource increases; document evidence and
retain acceptance scope if one becomes necessary, rather than asking again.
All shell commands must start with rtk. Node is not on the shell PATH; the
available Node REPL can import the retained audit/diagnostic modules.

### Requirements that remain open

Rebasing and required pointer associations, global storage aliases, TLS
base/index register provenance, full function control/dataflow and termination,
CRT callback/startup/API effects, stack/reserve and debug qualification, native
tool/build ownership, diagnostics and publication, and final source-cohort/native
acceptance remain required. Keep retained frontend/checker gates. Component
qualification is not completion of the deliverable.

The owner-confirmed Err persistence/replacement rule remains frozen. Production
must not monitor, reject or retry source changes; source-identity audits are
verification-only. No language or architectural scope change is approved by this
handoff.

## Native implementation in progress - 2026-11-04

The entries below preserve earlier checkpoint context and then-next actions.
The resumed-goal section above and NATIVE-IMAGE-RELOCATION-EVIDENCE.md record
the latest qualified result and current continuation.

The owner confirmed full Err persistence through success and complete visible-field
replacement by each new error. Section 9, the runtime contract and manual now state
Err.Clear/valid Resume clearing and the distinction from On Error Resume Next.
The shared support already obeys its supported fields; added stale-description/
source controls and public-accessor checks pass the 23-command error gate
9c6c19988df443899daa405a1d356422. ERROR-SUPPORT-EVIDENCE.md records scope.
Resume/trapping execution remains deferred. That confirmation did not change
the native deliverable scope; no production runtime code changed.

TLS storage association now passes 126 component groups (48,258,803 assertions
per stage), 2,240 complete instruction groups, 128 retained-leaf groups and 4,064
target groups. Both readers match all 592 TLS-index and 888 TLS-member references;
all 640 new TLS controls and 3,104 retained target controls reject. The 288 object-
unwind, 32 image-table and 416 extent-binding groups also pass. The complete
metadata oracle uses frozen producer extents and CRT anchors independently of
the directory pointers being tested. NATIVE-THREAD-STORAGE-EVIDENCE.md records
commands, reports, source identities and the unchanged 645-path audit. Component
report: 8ecde2f7f8c14e389ad2b9dfd3ef4d9a; target report:
fa118c9d682e4ebaadd45be7154e8816. Resource caps and test allowances are unchanged.
NATIVE-IMAGE-POINTER-INVESTIGATION.md accounts for all 49 absolute pointer fields
per image, including the earlier 36 unclassified fields. Next implement bounded
base-relocation validation and associate the required pointer writes/values,
then complete register provenance and control/dataflow. Preserve global aliases,
CRT callback/startup effects, stack/reserve, debug, builder ownership and final
acceptance obligations. The original native-executable goal remains active.

At the preceding checkpoint, import-address association passed 108 component groups (46,160,914 assertions
per stage), 2,240 complete instruction groups, 128 retained-leaf groups and 3,424
target groups. Both readers match all 80 import uses against frozen KERNEL32.dll
API names; all 128 new import controls and 2,976 retained target controls reject.
The shared image-directory/span extraction also retains 288 object-unwind,
32 image-function-table and 416 extent-binding groups. NATIVE-IMPORT-EVIDENCE.md
records exact commands, reports, identities and the unchanged 622-path audit.
The component report is 9d30e5d75f1745baac27187da3281caa; the target report is
bd503b8cb0644bc8bd4a6c82e8850be1. Existing production caps and test allowances
remain unchanged. Next bind the TLS index and generated TLS extents to the PE
template, preserving the required register-chain, DIR64/rebasing, CRT callback,
global alias and whole-function control/dataflow obligations. The builder,
stack/debug closure and final native acceptance remain unfinished; the original
native-executable goal stays active.

At the preceding checkpoint, reference-pointer binding passed 102 component groups (44,063,350 assertions
per stage), 2,240 complete instruction groups, 128 retained-leaf groups and 3,296
reference/generated/signed-target groups. Both readers match all 1,880 reference
loads and 3,128 generated references; all 2,976 target/encoding controls reject.
NATIVE-REFERENCE-POINTER-EVIDENCE.md records reports
99ff9f63d8e84eb39de473f50215e55e, 0cc1c410feb94cad90c1cee35e5c45ca,
5195a5c99f604176bd0a49f285ae5d6d and 6c937888715a49abb02b23a217434e4c,
identical LLVM and the unchanged 591-path audit. It retains the failed timeout
and control-routing runs and their corrections. Measured full probes require
test-only 240-second child / 900-second enclosing allowances; no production cap
changed. The independent PE diagnostic passes all 16 images and records
IAT/TLS and DIR64 associations in NATIVE-IMAGE-DIRECTORIES-INVESTIGATION.md. Next
qualify those directory associations, then pointer/register propagation and
complete control flow, preserving image-rebasing and CRT TLS-callback obligations.
The original native-executable goal remains active and incomplete.

At the preceding checkpoint, generated target ownership and extents passed 96 component groups (41,965,983
assertions per bootstrap stage), 2,240 complete instruction groups, 128 retained-leaf
groups and 2,784 generated/signed-target/fixup groups. Both readers match all 3,128
generated function/data/TLS references and reject 2,464 target/encoding controls.
All 42 frozen definitions per image match independent ranges in 32 reader/image
comparisons. NATIVE-TARGET-OWNERSHIP-EVIDENCE.md records reports
c27cd1499b03447ba4d728af35d5364d, 34a0e7e6a8014b39878168aff93cecae,
8bfb9584b23941b786417d6b15abd91b and eaaf678cd8144ab4a9f42e0e2ed67a4f,
identical LLVM, exact costs and the unchanged 572-path audit. Direct generated
transfers require the frozen entry; data accesses must fit frozen storage with
compatible permissions and the ordinary/TLS address domain. Production caps and
the existing 720-second component deadline are unchanged. Next bind reference
cells to generated referents and IAT/TLS-index locations to PE metadata, then
qualify pointer/register propagation and complete function/termination closure.
Global data aliases, resident image storage and production build-owner integration
remain separate required proofs. The complete native goal remains active.

At the preceding checkpoint, signed linked instruction targets passed 92 component groups (39,868,628
assertions per bootstrap stage), the 2,240-group complete instruction gate,
128 retained-leaf groups and 1,856 signed-target/fixup groups. Both readers match
all 5,712 signed targets and reject 1,568 target/encoding controls. The diagnosed
wraparound cases now reject while valid signed limits and negative displacements
remain accepted. NATIVE-INSTRUCTION-TARGET-EVIDENCE.md records reports
1b9f341a7ab04072a058f4a0d59414d4, 17a5c536fc7e40c099c05fac7a6ab716,
5dab04bb5b204b0cba6e21aee7668305 and 6396d3a853e04b70a900bad12a101664,
identical LLVM, exact costs and the unchanged 538-path audit. Production caps
and the 720-second component deadline are unchanged; no full bootstrap is claimed.
NATIVE-TARGET-OWNERSHIP-INVESTIGATION.md records the separate 5,712-reference
census: generated extents, 1,880 reference cells, 80 IAT references and 592 TLS-index
references match their frozen/PE associations. The generated-owner qualification
above completes the entry/extent consumer; pointer associations, full function/
dataflow and terminal closure remain. The complete native-executable goal remains
active and incomplete.

At the preceding checkpoint, instruction relocation-field pairing and original effective offsets passed
90 component groups (37,771,052 assertions per bootstrap stage), 2,240 complete-code
groups and the retained 128-group leaf gate. Both readers pair all 5,712 code
relocations, including trailing-immediate corrections, and reject 1,792 complete-code
controls. NATIVE-INSTRUCTION-RELOCATION-EVIDENCE.md records reports cc7e1c28420e4154827555baf1850308,
92bf72bfae034e46a65364d042255a3e and a5f0e52304704dabab2a23b13a025238,
identical LLVM and the unchanged 262-path input audit. No production cap changed.
The six-case signed-target diagnostic passes through both stages and isolates
three modulo-field counterexamples; NATIVE-CONTROL-FLOW-INVESTIGATION.md records
its exact inputs and results. The subsequent qualification above establishes signed
correspondence; target ownership/extent and complete function flow, pointer, TLS/import
and termination obligations remain required. The full native goal remains incomplete.

At the preceding checkpoint, indirect call/jump target registers were retained in NativeInstruction
without changing its 72-byte size. The missing information was diagnosed at
16 actual r13/rsi call sites. The refreshed 88-group component gate passes
35,672,957 assertions per bootstrap stage; the 1,120-group complete-code gate
matches all 36,192 instructions including target registers and rejects 896
controls. The retained 128-group leaf gate also passes.
NATIVE-INSTRUCTION-EVIDENCE.md records reports
efb15c0840b84e4281880b1a2f05eb2e, e5146e0fa3714fdc90c85a56e24a5061
and e1ca36408f464ebab9a04a849e1ca700.
NATIVE-CONTROL-FLOW-INVESTIGATION.md records the paired relocation/function
diagnostics: 288 trailing-immediate REL32 corrections, 176 initializer-table
references and the O0 self-termination success branch still requiring API proof.
These observations do not qualify whole-function safety. The subsequent field/offset
qualification above leaves signed linked targets and complete control flow required.

At the preceding ownership checkpoint, production contribution ownership passed
86 component groups (35,672,878
assertions per bootstrap stage) and the expanded 2,208-group retained-code gate.
NativeCode enforces anchor consistency and complete object-section coverage;
NativeCodeIndexes checks owner uniqueness and file/RVA nonoverlap through the
existing budgeted sorts. Both readers validate all 16 retained images, with
32 independent-order comparisons and 1,888 rejected controls across the gate.
Index peak/ready/copy costs are 25C/4C/12C bytes; borrowed records remain unchanged.
NATIVE-CODE-OWNERSHIP-EVIDENCE.md records reports
4e22acebba4d44dcae5b06b3a297ec1c and c10b0f11185f4f0a8cd2d3670346edff,
including the corrected C-fixture compile failure. The measured component gate
took 619 seconds of child commands, so its full-bootstrap wrapper now allows
720 seconds; production caps are unchanged. No full bootstrap or native build
owner acceptance is claimed. Next implement whole-function control flow and
effective targets, retaining the qualified ownership checks.

At the preceding instruction checkpoint, canonical INT3 decoding and complete
retained-code instruction comparison passed
pass 82 component groups (33,573,240 assertions per stage), 896 complete-code
groups and the retained 128-group leaf-instruction gate. Both readers match all
36,192 instructions / 146,088 unique code bytes, including 112 CC traps, and
reject all 672 changed-opcode/flow/displacement controls. The decoder classifies
CC as a trap; reachable traps still reject in leaf validation. No termination
closure or full control-flow safety is implied. NATIVE-INSTRUCTION-EVIDENCE.md
records reports 4f86734b35444fa984485dd64992d465,
472014f5cb8c401dbd37dcb403875328 and 8a8f8fd46a074322a63c6d3df1c957dc.
The ownership implementation contract specifies the next production anchor,
coverage and image-overlap checks, with explicit workspace/lifetime accounting
in NATIVE-CODE-OWNERSHIP-IMPLEMENTATION.md. A diagnostic finds 5,224 local jumps
within instruction/function fences and 16 relocated tail jumps requiring
cross-function checks. The full native goal remains active and incomplete.

At the preceding complete-byte checkpoint, whole-code contribution placement
and complete relocated/unchanged-byte comparison passed 82 component groups (33,573,187 assertions per stage), 1,408
retained-code groups and the affected 96-group constant regression. The code
gate observes 224 contributions / 292,176 content bytes through both readers and
rejects 1,120 ordinary-byte, fixup, addend, anchor and overlapping-field controls.
NativeCode consumes frozen retained anchors; common byte comparison and section/
metadata isolation are shared with constant binding. No resource cap changed.
NATIVE-CODE-EVIDENCE.md records current reports ff698de798c642e3b8ee7efd0902eae4,
8a262de376da4271ba740fbebb165d7b and 2bd4783e9cf24224b1f89b1ad2a31d86.
That checkpoint's full-code diagnostic accepted 72,160 instruction observations
with zero length/flow/displacement mismatches and rejected 224 INT3 observations. The 112
CC locations follow calls to ube.stack.abort (96) or ExitProcess (16);
this is a specific decoder/control-flow prerequisite, not proof of unreachable
traps. Next qualify complete-build contribution ownership/anchor consistency and
whole-function instruction/control-flow validation, then the remaining native
stack/debug/tool/publication and final source-cohort gates. The full goal remains
active and incomplete.

Earlier relocation-value checkpoint:

Relocation encoding comparison now passes 78 two-stage component groups
(31,473,972 assertions per stage) and 960 retained-artifact groups: 11,424
field observations and 672 rejected linked-byte/addend/site mutations. All 27
literal vectors, byte mutations, exact budgets, cancellation admissions, root
refusal and forced-result controls pass. Production named/constant target
binders supply the targets; site placement remains an independent test oracle.
NATIVE-FIXUP-EVIDENCE.md records reports fa6477ba667442f3839e1dc11727fdd8 and
b64b5212edb5486c99965b549ca20470, exact commands, hashes and limits. No cap changed.
At that checkpoint, contribution/site placement, overlap/alias policy and
complete byte/instruction correspondence were next.
The complete native-executable goal remains active and incomplete.

Earlier constant contribution checkpoint:

Anonymous constant contribution binding now passes 74 two-stage component groups
(29,376,033 assertions per stage) and 96 actual groups: 16 complete contribution
observations, 32 code-reference associations and 80 rejected mutations. All eight
affected O0 support objects map their complete 31-byte constant sections by unique,
aligned, read-only initialized content. Auxiliary-record validation, duplicate/
overlap and writable-alias rejection, exact resource/cancellation and atomic-output
tests pass. The named-target matrix remains passing at 736 groups with this reader.
NATIVE-CONSTANT-BINDING-EVIDENCE.md records commands, hashes and limits; no numeric
cap changed.

At that checkpoint, the next action was code placement and relocation
value/instruction-byte correspondence. A retained diagnostic covers 112 code sections / 146,088 bytes:
all 5,712 REL32/SECREL fixups and all remaining bytes match. It is implementation
guidance, not production acceptance. Distinct-contribution ownership/alias policy,
pointer cells/imports/TLS, full unwind/stack/reserve, startup/API/refusal/debug,
tool/build ownership, publication and final source-cohort acceptance remain open.
The complete native-executable goal remains active.

Earlier named target checkpoint:


Named relocation target resolution now passes 70 two-stage component groups
(27,276,878 assertions per stage) and 736 actual-object/image groups. All 144
generated objects are compared: 5,696 named code references resolve to independent
image anchors through each reader, while the 16 anonymous section references
explicitly reject. Incorrect expected addresses and missing linked definitions
supply 448 rejected controls. NATIVE-RELOCATION-EVIDENCE.md records exact commands,
identities, resource/failure checks and scope; no numeric cap changed.
The anonymous references share a 31-byte read-only constant section with exactly
one matching occurrence in each affected image. This is a diagnostic lead only.
Next qualify independent anonymous constant-contribution mapping, then relocation
value and instruction-byte correspondence. Pointer-cell/import/TLS, full unwind/
stack/reserve, startup/API/refusal and debug validation, build ownership/tool
launch, publication and final source-cohort acceptance remain open. The complete
native-executable goal stays active.

Earlier complete leaf binding checkpoint:


Complete retained object/image leaf extent and boundary-map binding now passes
66 two-stage component groups (25,178,741 assertions per stage) and 192 actual
binding groups: 112 leaf observations plus 128 independently decodable image
mutations rejected specifically by the binder. The real gate composes retained
names, address indexes, qualified fences and both leaf walks; extents and maps
match the independent object disassembly oracle. Equal-size/equal-instruction-
count but different-map cases, association failures and exact work/atomic-output
controls pass. All preceding index, leaf, instruction, extent/range, data and
retention matrices pass with this reader. NATIVE-LEAF-BINDING-EVIDENCE.md records
commands, identities and limitations; resource caps are unchanged.
Next resolve object relocation targets against retained image definitions and
qualify instruction bytes/fixups. Full unwind/stack/reserve, startup/API/refusal
and debug qualification, build ownership/toolchain wiring, publication and final
source-cohort acceptance remain open. The native-executable goal stays active.

Earlier function indexing checkpoint:

Retained function address indexing and conservative fence lookup now pass the
62-group two-stage component gate (23,081,511 assertions per stage) and 832
independent object/image groups, including 2,880 fence observations and 512
rejected controls. Actual images have unordered symbols and address aliases;
the index prepares order once, releases temporary keys and finds the next distinct
address by binary search. All preceding leaf, instruction, extent, range, data
and retention gates pass with this reader. NATIVE-FUNCTION-INDEX-EVIDENCE.md
records exact reports, identities, work/storage checks and scope. The measured
native-objects test deadline is now 600 seconds; production caps are unchanged.
Next combine the qualified fences and traversal to bind complete object/image
leaf extents and maps to retained definitions, then qualify instruction/relocation
correspondence. Full stack/reserve/debug and startup/API/refusal qualification,
build ownership/toolchain wiring, publication and final acceptance remain open.
The full native-executable goal remains active and incomplete.

Earlier leaf traversal checkpoint:

Bounded native leaf traversal now passes the 58-group two-stage component gate
(18,885,185 assertions per stage) and 256 independent object groups: 112 function
observations, 2,416 reachable instructions and 192 rejected object mutations.
The optimized Err setter's reachable extent is 294 bytes within a 304-byte fence;
multiple returns, loops and trailing padding are handled without a first-RET
shortcut. Exact maps, byte/work/payload bounds, allocation/cancellation/root
refusal, cleanup and large pending graphs pass. All preceding instruction,
extent, range, data, generated-reader and retention matrices pass with this reader.
NATIVE-LEAF-EVIDENCE.md records commands, identities, corrections and limits.
Numeric caps remain unchanged. Next bind the caller-supplied leaf fences and
extents to retained object/image definitions, then qualify instruction and
relocation correspondence. Full unwind/stack/reserve, startup/API/refusal and
debug qualification, build ownership/toolchain wiring, publication and final
source-cohort acceptance remain open. The native-executable goal remains active.

Earlier scalar instruction checkpoint:

Selected scalar AMD64 instruction inspection now passes the 54-group two-stage
component gate (16,785,841 assertions per stage), including 52 independently
specified encodings and bounded failure/resource controls. The actual instruction
matrix passes 128 groups over 32 observed leaf-containing objects: 2,496 instruction
observations and 64 rejected unsupported-opcode mutations. All preceding extent,
range, data, generated-reader and retention matrices pass with this reader.
NATIVE-INSTRUCTION-EVIDENCE.md records exact reports, source/tool identities,
field/cost assertions, test-only corrections and limitations. The production
manifest includes NativeInstructions; the measured reader test deadline is now
420 seconds, with production caps unchanged.
Next implement bounded control-flow traversal that validates branch targets on
instruction boundaries and establishes complete leaf extents. The observed Err
setter has multiple returns and forward/backward branches; first-RET termination
is insufficient. Instruction/relocation equality, complete stack/reserve/debug,
current build ownership and toolchain wiring, publication and final source-cohort
acceptance remain open. This is a scalar decoder qualification, not whole-function
or native-executable completion.

Earlier declared-extent correspondence checkpoint:

Retained declared object/image extent correspondence now passes 50 component
groups (14,687,535 assertions per stage) and 416 actual binding groups: 288 unit
comparisons containing 720 bound extents, plus 128 targeted mutation rejections.
The same reader retains all 288 object-range, 32 image-range, 192 data-binding,
224 generated-reader and 416 definition-retention groups. Preparation validates
the image table once; subsequent binds use a measured logarithmic search and
match the frozen definition's anchors and exact positive code length.
NATIVE-EXTENT-BINDING-EVIDENCE.md records commands, identities, counts, controlled
failures, test-oracle correction and limitations. Numeric caps are unchanged.
Next establish leaf extents and qualify instruction/relocation equality, then
complete unwind/stack/reserve and debug checks. The selected LLVM uwtable
experiment produced no leaf runtime-function entries at either O0 or O2; do not
assume that attribute solves the missing-metadata case. Production build ownership,
current toolchain/bootstrap wiring, publication and final source-cohort gates
remain open. The full native-executable goal remains active and incomplete.

Earlier object/image reader checkpoint:

Declared object and linked-image function extents now pass the 46-group two-stage
component gate (12,590,008 assertions per stage). Independent LLVM comparisons
pass 288 groups over 144 generated objects (720 range observations) and 32 groups
over 16 linked images (2,352 range observations). The 192-group data, 224-group
reader and 416-group retention regressions pass with the same current reader.
NATIVE-UNWIND-EVIDENCE.md records exact commands, identities, measured budgets,
adverse cases and limitations. Image records come from PE exception-directory
entry 3, with unique initialized section containment and ordered nonoverlapping
ranges. The reader test deadline is 300 seconds; its latest summed child-command
time is 194.281 seconds. Production caps are unchanged.
Next bind object and image extents to the same frozen retained definitions,
establish leaf extents and qualify instruction/fixup equality. Full unwind/stack,
reserve/debug, builder/publication and final source-cohort gates remain open.
Object-range checks are registered in the bootstrap; image-range and linked-retention
checks remain maintained explicit commands pending current toolchain integration.

Earlier definition-retention checkpoint:

Production definition retention now passes its two-stage component gate (38
groups, 8,394,970 assertions per stage) and the explicit linked-artifact gate:
416 groups, including 288 unit comparisons and 128 rejected image mutations.
It consumes frozen checked-project identities, preserves optional pre-object
elimination, and requires every surviving definition in the image with matching
type, permissions and expected data span. NATIVE-RETENTION-EVIDENCE.md records
commands, source identities, padding/control-oracle corrections and limitations.
The retained 192-group integer-data and 224-group generated-reader gates pass.
No resource cap or traversal bound changed. Next establish complete code extents,
resolve relocation targets and compare object/image instruction bytes and fixups.
Procedure anchors alone do not qualify code equality, stack or debug safety.
The new linked matrix still needs whole-bootstrap wiring through current explicit
toolchain evidence; builder/publication and final source-cohort gates remain open.

Earlier checked-project expectation checkpoint (before the retention consumer):

The pre-tool expected-linkage inventory is implemented from the immutable lowering
target plan and passes the focused two-stage gate: 34 groups, 6,296,786 assertions
per stage and identical raw output. An independent nine-declaration fixture checks
all 30 expected rows and measures nine work visits, 453 name bytes, 495 inspection
events and 2,992 owned payload bytes. NATIVE-EXPECTATION-EVIDENCE.md records exact
commands/reports, fixed stale loop-record and omitted optional error-helper
defects, controlled failures, resource boundaries and source identities. The retained 192-group integer-data and
224-group generated-reader gates pass. Numeric caps are unchanged; one explicit
expectation pass makes the combined declaration/import bound 4*D+I while lowering
alone retains 3*D+I, under the owner's authorized measured adjustments.
The preceding full-source graph gate passes 350 groups/798 commands, including
actual checked-project inventory construction at jobs 1/2/4 in root/reference
layouts and 144 O0/O2 Full/None object comparisons. Both bootstrap stages emit
identical LLVM and expectation tables. Each layout adds exactly 38 declaration
visits for 54 rows, 647 name bytes, 742 inspection events and 5,808 payload bytes.
Next consume the frozen rows for retained-definition and instruction/fixup
comparisons. Compiler/source producer markers, CU/debug
metadata, complete reserve/stack analysis, builder/publication and final whole
source-cohort gates remain unfinished.

Earlier definition/data binding checkpoint:

Production definition ranges and immutable integer-data binding now pass the
maintained two-stage reader gate (30 groups, 6,293,679 assertions per stage) and
192 actual metadata comparisons: 128 matching frame/reserve tables and 64
understatement rejections in objects and linked images. The retained 224-group
generated-binary reader gate also passes. NATIVE-BINDING-EVIDENCE.md records exact
commands, reports, identities and independent expectations; its implementation
contract is NATIVE-BINDING-IMPLEMENTATION.md. No numeric cap changed. The full
bootstrap now includes native-data-bindings, but has not been rerun here.
Next freeze the complete expected source/linkage identity table from checked
lowering/support emission before tools, then bind retained definitions and check
object-to-image instruction bytes/fixups. Expected code extents, complete recovery
reserve, stack/debug safety, native builder and final source-cohort gates remain
unfinished. The overall native-executable goal remains active.

Earlier inventory checkpoint:

The bounded production symbol inventory now passes the maintained reader gate:
30 groups and 63 commands, with 4,196,129 assertions through each bootstrap stage
and identical raw output. The follow-up generated-input gate passes 224 groups
and 336 commands across 112 retained UBE-produced binaries. Reports are
bootstrap/out/native-objects/d10cca44063e467abf63912c49855440/report.json and
bootstrap/out/native-object-inputs/3325c64aaeb04e76ad7413ba2069630e/report.json.
NATIVE-INVENTORY-IMPLEMENTATION.md defines its ownership and resource contract;
NATIVE-OBJECT-EVIDENCE.md records exact commands, counters, identities, corrected
test expectations and adverse controls. Indexed primary membership, borrowed
cross-arena names, unique definitions and relocation target membership are now
implemented. Shared parser/global payload caps and byte/event/cancellation bounds
remain unchanged. Next bind explicit compiler-owned expected identities to the
inventories, then qualify object-to-image retention and fixup comparisons before
complete stack/debug analysis. Native builder integration, final current-source
bootstrap/checker/resource/performance and retained gates remain unfinished.

Earlier byte-key prerequisite checkpoint:

The symbol inventory's byte-key dependency now supports explicit inspected-byte/
event caps, cancellation and queries from a separate immutable byte arena, using
the existing Core sorter/lookup. The old APIs retain their 4,827,069 assertions
per stage, and the new bounded gate passes 2,103,397 per stage. It demonstrates
the actual need: eight shared-prefix keys require 1,632 read bytes, independently
of the key-count cap. Exact/one-below budgets and every cancellation admission
preserve old results. ../../std-lib/BYTE-KEY-BUDGET-EVIDENCE.md records source,
reports, the corrected root-refusal test expectation and exact commands.
The integrated foundation regression passes 35 groups in
bootstrap/out/semantic-foundations/23c8a21b7b7a4b5d8020784f79499eb7/report.json.
Fresh reader and generated-input reports are respectively
bootstrap/out/native-objects/fcea462e08aa452994b9e6fa3c9f8016/report.json and
bootstrap/out/native-object-inputs/00d02d40103d4cd28ca249bc223a8008/report.json;
26 and 224 groups pass. The new library gate is registered after the legacy one.
The private comparison observers match the shared implementation. The inventory
checkpoint above supersedes this earlier next action; full current-source
checker/resource/performance and complete binding remain pending.

Production binary readers now include borrowed names, primary symbols/auxiliary
extents and selected AMD64 relocation descriptions. The two-stage component
gate passes 26 groups and 55 commands, with 2,098,219 native assertions per stage:
bootstrap/out/native-objects/5555ef1b6da347a7a0634197bd395a5f/report.json.
Both raw outputs match. A further 224-group/336-command gate compares both
readers against the SDK oracle over 112 retained actual UBE-generated objects
and bound images: bootstrap/out/native-object-inputs/9d69205d98f14a47b94055c495a2b06d/report.json.
All captured reader inputs and consumed artifact hashes match. Independent
synthetic cases cover malformed names/symbols, auxiliary skipping, patch/target
bounds, budgets, cancellation, allocator/root refusal and corrupted-output
controls. NATIVE-OBJECT-EVIDENCE.md records commands, hashes, digest limits and
the earlier header checkpoint. Both gates are registered in the full bootstrap;
no production numeric cap changed. At this earlier checkpoint primary-symbol
membership and owned-identity binding were still pending. The inventory gate
above now establishes primary membership; required auxiliary semantics and
complete retention/fixup binding remain open.
Complete binary admission, stack/debug safety and refreshed source qualification
remain pending. All command handles for this checkpoint are terminal.

Immutable frame-data emission now passes the two-stage component gate
(358 groups, 2,097,703 emitter/resource assertions per stage) in
bootstrap/out/native-initialization/1b0d3bc34a644986853863443ae457a8/report.json.
The new test-owned object/data binding gate passes 36 groups and 548 commands in
bootstrap/out/native-frames/157eecd5aacd410fade78655207ec826/report.json:
16 stage/reference/O0-O2/Full-None combinations, exact indexed frame metadata,
static/unwind/leaf agreement, unchanged measured objects, linked values, actual
checked Main through real Windows entry, and report/understatement controls.
NATIVE-FRAME-IMPLEMENTATION.md records the commands, hashes, retained harness
corrections and limits. The reserve is still controlled at 256 bytes; production
binary inspection, linked instruction/fixup checks, call-site/prologue analysis
and complete reserve/startup/API safety remain unfinished. Next implement that
bounded production inspection and binding, then derive and qualify the complete
reserve and entry closures. The new gate is registered in the full bootstrap.

Windows stack initialization, fatal disposition and module wait now have a
production UBE emitter and pass the expanded two-stage component gate:
bootstrap/out/native-initialization/0e93680c383b42ebb2e2379d6ce0b931/report.json,
358 groups, 1,094 commands and 2,097,617 emission assertions per stage.
Both stages emit identical LLVM. NATIVE-PLATFORM-IMPLEMENTATION.md records
synthetic malformed-query/capacity/publication controls, independent real Windows
page oracles, actual fatal/wait observations and O0/O2 Full/None common-entry
integration with controlled frame/reserve data. No production resource cap changed.
The expanded test takes about 281 seconds, so its bootstrap harness deadline is
420 seconds. The freshly compiled whole checked-project regression also passes
194 groups and 510 commands in
bootstrap/out/native-graph/927756dfc68f45b8b2f9770a039ca4e8/report.json.
Both raw outputs match and all captured inputs remain unchanged. The six-group
import-work gate also passes on this cohort in
bootstrap/out/native-import-emission/79e6ca71228c43aca181c047c5819b48/report.json.
All command handles are terminal. A refreshed full bootstrap remains pending. Next bind complete frame footprints to exact non-LTO
objects, derive the recovery reserve and qualify startup/API and refusal closures.
The native builder/debug/publication acceptance remains unfinished.

Common program entry and the ordinary process adapter now pass 224 focused
initialization/entry groups and 194 checked-project groups. Reports:
bootstrap/out/native-initialization/19d3709230a240c388e6dd12d886489f/report.json and
bootstrap/out/native-graph/b876b8cda4074d529bae08d26cc66f3b/report.json.
The latter reuses one completed hash-pinned compiler invocation and reruns all
current native oracles across both stages. NATIVE-ENTRY-IMPLEMENTATION.md records
commands, exact identities, two retained harness failures/corrections and scope.
Ordinary and observed adapters share the same startup/init/Main sequence; O0/O2
checks cover no user entry on setup failure, initializer failure, Main refusal,
Sub/Long results, signed Windows exits and preserved/set Err. Actual Windows
stack setup was still controlled at that checkpoint; the implementation above
now supplies real Windows setup. Complete frame/reserve metadata remain unqualified.
The six-group import-work gate is retained on this cohort in
bootstrap/out/native-import-emission/6660a403ad7944f681f520bb041642f1/report.json.
The subsequent platform implementation above advances that checkpoint; complete
startup/frame/reserve/fatal/wait safety still precedes native builder acceptance.

Per-module output/imports now pass 154 two-stage graph groups and 342 commands
in bootstrap/out/native-graph/a04adb0a0941407f8d1e63c4c31930cb/report.json.
Independent module objects preserve O0/O2 scalar/native/ByRef and initialization
behavior. The actual import-work regression passes six groups and 56 commands
in bootstrap/out/native-import-emission/b805c56cc1f8443badedd1b25f070db2/report.json:
126 own plus 210 import visits, total lowering work 2,925, exact-cap success and
controlled failure at 2,924, with unchanged inputs and complete cleanup.
The focused index gate passes 26 groups. NATIVE-MODULE-IMPLEMENTATION.md records
commands, hashes, qualification scope and full-bootstrap registration. Numeric
caps are unchanged. The subsequent entry control-flow qualification is recorded
above; real platform stack/wait and the full native builder remain unfinished.

The owner has approved the documented 3*D declaration-work correction.
NATIVE-RESOURCE-CONTRACT.md, NATIVE-DECLARATION-WORK-REVIEW.md and RESOURCE-ORACLES.md
now record preparation/signature/entry-storage accounting with unchanged caps
and body/argument bounds. Earlier pending-review statements below describe their
historical checkpoints. The owner subsequently approved typed-import work I
and authorized any further necessary increases, with measured accounting.
The adopted total is 3*D+I, where I <= V+A+1; numeric caps remain unchanged.

Normal initialization scheduling is implemented and its component gate passes
118 two-stage groups, including 2,097,396 emission assertions per stage, O0/O2
native order/failure tests and required helper inlining. Report:
bootstrap/out/native-initialization/5253acf4ac2b45668f302f77991e20a5/report.json.
The adapter validates canonical checked package/source metadata in M visits,
then emits M requirements in library-before-root manifest order, with no scratch
payload, declaration scan or extra body walk. The whole checked-project gate also
passes 118 groups and 238 commands in
bootstrap/out/native-graph/794008b5eaad41528377963bf5c9b8d8/report.json, with 967 graph
and 2,107,571 body assertions per stage. Actual one-package/direct-reference
projects pass O0/O2 order, completed-dependency, Main-result and failure checks;
jobs 1/2/4 preserve bytes/work/identities. Both raw LLVM images are identical.
All handles are terminal. NATIVE-INITIALIZATION-EVIDENCE.md records commands,
hashes, retained controls and the combined-unit/controlled-frame observer limits.

The concrete foreign-import counterexample now passes actual retained checker
and declaration inventory assertions at jobs 1 and 4: 42 declarations, 93 own
visits plus 210 necessary typed-import visits, already exceeding 3*D = 126.
The report is bootstrap/out/native-import-work/b37361a2198c4ae4977be7688244d189/report.json.
NATIVE-DECLARATION-WORK-REVIEW.md proposes a separately counted import allowance
I <= V+A+1, with no change to caps or body/argument traversals. That addition
is now approved and the qualified per-module results are recorded above.

Foreign access and required-module failure propagation now pass the maintained
two-stage graph gate: bootstrap/out/native-graph/1d61ea91bdbd4e3f9bfb6bc15df92ed0/report.json,
94 groups and 190 commands, with 967 graph and 2,107,242 body assertions per stage.
Both raw LLVM images are identical. O0/O2 observers and three new negative controls
qualify actual checked three-module bodies with the shared initialization helper.
Reads/writes guard actual foreign storage,
calls guard after argument evaluation, exact unused ByRef forwarding does not
dereference, and ordinary calls check the failure latch after their result merge.
Failed requirements return neutral/void/false immediately. The shared frame table
now consistently includes ordinary, initializer and wait slots (F+M+1).
The new three-source guard-project passes historical checker admission at jobs
1 and 4, and the combined C body fixture passes strict syntax checking.
The retained first run stopped at a missing target triple in the test-only data
output; its correction changed no production source. The focused diagnostic and
fresh full gate then passed. All handles are terminal. Exact commands, hashes,
failure record and scope are in NATIVE-INITIALIZATION-EVIDENCE.md. The body owner
remains 64 bytes, with no additional graph/declaration traversal or scratch payload.

Next complete per-module output/import declarations and the ordinary process
entry consumer of the qualified schedule. The integration fixture combines bodies into one test unit,
uses controlled frame metadata and observes entry to a test wait function. Actual
stack footprints, platform waiting, normal process startup, warning presentation,
tool/path/debug/CLI/publication and full source-cohort acceptance remain unfinished.
The full goal remains active; complete lowering resource acceptance is pending.

Checked module initializer body emission now passes the fresh two-stage graph
gate: bootstrap/out/native-graph/e865f6e060bf48f9a85ea8abb6b0a09b/report.json,
76 groups, 967 graph and 2,106,947 body assertions per stage. O0/O2 observers
check declaration order, neutral reset, forced/default ByRef slots, actual Err
and recoverable ordinary-call refusal; two altered initializer controls fail as
required. Jobs 1/2/4 match bytes, work and identities, and the two raw LLVM files
are identical. Earlier scalar/native/call LLVM remains byte-identical.

NativeGraph now retains a bounded per-module procedure-root index during the
existing planning walk. NativeTraversal can defer a procedure subtree after its
edge event, preserving live depth/pending accounting. The 104-byte graph owner
adds 4*min(F,V) payload, with controlled invalid-identity, allocation/root failure
and cleanup coverage. The component gate passes 26 groups and 8,437,455 assertions
per stage in bootstrap/out/native-emission/910aaae70fbc41f296342ef8a78c172e/report.json.
Exact commands, hashes and limits are in NATIVE-INITIALIZATION-EVIDENCE.md; the
implementation contract describes shared cursor/temporary ownership. All test
handles for this checkpoint are terminal.

That 76-group checkpoint preceded the shared-state and schedule integration qualified above.
Its single-module observer directly invokes one initializer with controlled frame
metadata; its evidence remains body-only. Current next work is per-module output,
imports and package/source scheduling, followed by the remaining native boundaries.

Private ByRef owner transport now passes the current two-stage native graph gate:
bootstrap/out/native-graph/43e9a0e0382e45a784c743445d52d4eb/report.json (64 groups,
926 graph and 2,106,631 body assertions per stage). The emission gate passes
26 groups and 8,437,370 assertions per stage in
bootstrap/out/native-emission/49c3d6afaff545bc915ac38cf5454c51/report.json.
Exact commands, source identities, owner-corruption controls and the corrected
LongLong identity boundary are in NATIVE-IMPLEMENTATION-EVIDENCE.md. The private
ABI carries one i32 owner after each ordinary ByRef pointer, with no additional
plan payload or declaration scan. Global, local, temporary, named, aliased and
recursive forwarding cases preserve their independent value/Err expectations.

Ten independent initialization fixtures were added and admitted by the historical
checker at jobs 1 and 4 (126 additional admission checks total). Their required
runtime results and wait observations are in tests/native-executable/ORACLES.md;
those runtime outcomes remain unverified. A focused generated-code probe then
exposed a local declaration reset failure: three loop executions of a self-
initializer returned 3 instead of 1. The retained before-report is under
bootstrap/out/native-body-diagnostic/declaration-reset/. NativeBodies now emits
neutral storage on declaration entry before initializer children, and the
maintained body fixture includes the regression. Its fresh graph gate above
passes all 64 groups through both stages and O0/O2; raw LLVM is byte-identical.
The exact maintained observer rejects the retained pre-fix emitter, with sources
and outputs preserved in declaration-reset/maintained-before/. All commands
started for this checkpoint are terminal; no test process remains live.

The later shared-state integration is qualified at the top of this section.
Package/source startup order, actual platform wait, linked stack metadata/startup,
tool/path/debug/CLI/publication and final source-cohort acceptance remain unfinished;
the goal remains active.

The module-initialization shared data and per-output inline access helper now pass
54 focused two-stage groups in
bootstrap/out/native-initialization/5b66b3fa15104fec9230f1fcf8255369/report.json.
Command: `rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/initialization/check.ps1 -DiagnosticOnly`.
Ten native modes run at O0/O2 with two helper units sharing one data unit; four
negative controls check state, admission, shared ownership and actual work.
Resource probes pass 2,097,299 assertions per stage, including real root pressure
and exact cleanup. NATIVE-INITIALIZATION-EVIDENCE.md records identities, retained
fixture failures and limits; NATIVE-INITIALIZATION-IMPLEMENTATION.md records the
ownership/ABI integration contract. NativeInitialization is in the manifest and
its gate is registered with a 300-second bootstrap deadline.

Next connect checked initializer bodies and foreign accesses to this helper,
using the now-qualified private ByRef owner transport. Emit module declarations in written order and the normal
package/source schedule; propagate initialization failure through generated calls
before entering Main. The actual platform wait, stack metadata/startup and final
source-cohort gates remain unqualified. Tests currently use controlled C bodies
and frame metadata. This is support qualification, not complete runtime integration.

Checked-source initialization-warning discovery and conservative ByRef propagation
now pass the fresh two-stage gate. Command:
`rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/warnings/check-sources.ps1 -DiagnosticOnly`.
Report bootstrap/out/native-warning-sources/c4f0f07a56b740d4ac45426d4363e0cc/report.json
passes six groups and 2,108,156 assertions per stage over 23 source cases
(22 accepted, one exact UBE1417 rejection), jobs 1/2/4, independent dependency/span
oracles, actual work/pending/payload, cancellation/allocation/root pressure and
negative controls. Both fresh raw LLVM images are identical. The source admission
gate separately passes 46 historical-checker process checks. Exact identities,
scaling results and retained failures are in NATIVE-WARNING-EVIDENCE.md.

NativeDependencies uses private compact procedure/formal queues, forwarding edges
and the existing explicit cursor. It preserves immutable checker/catalog/source
owners. Omitted defaults retain their declaration-source identity; a focused
regression exposed and corrected the walker's overly strict source check.
NativeDependencies is in the production manifest and check-sources.ps1 is registered
in the full bootstrap with a 1200-second deadline. The gate uses pinned historical
df158 tools; the updated full bootstrap and final source-cohort gates have not run.

Continue integrating and qualifying runtime module initialization, including foreign
read/write/call guards and accesses through forwarded ByRef aliases, under the
reviewed runtime and stack contracts. Warning presentation, native tool/path/debug/
CLI/publication and final retained gates remain unfinished. Real linked stack
footprints/startup/recovery remain unqualified. The declaration-bound proposal
still awaits owner review; the accepted bound remains 2*D.

The declaration plan now assigns a dense ByRef-formal index during its existing
one-pass preparation. ByVal/nonparameter targets remain -1; applicable intrinsic
formals are included. The new index/count occupy existing padding: target/owner
sizes remain 72/24 bytes, with unchanged work and emitted target identities.
This is the compact scratch prerequisite for checked-source alias propagation.
The current focused emission gate passes 26 groups and 8,437,320 assertions per
stage in bootstrap/out/native-emission/e64ec7bd54ad4f71a708c3baba97b806/report.json.
The real-checker gate passes all 54 groups in
bootstrap/out/native-graph/b176a0690d4a42958d6dd27a1e7d9791/report.json:
926 graph and 2,106,566 body assertions per stage, retaining O0/O2 observers and
negative controls. Scalar/native/call body LLVM is byte-identical to the earlier
qualified outputs below. Both commands terminated with exit 0; no process
remains live. Exact identities and scope are in NATIVE-IMPLEMENTATION-EVIDENCE.md.

Ordinary guarded calls and exact/forced/default ByRef argument storage now
pass the focused full-source gate. Command:
`rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/graph/check.ps1 -DiagnosticOnly`.
Report `bootstrap/out/native-graph/6b1625f5e6604895b4fed4a4ab14311e/report.json`
passed all 54 groups: 833 graph and 2,106,566 body assertions per stage, plus
O0/O2 native observers and three changed-output controls. Both 7,205,461-byte
raw images have SHA-256
`87717CAC8E0CDFA17C569E6624D35A84B09C9FD99C11261F41E343F3C653CDA6`.
The new 20-procedure call fixture covers named/written order, exact aliases,
forced/default ByRef slots reset on each evaluation, recursion, native aggregate
returns and Err 6/11/28 ordering. All seven controlled admission/fatal modes
pass at O0/O2; the inverted guard fails at its independent observer. Output
and charged work match across jobs 1/2/4. Earlier scalar/native body LLVM stays
byte-identical. The run is terminal; no test session remains live.

The component gate also passed 26 groups and 8,437,298 assertions per stage in
`bootstrap/out/native-emission/f6728e8cdba5433db9726b81f5a98205/report.json`,
with identical 1,140,677-byte raw LLVM (SHA-256
`32F397DCF694493FFF7FA6AC2D25FE4434FA010B85FFB55269A80EDB209DBBAD`).
Targets retain a dense ordinary-procedure frame index; graph preparation assigns
forced/default ByRef temporary slots in the existing argument pass. Current
layouts are 72 bytes per target, 24 per declaration plan, 20 per node link,
24 per argument link and 64 per body owner. Entry reserves fixed temporary
slots; argument effects precede admission and formal-order call operands.

These DiagnosticOnly gates use pinned historical df158 tools and current source
inputs. They do not qualify a final source-built cohort or native builder.
The call observer supplies controlled stack metadata: linked frame sizes,
recovery reserve, committed-floor startup and the production fatal adapter
remain unqualified. Cross-module initialization, including dereferences through
forwarded ByRef aliases, is the next integration concern. Warning presentation,
native tool/path/debug/CLI/publication and final retained gates also remain.
The declaration-bound proposal still awaits owner review; 2*D remains the
accepted bound and whole-lowering resource acceptance is not claimed.
The earlier graph attempt `1db0d68198ff461f9bfe2245ce215323` was explicitly
interrupted before testing because harness binding insertion failed; it is not
a pass. Exact evidence and limitations are in
`NATIVE-IMPLEMENTATION-EVIDENCE.md`.

The warning matrix/component/witness consumer now passes six focused groups and
2,098,158 assertions per stage in
bootstrap/out/native-warnings/8ea86280022b4654bef0249028983c9a/report.json.
The revised Core component gate passes six groups and 2,175,517 assertions per
stage in bootstrap/out/graph-components/5425f3efa1344f55b5fed0f5007e6865/report.json.
It checks pending admission before each push and returns actual live/peak counts,
allowing the compiler to share a pending budget with other owners. Independent
witness/transition observations, boundary/failure/cleanup and negative controls
pass. Exact commands, hashes and limitations are in NATIVE-WARNING-EVIDENCE.md
and std-lib/GRAPH-COMPONENTS-EVIDENCE.md. Both modules are now in their production
manifests. Both gates and the checked-graph lowering gate are registered in the
full bootstrap; the updated full bootstrap has not run.
The later checked-source discovery qualification is recorded at the start of this
section. Runtime initialization and warning presentation remain unfinished.

The following paragraphs retain earlier checkpoints; their then-next actions
are superseded by the current state above.

The graph's per-node index now retains the inverse argument association in its
existing single map pass (16 bytes per node, previously 12). Child conversion
consumes that association before the next argument. Pack/Unpack and
same-nominal native equality now connect to the ordered procedure consumer.
The component gate passes 26 groups and 8,437,288 assertions per stage in
`bootstrap/out/native-emission/8dc775b64a2d4f1db09d2e4fc09c5931/report.json`.
The full-source graph gate passes 24 groups in
`bootstrap/out/native-graph/bbc5d65e69cf46ab98c9b861f2092adf/report.json`:
800 graph and 2,106,249 body assertions per stage, including 19 additional
checked native-value procedures and O0/O2 ABI/value/Err/ByRef observations.
An inverted actual native equality predicate is rejected by the independent
observer. Raw compiler LLVM and emitted programs match across stages and
jobs 1/2/4; the earlier scalar-body output is unchanged. Both runs are terminal.
These remain DiagnosticOnly focused proofs, not final source-cohort or native
builder qualification. Ordinary guarded calls, exact ByRef argument addresses
and forced/default ByRef temporary storage are the next integration work.
The separate declaration-bound review remains pending. Exact commands,
identities and retained test-fixture failures are in
`NATIVE-IMPLEMENTATION-EVIDENCE.md`.

Bounded graph preparation now uses one argument-map pass, retaining the reviewed
second visit for emission. Scalar LLVM constants, checked conversions and
integer/Boolean arithmetic fragments pass the focused two-stage native gate.
Real-checker integration passes 514 assertions per stage with jobs 1/2/4,
including unchanged graph/facts and native execution of retained conversion
facts and mixed LongLong/Long arithmetic nodes at O0/O2. The later declaration
index and scalar/native storage components now pass focused two-stage native
tests, including allocation denial, cancellation, root pressure, neutral
storage and ByVal/ByRef behavior. Real-catalog integration passes 761 assertions
per stage; its 31 declarations produce 56 stable target identities in one scan,
with identical index bytes across jobs 1/2/4.
The ordered procedure consumer now emits eight actual checked procedure
subtrees, including entry storage, assignments, While/Exit, ElseIf and nested
short-circuit expressions. The expanded graph gate passes 18 groups through
both stages: 761 retained graph assertions and 2,105,842 body assertions per
stage, predominantly real root-registry fill/drain checks. Independent native
value/Err/ByRef observations pass at O0/O2, and a mutated short-circuit result
is rejected. Report `ef1c2d437ec34098a6fac7594689ecf2` records exact inputs.
The body walk charges exactly 2*V+E; declaration signature/storage loops still
need their combined work-accounting audit before whole-lowering bounds can be
claimed. Calls/ByRef temporaries, module
initialization, native CLI/tool/publication and final source-cohort qualification
remain unfinished. Exact reports and scope are in
`NATIVE-IMPLEMENTATION-EVIDENCE.md`.
The declaration-work audit reproduced 33 uncharged definition visits in the
eight-procedure fixture. Those visits are now charged and the focused old-code
control fails as expected. The two-stage graph rerun passed all 18 groups in
`bootstrap/out/native-graph/b4674599705a458ab587e2e4c027d93b/report.json`, with
761 graph and 2,105,845 body assertions per stage. Generated program LLVM is
unchanged. An expanded zero/early/below/exact/above work-limit probe also passed
2,105,999 assertions against each retained current adapter and was promoted
byte-identically to the maintained probe; its exact commands and identities
are in `bootstrap/out/native-body-diagnostic/declaration-work/boundary-report.json`.
These focused results do not replace final source-cohort qualification.
All runs from this checkpoint have finished; no session remains live.
`NATIVE-DECLARATION-WORK-REVIEW.md` records the concrete 56-versus-46 visit
counterexample and proposed 3*D bound. Owner review is pending; the existing
2*D contract remains authoritative and whole-lowering resource acceptance is
not claimed.

The explicit checked-graph cursor also passes the expanded two-stage diagnostic
gate: exact enter/edge/exit order, repeated occurrences, bounded depth/work,
actual continuation copying, allocation/root pressure, malformed edges and
cancellation. Its regression caught and fixed a stale success diagnostic after
a successful poll. Report `76def9a223584ab0bf2e554babcb884c` and the retained
failure are recorded in `NATIVE-IMPLEMENTATION-EVIDENCE.md`. These tests build
synthetic instances of the actual BoundNode layout; the cursor is not yet
connected to end-to-end checked-program LLVM generation.

The bounded byte writer now passes its focused two-stage diagnostic gate,
including exact file read-back, actual allocation/copy/resource/cancellation
observers, decimal encoding through independent native workers, and two defective
writer controls per stage. Its fixture emits LLVM that links and returns 37;
it does not yet consume the checked graph. The new generic decimal encoder and
ByteBuffer release operation live in UBECore. Exact commands, source identities,
retained diagnostic failures and scope are in `NATIVE-IMPLEMENTATION-EVIDENCE.md`.
The gate is registered for the next full bootstrap; current-source qualification
is still pending. The next integration action is checked-graph lowering.

The shared error-support dependency is extracted into
`bootstrap/runtime/error_support.c`, included by the existing runtime and
compiled independently for scalar output. Bounded recording and the specialized
Err 28 setter pass focused record, existing-caller and Full/None linked/TLS
gates. Exact commands, retained reports, failed initial compilation and scope
are in `ERROR-SUPPORT-EVIDENCE.md`. The first full run,
`bootstrap/out/v2/10a74762c73e4481bbcd57e3d3fb9724/`, failed because the
caller-retention test's private runtime copy omitted the extracted include.
The caller-retention and root-registry copy lists now include both new runtime
files. The retained failure is not a passing qualification.

The complete rerun
`rtk proxy powershell -NoProfile -File bootstrap/build-v2.ps1` exited 0 with
914 acceptance assertions. Cohort `df15817344774026bebebfd1e9ae8eaf` has manifest
SHA-256 `A8573742189253D557AD7527084E44C6A7E0ED56A937215DAF5EC8A083129445`.
This qualifies the extracted runtime and counted-output bootstrap dependency
with its retained source-input/scanner/project/concurrency gates. The run has
finished; no bootstrap session is live. The subsequent checker correction and
native resource-module integration below are later source changes and still
need the final source-cohort and retained frontend/checker gates.

`std-lib/FILE-OUTPUT-CONTRACT.md` specifies the write/flush dependency.
The smallest declaration-only probes reproduce the absent File.TryWrite and
File.TryFlush bindings through both newly built candidate stages: exit 1,
UBE3230, no LLVM. The exact command is
`rtk proxy powershell -NoProfile -File bootstrap/out/file-output-admission/check.ps1`;
its report records source/tool identities. This only diagnoses missing roles,
not qualification of those candidate stages. The bounded declarations, role
validation and native writer now pass their 19-group direct/two-stage gate;
`../../std-lib/FILE-OUTPUT-EVIDENCE.md` records exact byte, partial-write,
failure, ownership, cost and concurrent-owner checks and five defective controls.
The new names are now in the fresh checker's known-but-deferred primitive list.
The exact promoted SemanticDeclarations source matches the isolated correction
that passed 28 source/project checks through each stage; its SHA-256 is
`803D9B0EB8FBAB8C0F3DE6118DB54CEE5BBF6061B4CA3BC85A3DC916924E9437`.
The maintained semantic CLI gate now includes that regression. Guarded
creation, lowering and native-tool/publication integration remain unfinished.

The new scalar native resource-accounting module passes 157 native boundary
assertions through each source-built stage with byte-identical raw LLVM. It is
now in the compiler manifest, with its focused gate registered in the bootstrap
runner. `NATIVE-IMPLEMENTATION-EVIDENCE.md` records
the exact command, report, bootstrap-subset correction and remaining integration
and actual-emitter measurement obligations.

## Current design decisions - 2026-11-03

The bounded contract preparation and review is complete. Final selections are
in `NATIVE-PATH-CONTRACT.md` (path domain and guarded acquisition),
`NATIVE-STACK-REVIEW.md` (cached committed floor, linked-code reserve derivation,
startup/fatal dispositions), `NATIVE-BUILD-DIAGNOSTICS.md` (delivery ownership
and deadlines), and `NATIVE-DEBUG-CONTRACT.md` (finite Full admission).
They supersede the earlier open-decision statements retained below. No
production backend or complete host qualification is claimed. Implementation
must pass the main contract's separate acceptance checklist.

Next action: connect the bounded writer and explicit traversal to checked-graph lowering,
then the reviewed native path/tool/stack/debug/publication behavior. Shared
error support and counted byte output have passed the 914-assertion bootstrap
cohort; the later checker, resource, writer and traversal changes still require
final integration gates.
Keep the independently authored native, ABI, error, resource and publication
oracles; do not replace them with the emitter's own expectations.

The focused test-only CU identity probe returned 0 with nine mutation controls;
the exact command and hashes are in
`bootstrap/out/debug-unit-identity/45630dbae446496a9f6b9ba21c9602ff/report.json`.
Root checked the retained Full/None, script and all nine control hashes against
that report. It covers PE long names, CU framing/root identity and selected
offsets only; production DIE/line/value checks remain unimplemented.

### Earlier preparation records

The earlier audit separates preimplementation decisions from backend acceptance:
the plan requires reviewed contracts before code, not a working backend before
its design can be completed. The main contract now has separate checklists.
`NATIVE-RESOURCE-CONTRACT.md` selects serial lowering, bounded maps/traversal,
one reusable ByteBuffer, and explicit initial caps: 256 MiB cumulative raw LLVM,
256 MiB accepted candidate length, 1 GiB owned lowering payload, 1048576 pending
entries, depth 256, 4194304 target identities and 268435456 work events.
These are engineering policy choices, not measured usage or total RAM/disk
limits. It accounts for both ByteBuffer snapshot copies and resize overlap;
the counted byte writer remains a UBECore/minimal-host dependency to qualify.
The resource oracle now distinguishes this serial baseline from conditional
future parallel-lowering barriers, retaining existing frontend concurrency gates.

Nontransactional extended handle rename is selected as the core publication
direction on the combined ordinary-path evidence above. Full name/reparse
acquisition policy and production integration are still open. The review goal
also still needs complete stack strategy/reserve, bounded diagnostic delivery
and the finite production Full-debug check. Tool identity/deadline and argument
policies are now selected below; their common path prerequisite remains open.
No production backend or native executable capability is claimed. These
selections supersede earlier statements below that all lowering resource
choices or the core publication primitive are still undecided.

Read-only peer review checked resource units/ownership against the adopted
ByteBuffer API and checked consistency across the main review and workplans.
It found and prompted corrections for two-copy snapshots, conditional parallel
oracles, cancellation inside whole-buffer primitives, and stale measurement
prerequisite wording. `rtk proxy git diff --check` passed; a trailing-whitespace
scan of the new/updated native contracts and resource oracle returned no matches.
These are document checks, not emitter/resource acceptance tests.

### Runtime boundary and linked-support evidence

`NATIVE-RUNTIME-CONTRACT.md` now selects the private Err boundary and test
observer. It preserves the existing native TLS record and set/read/clear
semantics, requires one shared error unit extracted from the current bootstrap
runtime, and states the temporary support's replacement condition. The ordinary
and specialized Err 28 recording paths must have closed bounded machine-code
footprints; the current setter's CRT calls do not establish that property.
The final-Main observer and one-checkpoint-per-run typed record have distinct
formats, preventing ambiguity over multiple records or wide scalar results.

The new maintained host audit uses the explicit support cohort and constrained
environment. Command:
`rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/verifier/check-linked-error-support.ps1 -SourceReport bootstrap/out/explicit-link-inputs/318209f12b5b4f0282acf596c47e6386/report.json -OutputDirectory bootstrap/out/linked-error-support`.
Observational mode passed with report
`bootstrap/out/linked-error-support/f9fdcfd73ce6416096538c7517e6135f/report.json`:
the three-width LLVM remainder bridge and overlapping native TLS/clear checks
passed, while wrong-error and wrong-thread controls returned 1. Minimality did
not pass: section GC retained 28 UBE symbols, 24 outside the error-only allowlist;
four library exports retained unrelated support. The no-GC control retained
301/297. Adding `-RequireMinimal` correctly failed with exit 1 and report
`bootstrap/out/linked-error-support/a8148ba056704c9b9c223548adf66be8/report.json`.
Exact identities, scope and limits are in `tests/native-executable/ERROR-ORACLES.md`.

This evidence rejects the whole-runtime-link recipe. It does not implement the
shared error unit or qualify UBE emission, all header dependencies, stack safety
or the production launcher. The next stack candidate caches a startup-established
committed floor and removes per-call OS queries; its host invariant, complete
metadata/entry accounting and startup/fatal failure path still need decisions.
The rest of the preparation remains active: publication name/reparse domain,
bounded diagnostic delivery and finite production Full-debug checks.

### Tool identity, arguments and lifecycle decisions

`NATIVE-TOOL-CONTRACT.md` selects the executable/non-OS-dependency binding scope,
trusted Windows loader/system boundary, exact CRT-style quoting and strict
UTF-16 argument transport. Initial caps are 1024 argument tokens and 32767
UTF-16 code units for the encoded command line (including its NUL) and explicit
environment block (including its final double NUL). Compiler-generated output
paths are separate absolute arguments. Qualified driver-internal response files
belong to the owned temporary/tool tree and require a second-hop argument test;
no source-supplied response file or oversized-launch fallback is introduced.

Defaults are 600000 ms per invocation, 5000 ms completion grace, one shared
5000 ms stop/drain deadline and controller waits at most 50 ms. These are
algorithmic policies, not guaranteed Windows syscall/real-time return limits.
The selected capture uses overlapped reads and retains any unresolved I/O owner
until completion. Only one uncertain invocation may remain; subsequent tool
admission fails until it is reaped. No separate executor/pool is introduced.
Setup failure never resumes an uncontained child; uncertain cleanup never
permits publication or freeing a pending read buffer.

The diagnostic contract now distinguishes secondary containment failure from
drain failure after a cancellation/child-failure primary. `diagnostics.json`
has 24 independent future vectors, adding both uncertain-stop cases and the
`lowering-work` category, which distinguishes cumulative visits from live
pending entries. Earlier 21-vector statements below describe that checkpoint.
Failure oracles now include exact encoded/count/environment boundaries,
driver-to-linker transport, before/at/after deadline observations, delayed I/O
cancellation, retained-owner admission and later successful reaping. Existing
synchronous-reader/hand-authored argv probes do not qualify those production
paths. Common path acquisition, stack recovery and diagnostic/debug completion
remain design work; no native launcher is claimed implemented.

Read-only peer review found and resolved an omitted secondary `drain` outcome
when processes are stopped but capture cleanup remains pending. Deadline ties
are explicitly timeout at equality; latched completion is not revoked later.
Direct `llvm-readobj --coff-imports` inspection of the pinned Clang/LLD files
found only Windows-system names in their direct import descriptors; exact
commands/hashes and the transitive/dynamic-load limitation are in the tool
contract. A PowerShell `Get-Content -Raw .../diagnostics.json | ConvertFrom-Json`
data check asserted 24 unique names, string output/condition fields, exits in
0/1/2/4 and no CR in the LF-only vectors; all assertions passed. This validates
data shape, not diagnostic behavior. `rtk proxy git diff --check` passed, and
the native tool/main/diagnostic/failure documents and vectors had no trailing
whitespace matches. Production launcher/capture/deadline tests were not run
because that boundary is unimplemented.

## Earlier qualification and contract review - 2026-11-02

The main contract now selects explicit startup/archive resolution and a child
environment allowlist. `--no-default-config`, `-nostdlib` and COFF
`/nodefaultlib` suppress the tested ambient config/library discovery routes.
LLD uses `--threads=1`, which is not an OS-thread or total-memory cap.
`tests/native-executable/verifier/check-explicit-link-inputs.ps1` recompiled
retained LLVM and linked the recorded 13-file support cohort in Full/None.
Both object/executable hashes matched their earlier controls and exit was 7;
reproduction archives contained exactly those inputs plus the generated object.
Config and default-library omission controls failed with their independent
markers and no output. Exact commands, hashes, environment and report paths
are in the explicit-cohort section of `tests/native-executable/verifier/EVIDENCE.md`.
The fixture imports kernel/UCRT API sets. This is host cohort evidence, not
portable-release qualification, tool/DLL race protection or selection of the
UBE error/stack support. The referenced root toolchain lock files are absent.
The retained `verifier/check-support-object-inventory.ps1`, run with the None
explicit-link report, also passed all 13 support-file inspections: 7,310 AMD64
COFF records, 52,655 sections, and only four permitted common-symbol alignment
directives in three members. It cross-checks independent archive/section reads
against readobj and the recorded cohort counts. Exact command and report are in
the same evidence section. This completes the fixed-cohort format/directive
inventory, not native runtime or image-binding qualification.

The initialization-warning policy is selected in `NATIVE-BUILD-DIAGNOSTICS.md`:
follow initializer-reachable bodies, propagate root-storage origin through
exact ByRef formals, and emit one possible-cycle warning per cyclic dependency
component. Same-module self access, local/temporary copies and uncalled helpers
do not alone imply a cycle. The test-only command
`rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/additional/check-initializer-warning-model.ps1`
passed 21 hand-authored graph/anchor cases and three adverse controls. A first
run found a test-model sorting bug, corrected before the passing result.
The model does not test source extraction, the production component algorithm,
native alias enforcement or emitted diagnostics. Their future acceptance
obligations are retained; missing backend implementation is not a design-review
blocker. Exact publication, stack safety, resource budgets and tool/support
binding still need contract decisions before preparation is complete.

The candidate structural profile is selected in `NATIVE-CANDIDATE-REVIEW.md`.
The current layout suite rejects 22 malformed cases, accepts three permitted
variants and passes three count boundaries; the omitted-layout probe accepts
all variants as its adverse control. The independent structural suite also
passes for the selected Full/None outputs, with 11 rejected cases per mode and
original/zero-code acceptance controls. Exact commands and artifact paths are in
the candidate review. These select a finite profile, not a complete loader model.
Production reads, cancellation and binding the inspected file to publication
remain unqualified. No production native builder is implemented by these probes.

The new-command interface is now selected in `NATIVE-BUILD-DIAGNOSTICS.md`:
UBE1500..UBE1514 are reserved; new error/warning output uses stderr with exact
UTF-8/LF formatter bytes, and success confirmation is console-only. Existing
frontend/checker bytes remain unchanged. The 21 hand-authored vectors in
`tests/native-executable/diagnostics.json` define future exact outputs.
The 17-case reference renderer, retained stage-one raw checker at jobs 1/4,
and console/file/pipe classification plus inverted controls passed; commands
and scope are recorded in the diagnostic document. These tests do not qualify
the new renderer, byte writer, console delivery deadline or warning analysis.

The stack review now distinguishes own-frame allocation from complete call
footprint. A focused O2 observer compared static reports, unwind allocations
and actual RSP movement for two frame sizes in Full/None modes: calls consumed
eight bytes beyond the reported frame, and all omitted-return controls failed
as expected. The two experimental linked guards now include that return address;
their metadata, recursion, Err/result and oversized-call controls passed again.
Exact commands and limitations are in the call-footprint section of
`tests/native-executable/ERROR-ORACLES.md`. `NATIVE-STACK-REVIEW.md` specifies
the accounting terms and guard inequality. Complete helper/recovery reserve,
initial commitment and the fatal path remain unqualified; no production stack
guard has been selected or implemented.

The native command review now selects explicit object compilation and linking
options in `NATIVE-EXECUTABLE-CONTRACT.md`, including DWARF 4 for Full and
timestamp suppression. The output-path host test previously generated LLVM
but rebuilt C for its executable; it now compiles that LLVM and links its
object. Its Full/None pairs matched LLVM/object/executable hashes and returned
7; changing only LLVM produced 9. The selected flags also passed the existing
source-location/side-effect and valid/invalid-verifier probes. Exact commands,
the initial timestamp comparison failure, hashes and limited scope are in
`tests/native-executable/verifier/EVIDENCE.md`, under the staged-command review.
This selects command options, not a production tool boundary. Resolved support
inputs, publication and resource/stack safety remain open. Candidate profile
selection is recorded above; its production integration remains open.

The additional native-fixture admission suite most recently passed 106 checks
per stage at jobs 1 and 4, using
`rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/additional/check-admission.ps1 -Compiler <stage>/ube.exe`
with stage1 and stage2 under
`bootstrap/out/semantic-cli/e5b3d482d7fd46539e190ea70d20ecef`. It includes the
five-native-argument and Full/None tail-recursion fixtures. These are frontend
admission checks; they do not execute a native build or qualify the review.

The additional `initializer-cycle-branch` fixture distinguishes an A–B cycle
from its non-cyclic dependency C for future warning attribution. Running
`tests/native-executable/additional/check-admission.ps1 -Compiler <stage>/ube.exe`
with each source-built semantic CLI stage under
`bootstrap/out/semantic-cli/e5b3d482d7fd46539e190ea70d20ecef` passed 98
frontend admission checks per stage. This checks admission, not native execution
or implementation of the proposed warning.
The retained graph comparison also passed for both stage observers at jobs 1
and 4, checking all three resolved targets against their source anchors and
rejecting each independently altered target. Run
`rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/additional/check-cycle-branch-graph.ps1 -Observer <observer>`
with `bootstrap/out/semantic-whole/d6427b01696642339093b6fc06bd3dab/f740ea07e47744afb51ff8e72dd6f6f7/targeted-stage1-ee4c75f3860143c78d87811112256454/targeted.exe`
and with the sibling `targeted-a459a1512e004eeea42bfa75b75ae947/targeted.exe`.
This observes frontend graph facts only; it does not test the future warning.

The bounded lifecycle deferral correction and its retained checks are qualified
on source-built cohort `25f3b4878a1348e79766e70decd66b66`; see
`LIFECYCLE-DEFERRAL-EVIDENCE.md` for exact reports, independent audit and scope.
The direct-call fixture is deferred at the declaration; this does not qualify
future supported-hook call enforcement. Native executable generation remains
unimplemented. The next action remains review of the concrete native contracts,
including unresolved tool/process, publication and resource decisions.
The concise decision and open-issue inventory is `NATIVE-REVIEW-SUMMARY.md`;
`NATIVE-CANDIDATE-REVIEW.md` proposes candidate checks without selecting a
production validator. The expanded additional fixture suite most recently
passed 96 admission checks per stage at jobs 1 and 4, including signed
native-value boundaries, initializer-order event fixtures and early module access. The comparison-boundary
fixture has a separate host C reference and focused semantic-graph checks;
neither executes fresh-v3 native output. A test-only PE probe rejected selected
misaligned and excessive-directory-count mutations, with omitted-check controls;
it does not establish complete PE validation or a safe publication mechanism.
The owner confirmed that each signed integer minimum `Mod -1` returns zero without a new
error, preserving existing Err. The language specification and scalar-operator
audit record it; the native oracle requires separate clear and preseeded Err
observations. Both stage-built CLIs passed 54 additional-admission checks each,
including jobs 1 and 4; the hand-authored guarded arithmetic probe passed at O0
and O2. Neither result proves fresh-v3 native execution or actual runtime Err.
The owner subsequently confirmed the same remainder rule for all signed integer
sizes. Added Integer and LongLong fixtures brought the admission run to 58 checks
per stage; native execution and Err observation remain future gates.
The owner also confirmed Err 28 and a neutral function result when a call is
safely refused for insufficient stack. No production guard is yet qualified.
The owner confirmed that an initializer accessing another module not yet begun
must first complete that module's initialization. The owner later clarified that
circular references should remain allowed, with a compiler warning when
detectable, and that another module cannot read one that has not finished
initializing. Mutually waiting initializers may continue until stopped; the
future IDE must be able to show the warning. Native execution is unverified.

The installed qualified local CLI (SHA-256
`80955A6E4CF5F4249C70C8EA130C4D0CD97AA07FB7EE847F24838F507A6CD241`)
subsequently passed the 38 native-fixture admission checks, six exact frontend
rejection comparisons and their controls. The 19-project result-definition
consistency check also passed. None runs a generated native program.
An additional Byte-promotion fixture is kept separately from that pinned
inventory and was accepted locally at jobs 1 and 4. Updating the existing
fixture scripts initially made the cohort selection stale; those scripts were
restored byte-for-byte and `Get-VerifiedBootstrapSelection` again passed for
manifest SHA-256 `A56778FE1D2F72F8A79A158A8C292E02F49E785945463D415165790CB362D5E7`.
The additional fixture is not part of the prior structured identity audit.
A focused current-host Windows Job probe passed for a suspended child and test
grandchild (active count 2 before termination, 0 afterward). Exact command,
hashes, failed first compile and exclusions are in
`tests/native-executable/JOB-CONTAINMENT-EVIDENCE.md`; it does not qualify pipe
handling, arbitrary host contexts or the production compiler boundary.
A separate test-owned replacement probe observed successful existing/absent
destination cases, preservation under an exclusive lock, and an unchecked
hardlink-swap race. See `tests/native-executable/REPLACEMENT-PROBE-EVIDENCE.md`;
it does not prove atomic visibility, durable writes or identity-safe commit.
Independent arithmetic boundary expectations are recorded in
`tests/native-executable/additional/ARITHMETIC-BOUNDARIES.md`. Six local
source-only scratch probes matched the expected admission or constant-fault
diagnostics; they do not establish native arithmetic or Err behavior. The
document and additional fixture are not part of the earlier 25f identity audit.

The chronological preparation log below preserves earlier results and pending
statements as they stood at each checkpoint; the current status is above.

The bounded draft, independent agent reviews and specified result/failure cases
are ready for owner review in `NATIVE-CONTRACT-REVIEW.md`. Exact implementation
resource bounds, supported optimization/debug options, a qualified process and
identity-protected commit boundary, and the actual native/ABI/Err/failure gates
remain future prerequisites; a review of the proposal is not a native execution
claim. No backend implementation is authorized merely by this preparation.
On 2026-11-02 the owner accepted the proposed small first executable feature
scope (numbers, Boolean, variables, procedures, If, While and supported native
datatypes; strings, arrays, classes and forms later). Remaining review choices
are separate and have not been approved by that answer.
The owner subsequently confirmed that a tool failure should show a clear error
with useful readable details when possible and a safe fallback for unreadable
output. The earlier hex-only display proposal is superseded; exact safe rendering
and the separate quiet-success, capture-limit and CLI choices remain under review.
The owner then requested a small success confirmation in a terminal that does not
interrupt scripts. The draft proposes a best-effort interactive-stdout line and
quiet redirected output, with exit 0 and no acknowledgement required. Exact text
and terminal detection remain to be specified and tested; `--check` is unchanged.
The owner also confirmed that a failed build preserves the previous executable,
and a successful build overwrites it without an additional prompt. The build
command supplies confirmation, or the IDE handles it before invoking the build.
The publication mechanism remains unimplemented and requires qualification.
The owner distinguished build success from cleanup success: once publication
succeeds, a cleanup problem is a warning and the build remains successful.
The owner accepted first-build debug information on the condition that it
faithfully describes the optimized program and does not change observable
behavior; unavailable optimized-away values must not be fabricated. Native
debug information and debugger operation remain unverified.
The separately maintained additional native projects passed 40 frontend
admission checks on the local CLI, then 42 checks each on both 25f stage-built
CLIs after adding the no-debug configuration; see
`tests/native-executable/additional/ADMISSION-EVIDENCE.md`. Focused semantic observations for numeric While
conditions, nested exits, nested named calls and single-line If passed on both
25f targeted observers with the controls recorded in
`NATIVE-LOWERING-REVIEW.md`. These observations do not qualify native lowering
or execution. `rtk proxy git diff --check` returned exit 0 for tracked changes;
it does not inspect untracked drafts or fixtures.
A C debug-reader probe also passed object and linked Windows executable checks
with wrong-name and no-debug controls. It demonstrates a candidate tool path,
not debug information emitted by UBE.

## Native executable contract preparation - 2026-11-02

Drafted `NATIVE-EXECUTABLE-CONTRACT.md` and hand-calculated initial native and
failure cases in `tests/native-executable/ORACLES.md`. They are review drafts,
not implemented or qualified behavior. The current synchronous tool intrinsic
does not establish cancellation, and text-file atomic replacement does not
establish native executable replacement; both need concrete qualified solutions.
The Err observer and complete construct-by-construct oracle set remain open.
Four concrete independent projects now cover empty entry, folding, signed
division/remainder and alias/temporary behavior. The local checker accepted each
with jobs 1 and 4; exact commands, executable hash and limits are recorded in
`tests/native-executable/ORACLES.md`. No emitted executable has been tested.
Three additional projects cover direct-reference native packing/copy/unpacking,
named-argument source order and short-circuiting, and a neutral runtime division
result; all six local checker runs at jobs 1 and 4 passed. The last does not
observe Err. Eager Boolean evaluation, optional ByRef/default arguments and
runtime-dependent overflow have three more fixture projects. The repeatable
`tests/native-executable/check-fixture-admission.ps1` passed all 20 checker
admissions plus three comparator controls; native results and failure observers
remain unverified.
The contract now defines the replacement/cancellation linearization point and
`tests/native-executable/FAILURE-ORACLES.md` describes exact independent
tool, full-disk, cancellation, cleanup and replacement experiments. The current
bootstrap tool call waits indefinitely and has no cancellation contract; its
text-file replacement primitive does not qualify the proposed executable path.
`NATIVE-LOWERING-REVIEW.md` maps current result records and producer locations to
the execution facts and independent checks lowering needs. The map is a source
audit, not a proof that condition conversions, call mappings or all control-flow
relationships are sufficiently retained for a consumer.
The review subsequently located the existing independently authored complete
semantic graph: its recorded whole gate covers a reordered named call, forced
and omitted temporaries, and nested If/While with Boolean identity conversions
through both stages and jobs 1/2/4. See the lowering review for report identity
and the remaining nonidentity conversion, nesting and consumer obligations.
The new `conditions` project adds a future native result oracle for numeric
conditions, nested loops and ElseIf. Re-running fixture admission passed 22
checks and three comparator controls; it does not compare semantic records.
The subsequent conversion, recursion and negative-process-status projects extend
the planned independent results. Fixture admission now passes 28 checks and
three comparator controls; no native result or Err state has been observed.
`NATIVE-CONTRACT-REVIEW.md` records an agent review against each workplan
requirement and identifies unresolved ABI, consumer, tool, determinism, resource
and oracle decisions. This is not owner approval or a completed native gate.
The review found the normative one-component aggregate ABI had been omitted from
the draft; the draft now states its ByVal/ByRef and 1/1, 2/2, 4/4 requirements.
`native-widths` supplies Integer/Long cross-reference value cases. Fixture
admission now passes 30 checks and three controls; layout/calling convention and
native execution still require separate independent probes.
`tests/native-executable/ABI-ORACLES.md` now specifies target layout, signature,
payload, alias and corruption-control observations for all three representations.
It distinguishes the internal aggregate ABI from an unspecified foreign ABI and
does not claim that any probe has run.
The draft now fixes the raw LLVM comparison cohort and project-option handling.
The current host reports Clang 23.1.3; `opt.exe` was absent from its default
directory. Existing Clang IR compilation is not by itself proof of a separate
LLVM verifier, so the exact verifier and structural negative control remain open.
Follow-up: Clang 23.1.3 `-Xclang -llvm-verify-each` accepted the valid probe and
rejected a dominance violation. Exact commands, hash and scope are in
`tests/native-executable/verifier/EVIDENCE.md`. Requalify the chosen invocation
on the actual generated module; this focused probe is not backend acceptance.
`tests/native-executable/ERROR-ORACLES.md` separates neutral values from actual
Err observation, specifying stale-state, thread isolation, known/runtime faults
and negative controls. No general normative numeric mapping for these arithmetic
errors was located; numeric codes are not inferred from bootstrap behavior.
The `bitwise` and `comparisons` projects add exact future scalar results;
`tests/native-executable/COVERAGE.md` maps all current fixtures to the included
subset and explicitly lists gaps. The local admission script passed 34 checks
and three controls; none is a native execution result.
`expected-results.json` records the 17 independent signed exit expectations.
`check-result-definitions.ps1` passed schema, identity, range and fixture
membership consistency checks; it does not verify the expected arithmetic.
Repeatable `check-rejections.ps1` passed six exact diagnostic comparisons and
three controls. Its initial LF-only expectation failed: observed Windows output
uses CRLF, unlike the LF wording in SEMANTIC-DIAGNOSTICS.md. The discrepancy is
recorded for review; no diagnostic behavior was changed.
The bounded `newline/check-stdio.ps1` probe passed: default text-mode output
translated LF to CRLF, while binary mode preserved LF. Existing bounded-process
capture normalizes CRLF to LF, and the bootstrap print functions use C stdio.
This supports, but does not prove, the cause of the checker observation; raw
versus logical newline policy remains to be reconciled.
Three concrete frontend controls for known division by zero, constant range and
deferred String were checked at jobs 1/4: six expected exit-1 diagnostics and
coordinates matched. `FAILURE-ORACLES.md` records command, identity and the
corrected reserved-name attempt. Future build-path no-tool/publication behavior
remains untested.
The draft now records lowering-specific ownership, bounded-resource and measured
work obligations. Concrete numeric limits and candidate cost bounds still need
reviewed probes before production implementation; no new speedup is claimed.
The contract proposes a concrete build CLI with an optional output path,
existing jobs semantics, controlled exits and input-alias protection. It is a
review choice, not an implemented option; exact new diagnostic wording and the
host identity/alias mechanism remain open.
The owner subsequently approved a default `build` folder beside the project,
with the executable named after the project and an optional location override;
the compiler creates the default folder if needed.
`NATIVE-BUILD-DIAGNOSTICS.md` proposes usage, exit dispositions, diagnostic
classes and fallback/cleanup ordering for review. It now proposes separately
drained bounded raw tool output and deterministic hex on tool failure; the
existing inherited-stream intrinsic does not implement that proposal. Line-ending
interpretation and final code allocation are deliberately not claimed settled.
Parallel review identified startup ordering, recursion/stack safety, native
aggregate spelling, publication path races, tool descendants and fixture
portability gaps. The draft and future oracles now state those obligations;
the optional fixture also observes the omitted default result, and rejection
sources have LF checkout attributes and explicit SHA-256 checks. These edits
are review requirements, not proof of a host mechanism or native execution.
Follow-up independent reviews added Boolean truth-table and dependency-first
initialization fixtures, plus detailed child/pipe/path-race experiments. Current
admission passes 38 checks and three controls; result-definition consistency
passes 19 projects; rejection checks pass six cases and three controls. These
are not native execution or process-boundary qualification.
At this earlier checkpoint the proposed CLI reserved exit 3 for a confirmed commit followed by required
cleanup/reporting failure, with exit 1 limited to precommit failures. A host
operation with an indeterminate commit outcome remains unqualified; exit 4 is
now a proposed explicit unknown-outcome disposition, not a claim that a host
primitive satisfies the required decisive commit guarantee.
The later owner decision above supersedes exit 3: confirmed publication remains
successful and a post-publication cleanup problem is reported as a warning.
The diagnostic draft now distinguishes verifier rejection, tool-start failure,
representable nonzero exit and unobservable/unrepresentable completion; the
codes remain proposed and no new tool boundary is claimed implemented.
Independent semantic review found two definition/checker gaps: the current
checker accepts lifecycle hook declarations and direct calls although the former
are deferred and the latter forbidden; ordinary scalar module initializer
startup timing/order was not explicitly located in normative text. The startup
fixture's exit 10 is therefore provisional, not a normative native oracle.
Reproduce and retain lifecycle probes, reconcile scalar initialization behavior,
and qualify a focused checker correction before lowering depends on these cases.
Both reproducible local source-only probes are now retained under
`tests/native-executable/lifecycle-probes/`; `EVIDENCE.md` records commands,
checker hash and the unexpected zero exits. The future correction and stage
qualification have not been performed.
An additional `Module_Terminate` declaration/direct-call probe also returned
zero with empty output under the same local checker; it is recorded alongside
the initialization probes.
Focused correction in progress: the declaration collector now defers lifecycle
names using existing folded identities and UBE1400. The old installed checker
fails the new regression as expected. Diagnostic-only source-built stage1 and
stage2 each passed 28 source/project cases including jobs 1/2/4, bracketed/case
variants, direct call and unrelated-name controls. Reports are
`bootstrap/out/lifecycle-deferral/372f6eeb2c84420a8e2f526501f1f669/report.json`
and `bootstrap/out/lifecycle-deferral/21d4d756c79e43aaa3761663d7efed9a/report.json`.
Both diagnostic stages also passed the 38 native-fixture admissions and six
existing rejection comparisons. The diagnostic CLI retained 104 process cases:
`bootstrap/out/parser-cli/f02431080d6d469683b5dd0539102aee/report.json`.
These are focused diagnostic results; the fresh bootstrap and retained full
semantic gates have not yet completed, so no new qualification is claimed.
Follow-up: the first new source cohort `18c083f057f340f79f4c9744498bb685`
passed 894 bootstrap assertions before the maintained lifecycle gate was
registered; those later test-input edits make that selection stale. Two interim
cohorts (`c071b334474849d29ad6c42287eca5de` and
`64eb9844f7584120bc5d6fdbb23500c8`) were deliberately interrupted before PASS
to correct missing coverage and strengthen independent audit controls.
The final-input bootstrap is running in session `23345`, cohort
`25f3b4878a1348e79766e70decd66b66`; do not restart it merely because output is
quiet. Poll that handle and preserve pinned inputs until it terminates. Then run
the maintained semantic CLI, semantic input audit and applicable retained gates
on the final selection. The current handle and partial passes are not qualification.
Update: session `23345` exited 0 with `PASS: 894 acceptance assertions`.
`bootstrap/out/v2/current.json` now selects cohort
`25f3b4878a1348e79766e70decd66b66`, manifest SHA-256
`A56778FE1D2F72F8A79A158A8C292E02F49E785945463D415165790CB362D5E7`.
The maintained semantic CLI gate is running in agent session `34225`; its
result, the semantic input audit and remaining retained gates are still pending.
Update: semantic CLI passed both source-built stages and eight child proofs,
report `bootstrap/out/semantic-cli/e5b3d482d7fd46539e190ea70d20ecef/report.json`.
The independent semantic contract definition passed 205 cases and 29,561
definition assertions, report `bootstrap/out/semantic-contract/
8c88cbbab5634f898f9785cd3ddcff3a/report.json`. The input audit passed eight
stage-matched child proofs and negative controls, report `bootstrap/out/
semantic-inputs/93a767e4d6a64877a756d5d3abfcb3ae/report.json`. The retained
whole-semantic gate is running in agent session `36277`; other retained gates
remain pending. None of these is native-executable backend qualification.
Update: the retained whole-semantic gate completed successfully, report
`bootstrap/out/semantic-whole/d6427b01696642339093b6fc06bd3dab/report.json`.
It covers the maintained complete graphs, resources, sharing and controls;
the borrowed-lifetime and other retained gates remain pending.
Update: borrowed-lifetime passed, report `bootstrap/out/borrowed-lifetimes/
abe3aa4d84664e109c3db2397e3cc107/report.json`. Strict parser CLI is running in
agent session `42650`; its output is needed for the local CLI and documentation
example checks. Catalog, expressions, formatter, source-worker slots, parser,
project CLI, concurrency, complete-definition and docs checks remain pending.
Update: strict parser CLI passed 104 exact process cases, report
`bootstrap/out/parser-cli/a5148e850c1b4357a0cd56e1d08b9af9/report.json`;
local CLI replay passed 52 process oracles, report `bootstrap/out/local-cli/
ff9df9ccdac743f9a96ae69c19bc03e0/report.json`; project CLI passed 1,202
assertions, report `bootstrap/out/project-cli/ca3570f0067d499d9d8488c0ea6ca9d6/report.json`.
The semantic catalog and remaining retained gates continue against cohort 25f.
Update: the retained semantic catalog gate passed 337 aggregate checks, report
`bootstrap/out/semantic-catalog/qualification/ab64f043705d4968a22ec7c96180dc2f/report.json`.
The expression gate and other retained checks remain pending.
Update: the maintained expression gate passed through both selected stages,
report `bootstrap/out/semantic-expressions/a76be8fd778c44b5b5b75d97fe462129/report.json`.
The formatter and remaining retained checks continue against cohort 25f.
The semantic formatter gate passed 259 aggregate checks, report
`bootstrap/out/semantic-formatter/qualification/3741feecb8864d95840121d5fd73b1df/report.json`.
The source-worker-slots gate and remaining retained checks are next.
The source-worker-slots parent gate passed both source-built stage proof groups,
with 4,255 actual source-set assertions per stage; report
`bootstrap/out/source-worker-slots-maintained/7a317c23be2c435aabd2700529942f58/report.json`.
The retained parser gate and remaining checks continue against cohort 25f.
The retained parser gate passed 1,879 checks with its accepted selection
unchanged, report `bootstrap/out/parser/6e75f856f56843e49eef829bca2828c1/report.json`.
The concurrency and final documentation/definition checks remain pending.
Update: retained concurrency passed both source-built stages with 8,440
source-set assertions each under the unchanged 180-second emission limit;
report `bootstrap/out/source-set-proof/52297b9b1b864280860c2f069cd91a67/report.json`.
The complete semantic definition validator passed 8,854 assertions and 13
corruption guards using an OUT copy; its resolved evidence is
`bootstrap/out/semantic-definition/8455ad7aef6e45b68daa80c3e75c9c13/resolved.json`.
`docs/assets/tools/check-development-examples.ps1` passed five exact tutorial
CLI cases and 35 source-matched declarations, report
`bootstrap/out/docs-checks/4802a6f8fb8a468f953dc1265d5fdb5a/report.json`.
`docs/assets/tools/validate-docs.ps1` passed 274 HTML files. These are static
and process checks, not browser/accessibility or native-executable results.
An independent final identity and scope audit was subsequently completed; see
`LIFECYCLE-DEFERRAL-EVIDENCE.md` for its exact inventory and limits.
On 2026-11-02 the owner confirmed that ordinary scalar module variables
initialize in declaration order as their module initializes, with referenced
libraries before executable modules. `lang-doc/language-spec.md` section 6.3,
`lang-doc/project-files.md`, and the public types topic now record the rule.
The startup fixture's expected exit 10 follows that decision but has not been
executed as native code. Lifecycle admission was subsequently corrected and
qualified as described in the current status above.
Documentation static validation passed 274 HTML files using
`rtk proxy powershell -NoProfile -File docs/assets/tools/validate-docs.ps1`;
this does not claim browser or accessibility verification.
Next: reconcile the draft with retained checker facts and the normative ABI,
author complete runnable independent fixtures and fault controls, then review
the bounded contract before any backend implementation. No completion claimed.

## Historical bounded semantic checker acceptance - 2026-11-02

This section records the earlier 88d acceptance. The later lifecycle-deferral
correction is qualified on the current 25f cohort; see the current status and
`LIFECYCLE-DEFERRAL-EVIDENCE.md` above.

First semantic checking is complete for its approved scalar/native MODULE
subset. The production manifest includes the checker, diagnostics, existing
check path and shared source-worker controller. Maintained tests consume the
actual production closure, real UBECore reference and independent expectations.
Accepted source-built cohort: `88d1906a667645fa87f885c3a117e52f`; manifest SHA-256
`9C4BFED73CF3CF4C42A768B68B61A6C0F318D0E038EC64B66D30BDFEC75BFEB9`.

[SEMANTIC-EVIDENCE.md](SEMANTIC-EVIDENCE.md) records the final bootstrap 894,
whole/catalog/expression/formatter/controller/CLI/resource/cost/sharing gates,
independent definitions and retained parser/source/project/local/lifetime/
concurrency proofs. The first concurrency attempt's 180-second emission timeout
is preserved separately; the unchanged quieter rerun passes both stages.

Supported successful checks exit 0 with empty output and publish no executable.
The full compiler and actual Core source remain deferred by the subset. Full
grammar/native execution and semantic performance are separate future claims.

The next existing deliverable is First checked native executable. Review its
bounded program set, lowering/backend, ABI/runtime-error and tool-handoff
contracts before implementation. No new executor or public phase API is implied.

## Historical implementation and foundation checkpoints

The sections below preserve their dated source cohorts and then-current
capabilities/actions. Current status is above and in Active next action below;
earlier OUT candidates and unavailable-check messages are not current claims.

### Earlier foundation qualification

Implementation continuation: four measured ordinary library modules are now
registered by the actual UBECore source reference: SignedIntegers, ByteKeys,
StorageCapacity and Utf8Encoding. Their maintained integrated gates and the
arena/four-UBE-worker foundation gate are registered in the source bootstrap.
That foundation source build passed 894 acceptance assertions, selecting
`bootstrap/out/v2/3d4622079d9d476d9aad890dfa8593e8/manifest.json` (SHA-256
`70B1F55EF276E2DAA12EB2939775E2FFA7AB7B68A0DCDC59476D16FEF55D1392`).
Command: `rtk proxy powershell -NoProfile -File bootstrap/build-v2.ps1`.
A subsequent `Get-VerifiedBootstrapSelection` audit passed against current
source/tool/artifact identities. The first attempt exposed the bootstrap's
Public-only reference restriction. A focused fix admits Private procedures
only within their original library module, retaining global duplicate rejection
and all other existing reference restrictions. Source-reference qualification
now includes private ordinary/intrinsic success and executable/peer-module denial.

The integrated proof reports are `bootstrap/out/signed-integers/
3ea27b94e3714a739f305b026b6200e9/report.json` (18 maintained assertions),
`bootstrap/out/byte-keys/e5b92a8f100a4ff3be60dafaf5665821/report.json` (20),
`bootstrap/out/scalar-storage/827996ac2e04453c9c78c27285fa3b60/report.json` (18),
and `bootstrap/out/semantic-foundations/fa9782ee12734ab7abee833ac22e1434/
report.json` (35). These include independent native values, executed work,
real-backed root/allocation denial, corruption controls and unchanged input
identities through both selected stages. They qualify the selected library/
arena/sharing components, not a semantic checker.

At this earlier foundation checkpoint, private candidates under
`bootstrap/out/semantic-implementation/` covered the model, declarations/names,
expressions/calls, constants, statements and coordination. Those copied reports
remain candidate evidence. The later implementation and independent complete
oracles are now maintained under src/ and tests/semantic/native/; production
qualification is recorded in the current status and final semantic evidence.

The first dependency is the retained parser detail in SYNTAX-DETAILS.md.
SyntaxNode/SyntaxResult layouts remain unchanged. Existing grammar paths now
retain declarators, passing/default/type information, rank/bounds, modifiers,
option/attribute parts, suffixes and written procedure/Exit kinds. New internal
child roles use the same owned arena; no source reparser or source payload copy.
The 12 independently authored full-detail cases are
`tests/parser/native/declaration-details.json`. Old fixtures retain their original
logical comparison; the complete physical graph is validated before projection.

The retained parser detail is now qualified for source cohort04c. It is not a
semantic checker.
The focused stage-one diagnostic executes all 200 frozen/supplemental cases
(1,865 native assertions), including all 12 complete physical-detail trees.
The final diagnostic report is
`bootstrap/out/declaration-fixtures/1a8c24b3a77a47c1acc5536027cd14d1/report.json`.
Four deliberately corrupted detail expectations were rejected. The separately
observed 51 cost rows pass 1,131 native assertions and 710 maintained measurement
assertions, including four measurement corruption controls; see
`bootstrap/out/declaration-fixtures/85d6c224e35a4123bc6d1ee0c3d076a7/`.
These diagnostic runs alone do not qualify the parser.

The complete current-source command `rtk proxy powershell -NoProfile -File
bootstrap/build-v2.ps1` passed and selected source cohort
`bootstrap/out/v2/04c889304e52467bbf597ac84269317e/manifest.json` (SHA-256
`2E9F51AD844CAE40CDD046EC85346604DE5F57B8F02C6CE306B11039135ECADC`).
It retains the fixed point and all 785 predefined bootstrap assertions.
The strict command `rtk proxy powershell -NoProfile -File
compiler/UBE_Compiler_v3/tools/check-parser.ps1` passed 1,879 maintained checks at
`bootstrap/out/parser/eee096abee4d4e85bd22a7fbd9399ec2/report.json`.
It covers all 200 cases, exact details, both stages, actual faults and exhaustive
real-backed root capacities, worker sharing, cost bounds and comparator controls.
Existing CLI/lifetime/concurrency gates still need reruns for the final checker.

All 20 updated syntax inventory entries pass 829 source-witness assertions in
`bootstrap/out/declaration-inventory-current.json`; this is source evidence only.
`SEMANTIC-PROBES.md` fixes the subsequent native storage/lookup/numeric probe
obligations. Focused numeric probes found a bootstrap prerequisite gap: both
stages reject general LongLong arithmetic at emission, and signed-minimum
negation wraps with stale Err. Reproductions are
`bootstrap/out/numeric-prerequisite/57f92f43e69c4e41a33003240d5ac3ee/report.json`
and `bootstrap/out/wide-negation/c09b7437b31c4a4b946b1b9e063b6dca/report.json`.
The focused repair contract is v2 `tests/wide-integers/CONTRACT.md`. Checked
machine helpers and the existing emitter path now cover the six signed-64
operations. Its focused gate passes eight maintained assertions, including 79
independent native cases/158 value-and-Err assertions per stage, identical raw
LLVM and a deliberately wrong expected-value control. Report:
`bootstrap/out/wide-integers/da45734c3cc744f1b21ed7d6abd26e9a/report.json`.
The full command `rtk proxy powershell -NoProfile -File bootstrap/build-v2.ps1`
passed all 793 acceptance assertions and selected source cohort
`bootstrap/out/v2/281e3cb01f86415793da82acd8d13c2c/manifest.json`.
It retains every previous 785 assertion plus the eight focused wide-integer
assertions. All earlier reports remain bounded to their exact preserved cohort;
final parser/CLI/lifetime/concurrency gates must cover the eventual checker.

Sorted/bounded-hash test candidates are drafted below `bootstrap/out/` only.
`run-key-index-functional.ps1` passes 73,041,611 functional assertions per stage
at `bootstrap/out/key-index-functional/208d329faa6e4d9da2efe5833a9b8315/report.json`.
This covers all preset sizes 0/1/8/64/1024/16384, increasing/reversed/duplicate/
common-prefix/empty-byte keys, complete stable equal-key groups, range queries,
controlled collision work, unchanged input and final zero retained allocation.
It is a diagnostic candidate comparison, not a selected representation: actual
copy/allocation/root observations subsequently pass in
`bootstrap/out/key-index-observed/f93ba211053641cf85453f410145a9b8/report.json`:
73,041,873 native assertions per stage, plus 4,204 host measurement assertions
and five deliberately corrupted counter/copy/allocation/memory controls in its
`measurement-checks.json`. Actual publication copies are exactly one logical
payload; query allocations/copies and key-byte copies are zero. Source-audited
physical bounds are now preset in SEMANTIC-PROBES.md for the later maintained
acceptance run; these earlier diagnostic rows are not retroactive acceptance.

Actual allocation-denial sweeps with an unrelated old complete index and two
distinct input owners pass 1,392 assertions per stage at
`bootstrap/out/key-index-observed/1fbd0d1a7c984b519d26b9629a6a7ca6/report.json`.
Every observed allocation site fails safely, preserves the old graph/owners,
cleans temporary storage and recovers. Domain probes pass 129 assertions/stage
(`eb5b70d3f0d043268e7a8b2f4aa56d75`); the real 17-byte-copy observer control
passes 23/stage (`3b5638ea5c274149b2e39d791adf8184`). These IDs are under the
same `bootstrap/out/key-index-observed/` directory. The final root fixture adds
constructor and query actors: measured additional roots are 32/40/6/7. All 16
gap-free ranges across both stages, from zero through exact-plus-one capacity,
pass under actual one-million-record pressure at
`bootstrap/out/key-root-ranges/4ec66266602845a59a179e1beb532bbc/report.json`.

The ordinary-UBE signed integer/ASCII decimal candidate passes independent
results, old-output/Err preservation, signed minima, bitwise operators and
0/1/8/64/1024/16384 digit scaling through both stages. The observed run at
`bootstrap/out/signed-integer/012a408b55124308a703f9f888c4d8fb/report.json`
passes 2,101,133 native assertions/stage and wrong-expected-value controls.
It reuses the 79 maintained boundary cases, adds 44 operator cases, 169 ordered
comparison pairs and 43 decimal spans (including embedded zero), tests old Err
7/77, and proves zero allocation/copy and preset actual machine-operation bounds.
Decimal entry needs one additional actual root; zero/exact/above capacities
preserve the old scalar output on denial. The entire scalar cohort also runs
successfully while the root registry is completely full. Draft numeric bodies
are `bootstrap/out/signed-integer-candidate.bas`; no UBECore API is adopted yet.

Arena/name probes, complete maintained packaging and UBE-driven immutable sharing
remain before representation/API selection. The first lookup attempt
used an incorrect harness assertion that required an already-empty collection
to reclaim something; the corrected gate checks the required zero remaining
allocation instead. No production collector change was justified or made.

Exact initial source/parser-test/tool backup: 90 byte-compared files under
`bootstrap/out/semantic-baseline/549405a6379c411eaedfda49e1932ce9/`, with
`files.json` and the initial accepted selection. The earlier 2c0 cohort remains
the pre-change reference. Probe drafts have begun; production semantic storage,
generic UBECore numeric facilities and the checker are still unimplemented.
Keep their whole approved scope intact.

## Owner literal and initializer clarification - 2026-11-01

The owner accepted the basic checking scope and made clear that foundation-first
development is already given. Review ordinary behavior using VB6 unless it
conflicts with an established UBE definition; ask only actual behavior questions.

Unsuffixed literals must fit their selected integer types, widening beyond a
narrower destination context when necessary. `Dim x As Integer = 40000 - 10000`
has the same declaration/assignment behavior as two separate lines: x exists
with neutral storage before its initializer, the calculation uses a wider
integer, and 30000 converts to Integer. Storage remains after recoverable
runtime initializer failure. The specification, contract, conversion table,
public manual and independent cases record this clarification.

The additional four cases distinguish initializer/split assignment, typed wider
literals, self-reference to already declared storage and storage retention after
runtime failure. Current commands/results are in SEMANTIC-EVIDENCE.md. They are
expected semantic observations; current native tests qualify source admission
only. The owner subsequently confirmed rejection of provable faults, including
known final overflow in ordinary assignments, and required literal-only integer
arithmetic to reduce to a typed constant during compilation. Runtime-dependent
faults retain the existing Err rules. The updated evidence records definition
checks and frontend admission separately from unimplemented semantic behavior.

## Semantic contract prepared for review - 2026-11-01

The owner requested completion of the next-step preparation goal. The concrete
proposal is `SEMANTIC-CONTRACT.md`; `SEMANTIC-SYNTAX-INVENTORY.md` documents what
the current parser retains and what it discards. Independent targeted expected
facts, exact witnesses, source evidence and future native obligations are under
`tests/semantic/`. `SEMANTIC-EVIDENCE.md` records exact commands, outcomes,
identities, review checklist and limitations. No production source was changed.

The owner confirmed contextual unsuffixed decimal integer typing, including
destination propagation through arithmetic; otherwise use Long then LongLong.
The normative specification/conversion table and specified public manual now
record that rule. The proposal enumerates the first integer contexts and the
remaining deferred boundaries rather than inheriting bootstrap behavior.

Review this contract before implementation. The immediate technical dependency
is extending the existing parser's declaration detail publication, preserving
all previous syntax projections and failure/budget gates. Semantic representation
and lookup probes follow that qualification; no new parser, executor or phase
architecture is selected. The actual semantic checker/backend remains absent.

## Consolidated bootstrap runtime - 2026-11-01

The owner requested that bootstrap-native support be kept in the bootstrap
folder. The former root `runtime/` files now live in `bootstrap/runtime/`:
`bootstrap_runtime.c`, `bootstrap_unicode_runtime.cpp` and `value_storage.h`.
The former UBECore C adapters now live in `bootstrap/runtime/windows/`:
`file_primitives.c` and `thread_primitives.c`. The old directories are gone;
UBECore's production source tree contains UBE. Future UBE platform libraries
remain library work; this move changes no public API or language behavior.

Build/test paths, native includes, parent input inventory and current guidance
are updated. All 24 relocated v3 UBE files retain their original bytes. A focused
review passes 96 checks, including syntax of 32 edited PowerShell scripts and
byte-identical before/current preprocessed C runtime. The historical before-fix
regression mode keeps its pinned snapshot's original path layout.

Current source cohort: `2c0fb05a3c4b4912861db33043acdb40`, manifest SHA-256
`2D6B6082C7647DE7D380BEB35C1FAFB057A312F6056C0A9D552CC7E540772D51`.
`rtk proxy powershell -NoProfile -File bootstrap/build-v2.ps1`: PASS, 785 source
acceptance assertions. Subsequent strict maintained gates all pass:

- `compiler/UBE_Compiler_v3/tools/check-parser-cli.ps1`: 104 exact process cases
  plus all diagnostic controls; both stages' production LLVM is identical to
  the qualified pre-runtime-relocation CLI.
- `compiler/UBE_Compiler_v3/tools/check-local-cli.ps1 -CliReport <source CLI report>`:
  all 52 exact process oracles with the qualified stage-two executable.
- `compiler/UBE_Compiler_v3/tools/check-project-cli.ps1`: all 1202 assertions.
- `compiler/UBE_Compiler_v3/tools/check-borrowed-lifetimes.ps1`: all 56 native
  runs and its negative unowned-watch control.

These commands use `rtk proxy powershell -NoProfile -File`. Complete command
records, logs, report identities, exact path-edit backups and preprocessing
comparisons are in
`bootstrap/out/runtime-relocation/9ab2b6bb253e4e17b0c042b88d2db589/`.
The report paths are:

- `bootstrap/out/parser-cli/8223b27728b84529adda41b9a0f95a45/report.json`
- `bootstrap/out/local-cli/6b912f000fbf4ae5a1d3ec9483ee6a73/report.json`
- `bootstrap/out/project-cli/16e952bc59c0419bb1273537692876e7/report.json`
- `bootstrap/out/borrowed-lifetimes/da0f3f17d9604a868f9e868b2965379f/report.json`

Earlier source-layout and frontend/performance records below retain their own
cohorts and original paths. No performance measurement was rerun for these
filesystem corrections. The accepted initial parallel results and next proposed
semantic-checking contract remain unchanged. No push is authorized.

## Qualified source-folder layout - 2026-11-01

The owner requested filesystem separation of code from plans and definitions.
All 24 production modules/classes now live under `src/`; the project file stays
at the v3 root with the same source order and `src/` entries. Plans, contracts,
evidence and contributor guidance retain their locations. Tests/tools remain
separate. Every moved source file is byte-identical; active tool and CLI-oracle
paths are updated. No production names or behavior changed.

Fresh qualification:

- `rtk proxy powershell -NoProfile -File bootstrap/build-v2.ps1`: PASS, all 785
  source acceptance assertions. Current cohort `47d728ea15684fdd8639e444709df30b`;
  manifest SHA-256 `2AFF9EA62482FDED74F21A64AC81A6885A2230F67678409A199151D948C6AF57`.
- `check-parser-cli.ps1`: PASS, 104 exact source CLI processes and all diagnostic
  controls. Both stages' production LLVM is byte-identical to the accepted
  pre-relocation CLI, as well as to each other.
- `check-local-cli.ps1 -CliReport <new source CLI report>`: PASS, all 52 process
  oracles using the qualified stage-two executable.
- `check-project-cli.ps1`: PASS, all 1202 project CLI assertions.
- Focused relocation review: PASS, 122 checks of source hashes, exact path-only
  reference edits, manifest entries and syntax of all 36 PowerShell scripts.
- `rtk proxy git -c core.safecrlf=false diff --check`: PASS.

Commands above use `rtk proxy powershell -NoProfile -File` and the maintained
scripts under `compiler/UBE_Compiler_v3/tools/`. Complete relocation identities,
before-edit copies, command records and reports are retained under
`bootstrap/out/v3-source-relocation/49d3aecd4aa44286a1fecc4130338eb5/`.
Earlier a732 full frontend/performance qualification below remains the original
accepted record. Performance was not remeasured for this byte-preserving move;
no new speedup result is claimed. The next proposed semantic contract is unchanged.

## Completed project/frontend objective

The owner-requested bounded project input and qualified parallel frontend is
complete under the revised initial-performance criterion. Cohort
`a732173e4f3d450cb7a6feaa519af1d3` passes785 source assertions and all seven
strict retained gates. The project/jobs path uses the existing compiler-owned
`TryParseSources` budget, immutable owners/private outputs, deterministic spans
and failures, complete publication, cancellation/drain and old-output retention.
UBECore retains generic facilities without compiler source policy or an executor.

The current project consumer proof covers35 cases, four independent contexts and
375 observed allocator failures. The optional physical case-sensitive36th case
is historical, not part of this current qualification. Parser1769 checks retain
all188 cases and every capacity0..58/200/206/207 through both stages (1350
attempts). Source CLI104 exact processes and58 diagnostic controls, local52,
project CLI1202, lifetime56 and concurrency4200 assertions per stage pass.

Both complete uninstrumented sessions retain252 trials and pass all serial/small
guards. Real-corpus two/four-worker speedups are1.207x/1.304x and1.211x/1.335x;
balanced gains are1.279x/1.396x and1.288x/1.423x. All parallel trial ranges are
faster than serial, and four workers improve over two. The original1.5x/2x
targets remain missed; the owner explicitly accepted close initial results.
The frozen harness/reports and both baselines remain unchanged. See
[current acceptance policy](PERFORMANCE-ACCEPTANCE.md) and
[performance evidence](FRONTEND-PERFORMANCE-EVIDENCE.md) for the decision,
archive, exact identities, distributions, resource costs and remaining limits.

Applied changes are the conservative unused-argument-slot correction, the
approved address-owned root registry with collection gating/fallback, and the
existing coordinator's1ms wait. No spelling cache, scalar-read fusion, private
procedure aggregation, second executor or public ABI change was adopted.
The32-byte root ABI/global1,048,576 capacity and real failure coverage remain.

Full grammar, semantic validation and native code generation remain unfinished.
Successful syntax checks return the explicit semantic-unavailable diagnostic
and create no output artifact. Later rows remain proposed until their bounded
contracts/dependencies and owner review are ready. No further push was authorized.

## Earlier foundation and parser checkpoints

Completed: implement and independently qualify the bounded production grammar
consumer in `PARSER-CONTRACT.md`. Private linked-child storage, explicit expression
and control continuations, borrowed input, atomic publication and source admission
are integrated into the production manifest/CLI. `PARSER-IMPLEMENTATION.md` records
their boundary; `PARSER-NATIVE-EVIDENCE.md` records exact commands and identities.
The refreshed bootstrap passes 501 checks; the unrestricted native gate passes
4049 grouped checks through both stages, including all 188 syntax/reject/deferred
cases, 10412 actual root capacities, persistent allocator denial, complete old
result/source retention, cleanup, private workers and 102 measured cost rows.
Both raw native-test LLVM images are byte-identical. A failed harness run remains
historical; the corrected complete rerun repeats every stage and root capacity.

The strict CLI gate passed 82 exact process cases and 54 diagnostic controls,
including all 16 then-existing compiler/UBECore modules, with identical raw LLVM through
both source-built stages. The rebuilt local executable passed the same 41 process
oracles. New diagnostics recover without runtime allocation. The owner approved
correcting two ordinary-call fixtures from reserved `text` to `s`; no language
rule changed. Reserved `Width` declarations were narrowly renamed `ScalarWidth`.

Completed: focused native parser representation/traversal probes. Both accepted
source-built stages pass 3828 assertions; linked-child storage and explicit
stacks are selected for the first bounded consumer. A persistent-allocation
regression required a focused recoverable-GC/first-error runtime correction;
that fresh source gate passed all 501 grouped checks. Its exact identities,
measurements, tradeoffs and next production action are in
`PARSER-PROBE-EVIDENCE.md`. This is historical prerequisite evidence; current
production implementation and qualification are recorded above.

Completed: define the first grammar consumer before choosing parser representation
or implementing it. `PARSER-CONTRACT.md` and 116 manually authored cases pass
11969 new consistency assertions and 16 negative controls. Syntax grouping,
original spans, diagnostics, later semantic obligations and deferred families
remain distinct. `PARSER-EVIDENCE.md` records exact inputs/report hashes, review
corrections, limits and the then-next focused native probes. It describes the
definition before production implementation.

That earlier definition gate separately audited all 2308 recorded accepted identities
unchanged, preserving the existing 501-check native qualification and all 13 child
proofs. It did not rerun native behavior. Exact scanner commands, accepted hashes,
measurements and supported limits remain in `SCANNER-EVIDENCE.md`; the earlier
470-check result remains historical in `SOURCE-INPUT-EVIDENCE.md`.

## Earlier source/header state

The production manifest adds `SourceOwner.cls`, `SourceWork.cls`,
`SourceCancellation.cls` and `SourceParsing.bas` to the existing source,
scanner, bounded parser and CLI modules. Compiler-owned source/work objects
retain original bytes, tokens and private syntax. They consume actual UBECore
source references and its generic fresh-status Threads APIs.

The local `bootstrap/out/v3/ube.exe` is byte-identical to the qualified
stage-two CLI artifact and passes all 41 exact process oracles. It accepts one
`--check` source, syntax-consumes the bounded native MODULE grammar and defers
other envelopes, then reports semantic checking unavailable with nonzero
status. This is not a public release or project/jobs CLI support.

`../archived/` holds the previous v3/v4 trees, release previews and compiler
handoff documents. Exact pre-archive working-tree bytes are retained separately
from recorded relocation-only script/metadata changes.

The fresh UBECore remains in `../../std-lib/`. Its inventory is documentary
scope with open API/compatibility decisions. The VB6 bootstrap-port idea stays
deferred. No old compiler's phase model or verification claim is inherited.

## Earlier setup and foundation evidence

The archive/setup gate checks original and relocated file hashes, allowed text
replacements, manifests, preview hashes and PowerShell syntax. The inventory
gate checks named coverage and document structure. These gates do not compile
the new compiler, establish bootstrap fitness or prove runtime behavior.

`rtk proxy powershell -NoProfile -File compiler/archived/verify.ps1` passed
367 original/archived file checks, 13 recorded relocation-only changes,
nine preview hashes, 28 library archive files, six manifests/132 inputs and
21 script syntax/root checks. `std-lib/tools/check-inventory.ps1` passed its
175 reference names and 73 historical hooks. Those checks remain structural.

The owner explicitly requested and started the first foundation goal on
2026-10-30. `../../std-lib/FOUNDATION.md` now defines the primitive/type ledger,
independent target obligations and a finite native-type proposal requiring
review before syntax or production implementation changes.

`rtk proxy powershell -NoProfile -File std-lib/tools/check-foundation.ps1`
built the current small seed/runtime and ran 33 checks against that seed and
two restored v2 artifacts. All 18 bounded-subset checks passed; six target
probes passed and nine failed. Byte is unsupported in all three tools; v2
Integer storage is i32; seed ByVal records are unsupported; bootstrap String
construction rejects zero. Neither route is qualified for the intended native
datatype/byte-text library yet. Restored executables match their backup manifest
but current v2/C runtime sources do not match its input hashes. Full procedure,
exact identities and limitations: `../../std-lib/FOUNDATION-EVIDENCE.md`.

The owner's subsequent usable-v2 goal is complete for the explicitly bounded
bootstrap contract. `bootstrap/build-v2.ps1` builds the current seed/runtime
and both v2 stages without backup executables, checks the LLVM fixed point and
passes 130 assertions. Byte/Integer storage, conversions, scalar record copies,
compact arrays, rejection and crash regressions are covered. Unsupported deep
value copies diagnose; long expressions now receive a depth-limit error. Use
`../UBE_Compiler_v2/FOUNDATION-VERIFICATION.md` for the current identities,
commands and limits. The initial failed-probe report remains historical evidence.

## Earlier native-value and byte/text checkpoints

Completed: the owner delegated syntax/ABI decisions with VB6 conventions
preferred where compatible. `../../std-lib/NATIVE-TYPE-PROPOSAL.md` now records
the adopted opaque scalar mechanism. Source-built v2 implements Byte/Integer/
Long-backed nominal values, synthesized zero/copy, explicit Pack/Unpack binding
and equality. Bindings must originate in the type's declaring source module.
That earlier native-value gate passed 204 assertions: 130 core,
66 native-value and eight ordinary-record checks. Test-only layout/entry
adapters preserve all production UBE bodies and type definitions. Exact
identities, commands, regressions and limits are in
`../../std-lib/tests/native-type/NATIVE-EVIDENCE.md`.

The subsequent owner-approved managed extension now supports ordinary array/
record value copies, precise roots, results, borrowing and failure-atomic storage.
The ordinary UBE decoder and ByteBuffer bodies pass the combined maintained
source gate: 296 assertions, including self-compilation fixed point, managed
failure/cleanup and library functional/cost/concurrency gates. Independent
allocator/copy instrumentation covers ten input sizes through both stages;
four native workers share immutable input with private mutable instances.
Exact identities, commands, observations and limits for that checkpoint are in
`../../std-lib/BYTE-BUFFER-EVIDENCE.md`. Initial failed storage probes remain
historical evidence. At that checkpoint, the full Library/native envelope, builtin String, UBE
CallNew scheduling and complete language were unqualified. That record preserves
the foundation before later source-input and concurrency work.

## Active next action

Continue the reviewed First checked native executable deliverable. Instruction
relocation fields, original effective offsets and signed linked targets are qualified
in NATIVE-INSTRUCTION-TARGET-EVIDENCE.md. Generated function-entry and storage-extent
checks now pass the production consumer gates in NATIVE-TARGET-OWNERSHIP-EVIDENCE.md.
Reference-cell names, ranges, contents and accesses now pass the production gates
in NATIVE-REFERENCE-POINTER-EVIDENCE.md. Next bind IAT/TLS-index locations and TLS
storage to the PE structures described in NATIVE-IMAGE-DIRECTORIES-INVESTIGATION.md,
reusing the existing image-span and directory-header logic in NativeUnwind.bas.
Preserve reference-cell/generated-owner checks and image-rebasing/DIR64 and CRT
TLS-callback obligations.
Retain global data-alias/resident-storage and build-owner obligations. Qualify
whole-function control flow and pointer/register propagation, including the
observed relocated tail jumps and termination-call closure for decoded INT3
traps. NATIVE-CONTROL-FLOW-INVESTIGATION.md records the concrete field, pointer-table
and API-return dependencies; do not infer safety from trap position alone.
Use the qualified production anchor/coverage/contribution index described
in NATIVE-CODE-OWNERSHIP-EVIDENCE.md; complete build-owner integration remains
pending. Complete operand/effective-target, pointer-cell/import/TLS,
unwind/call-site/prologue/recovery-reserve, startup/API/refusal and debug checks,
then the tool/build owner, diagnostic delivery, publication and fresh complete
source-cohort acceptance. Preserve the checked graph, immutable source owners,
private results, shared worker budget and qualified frontend/checker behavior.
This does not reopen semantic rules or introduce a new compiler generation,
phase interface, executor, commit or push.
