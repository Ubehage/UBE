# Native initialization support evidence

The compiler-owned emitter in src/NativeInitialization.bas implements the shared
module-state data and per-output inline access helper described in
[NATIVE-INITIALIZATION-IMPLEMENTATION.md](NATIVE-INITIALIZATION-IMPLEMENTATION.md).
This is a prerequisite for the reviewed First checked native executable item.

```powershell
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/initialization/check.ps1 -DiagnosticOnly
```

Report `bootstrap/out/native-initialization/5b66b3fa15104fec9230f1fcf8255369/report.json`
passes all 54 groups, exit 0. The emission/resource probe passes 2,097,299 assertions
per pinned bootstrap stage; that count includes exhaustive real-root pressure,
not millions of distinct programs. The report retains 106 process records with
82,393 ms summed elapsed time. Busy-cycle processes intentionally reach their
one-second observation deadline and are terminated by the bounded harness.

Both fresh compiler-stage raw LLVM images are 880,626 bytes, SHA-256
`C20A11C59C073C422A58903E655CB495928F4944871489F037F3C9EC5ADA4857`.
Both emitted support/observer units are 3,510 bytes, SHA-256
`99B94C146A439E3D03C187E78F47701C01144001058D6657BCEBAEBB0FEEFC45`.
Both emitted data units are 367 bytes, SHA-256
`30EC6F08AD570641099497DA20539CCFE0816249D7669192D22EE31EC995C308`.
Captured production source is 11,940 bytes, SHA-256
`3F8EEDBBA31B6C62057A0E216276729490025A45E3AC99A90E542AE2EFE5C202`.
The report retains complete tool, source, adapter and artifact identities.

## What passed

Two separately linked LLVM helper units refer to one production-emitted data
unit. Independent C initializer bodies and the real extracted error support
observe ten runtime modes at O0 and O2 through each stage:

- Early dependency completion, own-module access, local-storage bypass and
  exactly-once completion, including reuse from the other LLVM output.
- A recoverable expression error preserving successful completion and Err 11.
- Refusal before the first initializer, and refusal of a nested initializer,
  with exact non-entry/state/Err 28 observations.
- An initializer returning failure, and an outer initializer incorrectly
  returning true after nested failure: both retain the failure latch and prevent
  subsequent required modules from entering.
- A circular dependency enters the observed wait with each initializer entered
  once and neither completed. It does not recursively re-enter the active module.
- Refusal to enter the wait, and an out-of-range internal module identity, take
  the controlled fatal adapter (test transport status 97).
- A dependency already completed by the normal scheduling caller is not repeated
  when the dependent initializer later requires it.

The observer checks module states, entry/completion counts, completion order,
exact Err numbers and preservation/revision where applicable. Native effects use
real generated support, not a reimplementation of its transition logic. Test-only
wrappers expose states and supply C initializers; they are not a public source ABI.
The second helper unit differs only in test wrapper names. The actual support and
shared data are compiler-emitted. LLVM optimized at both O0 and O2 contains no
remaining function or call boundary for module.require or stack.admit; this checks
the selected always-inline behavior for the fixture, not full machine footprints.

Three native negative controls are rejected at independent observer assertions:
resetting completed state to not-started, bypassing initializer admission, and
incorrectly giving the second helper its own private state array. A fourth
control omitting observed index visits is rejected by the resource probe.

The compiler probe observes actual table/declaration visits. Shared data consumes
2*M work and M+3 identities for M=1,2,3,8,256; helper support consumes 41 identities
and no module-entry traversal. Independent emitted-definition inventories check
identity charges. Exact/below work, identity, byte and peak-payload limits,
invalid dimensions without Err corruption, persistent allocation failure,
pre-cancellation, cancellation at the 4096-visit boundary and real root-registry
saturation pass. Retained capacity matches charged payload and cleanup leaves no
roots or live allocations. There is no new compiler scratch arena or ByVal owner
copy. The test extracts the exact existing TryVisitNativeIndex and stack-support
function definitions, retaining their complete production source identities.

## Retained attempts and limits

Initial report 26adc5cf57074a7e8a50f48d26466a2d passed the emitter probe but Clang
rejected the test program's missing target declaration under -Werror. Attempt
aee4a541a8af4ed7a8ce2c4212262609 placed that declaration after definitions, which
LLVM rejected. The fixture now writes its target preamble before emitted support.
No production lowering semantics were changed to address those fixture failures.

Report 59318dea8a7c4bccbd4586a8a53afb45 passed the initial single-unit support.
The selected per-module buffer/object boundary required shared process data and
separate inline helper copies; it supersedes that intermediate arrangement.
Report 8f75372fc80a454f81c4cb6f18f56cbd passed the split arrangement. The final report
above adds the private-state/observed-work controls and explicit inline checks.

NativeInitialization is now in the compiler production manifest, and the focused
gate is registered in bootstrap/build-v2.ps1 with a 300-second deadline. These
DiagnosticOnly results use historical qualified df158 bootstrap tools on current
captured sources. They do not establish a new current-source bootstrap cohort.

The native observer supplies controlled frame sizes, floor and reserve. Its C wait
and fatal adapters are test-only. Actual platform waiting, linked footprints,
committed-floor startup and recovery/fatal qualification remain required. Real
checked module bodies, per-declaration neutral initialization, package/source
startup order, foreign read/write/call guards, ByRef ownership forwarding and
failure unwinding through generated procedures have not yet been connected to
this helper. Warning presentation, native tool/path/debug/CLI/publication and final
retained gates also remain unfinished. The approved declaration bound is still
2*D; this support proof does not resolve that separate review.

Registration checks pass: `rtk proxy powershell -NoProfile -File
bootstrap/out/check-native-registration.ps1` parses eight registered scripts.
The filesystem/schema check in bootstrap/out/native-initialization/registration.json
records 13 unique existing Core entries, 55 compiler entries, the new gate/deadline
and passing nonempty assertion descriptions. `rtk proxy git diff --check` exits 0
with only existing LF/CRLF conversion notices. The updated full bootstrap has not
run, and no qualification session remains live.

## Checked initializer bodies and indexed procedure roots

NativeGraph now retains ordinary procedure roots during its existing walk, in
one private Long array capped at min(F,V) entries. The 104-byte plan owner charges
four payload bytes per reserved root. TryReadNativeProcedureRoot checks its frame
interval and preserves the previous result on failure. The shared cursor can defer
a child only after its edge event; it creates no child frame or enter/exit event.
Pending/depth ownership remains inside the existing cursor and cleanup.

The maintained component command:

```powershell
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/emission/check.ps1 -DiagnosticOnly
```

returned exit 0 in
`../../bootstrap/out/native-emission/910aaae70fbc41f296342ef8a78c172e/report.json`:
26 groups, 54 bounded commands and 8,437,455 assertions per stage. Both raw images
are 1,226,239 bytes, SHA-256
`233AB712984A610F593519B8D1906C17BF76F398037A2C7F8B7330B146FC495A`.
Tests cover nonzero frame bases, empty indexes, rejected out-of-range, duplicate
and nonconsecutive identities, exact payload/work caps, immutable source, root
pressure, allocation failure and complete cleanup. Child deferral preserves
siblings and parent exit, with independently enumerated event/depth/work results
and no extra allocation or copying. Earlier index-only report
f8ba73d166a347df8700b075fcf5cba9 passed before child deferral was added.

The complete checked graph/body command:

```powershell
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/graph/check.ps1 -DiagnosticOnly
```

returned exit 0 in
`../../bootstrap/out/native-graph/e865f6e060bf48f9a85ea8abb6b0a09b/report.json`:
76 groups, 154 bounded commands, 967 graph and 2,106,947 body assertions per stage.
Both raw images are 7,753,713 bytes, SHA-256
`FA13C636308BAF16A8787B09953EB0C9AF793D7C42A847EFD301CA800A52DF10`.
The generated initializer unit is 9,607 bytes, SHA-256
`ED96D8869D25648B678C0162A7999E8293BBF6671C34BE4153AD7D2A8524BFB4`.
Prior scalar, native-type and ordinary-call LLVM files compare byte-identically
to the preceding 43e9a0e0382e45a784c743445d52d4eb checkpoint.

TryEmitNativeInitializer shares the procedure subtree walker and fixed temporary
allocator. Its real checked single-module source proves declaration order, the
neutral reset of a later global changed by an earlier helper, forced/default
ByRef temporaries and continued initialization after recoverable expression or
ordinary call-refusal errors. O0/O2 observers check every relevant global, Main's
result, actual TLS Err and revision. Normal execution yields Main 41350, Err 11
and one revision increment. Refusing all four ordinary calls yields Main 1000,
Err 28 and five increments, while the initializer still succeeds. Removing the
Later reset or changing the optional default is rejected by the same observer.
Jobs 1/2/4 match output bytes, work and identities; zero/below/exact/above
initializer work limits preserve counted cursor cleanup.

| Production source | Bytes | SHA-256 |
| --- | ---: | --- |
| NativeGraph.bas | 25,889 | 6B292155A5863DA3DECD4D40C6B0DD7689056D50DE36C1352F873D59B6BFB60E |
| NativeTraversal.bas | 11,203 | 5BBAD7D50B3C09F540CC8E28B5BE8228B35AF7698849539A22487654F06A7791 |
| NativeBodies.bas | 54,682 | F85A0001FC056B9CBFD257A655FC93B7AC5BA4390C50B033213D6C6CCA6648FB |

One initial graph launch was explicitly interrupted after a test-registration
script failed before adding the initializer adapter. It has no qualification
claim. The corrected maintained harness parsed and the fresh run above completed.
All test handles from this checkpoint are terminal. A focused historical checker
also admitted the initializer source at jobs 4. The separate pending multi-module
neutral-reset fixture now interleaves its helper between the two globals and
passes checker admission at jobs 1 and 4; its runtime outcome remains untested.

These commands use pinned df158 bootstrap tools on freshly captured source. The
full updated source-built bootstrap has not run. The native observer invokes the
initializer directly and uses controlled frame metadata: this proves body
emission, not integration with shared initialization state, exactly-once module
scheduling, foreign read/write/call or ByRef access barriers, required-module
failure unwinding, real linked stack footprints, platform wait or process startup.
Those remain necessary before complete native-executable acceptance.

## Checked access and failure-unwind integration - 2026-11-03

NativeBodies now guards actual foreign reads/writes, ordinary/intrinsic calls
after argument evaluation, and incoming ByRef dereferences. Exact unused alias
forwarding remains non-accessing. Ordinary calls check the shared failure latch
after their result merge. Failed requirements immediately return false from an
initializer, neutral scalar/native aggregate from a Function, or void from a Sub.
Ordinary stack refusal remains recoverable and does not set that latch.

The maintained guard-project contains three actual checked sources. Its native
observer links unchanged emitted bodies, shared initialization data and the
production always-inline requirement helper. Normal checks require foreign value
12, call result 17, native value 6, assignment/argument event sequences 49/59/69,
forwarded-alias events 98, and direct initializer/Main result 129. Reading after
a foreign write must retain value 4, proving the completed dependency is not
initialized again. Refusing C's initializer must leave B's earlier value 12,
set Err 28 exactly once, stop later effects, return neutral even after a prior
Function-result assignment, and unwind all active required initializers to
failed state. Unused aliases leave foreign state untouched. With the foreign
module active, the actual helper reaches the noreturn wait-entry observer.

The existing scalar/native/call observers use an explicit successful requirement
adapter for their one module. They retain their original value/error/ABI/control
oracles, but cannot qualify shared initialization behavior. The new guard fixture
uses the real helper. All frame-table declarations now agree on F+M+1 slots.
The new body flag fits existing padding; the owner remains 64 bytes and adds no
scratch payload or traversal. Existing work-cap/cleanup assertions remain active.

The initial maintained run in
`../../bootstrap/out/native-graph/431bd1f4d3f8464fa25865ed9df81df0/report.json`
passed first-stage body tests, then failed Clang's strict target-triple warning
because the new test-only shared-data output omitted its target header. No
production source changed in response. The corrected focused command:

```powershell
rtk proxy powershell -NoProfile -File bootstrap/out/check-native-guards-diagnostic.ps1
```

returned exit 0 in
`../../bootstrap/out/native-guard-diagnostic/238101e131d342698d5294f90cbd11a9/report.json`:
nine groups and 20 commands, using the retained first-stage adapter and current
native fixtures. Its body probe passes 2,107,242 assertions. The three negative
controls bypass access requirements, post-call unwind, or dynamic ByRef checks;
each returns exit 1 at its corresponding independent value/effect assertion.
Historical checker admission of guard-project also returned exit 0 with empty
output at jobs 1 and 4.

The fresh maintained command:

```powershell
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/graph/check.ps1 -DiagnosticOnly
```

returned exit 0 in
`../../bootstrap/out/native-graph/1d61ea91bdbd4e3f9bfb6bc15df92ed0/report.json`:
94 groups, 190 bounded commands, 967 graph and 2,107,242 body assertions per
stage. No command timed out. Both stages pass O0/O2 observers and every retained
negative control. Jobs 1/2/4 produce identical checked-body bytes, work and
identities; checked source graphs remain unchanged and scratch ownership closes.

| Current source/artifact | Bytes | SHA-256 |
| --- | ---: | --- |
| NativeBodies.bas | 60,504 | 4E809A488AA60BDA137A114DEBC0ABB258986590055E8AA400A1EC04A92AF5DC |
| Raw LLVM, both stages | 7,795,110 | 73E9205F8A6B6F256031CAC4D959DBD302C836A2E1641E584E11CEC4612424F7 |
| guard-bodies.ll, both stages | 19,893 | D889412AC422B6BBB1D8BA776C4453796BC40BDF61CCDB542CA21CFE95964F9F |
| guard-data.ll, both stages | 367 | 30EC6F08AD570641099497DA20539CCFE0816249D7669192D22EE31EC995C308 |

NativeInitialization.bas is unchanged from its 54-group support qualification.
The current graph report records all captured source/test/tool identities and
checks they are unchanged before reporting success. Strict C syntax checking and
`rtk proxy git -c core.safecrlf=false diff --check` also returned exit 0.
Handles 34225 (retained fixture-header failure), 76004 (focused diagnostic) and
6580 (complete gate) are all terminal. No test remains running for this checkpoint.

This fixture uses a combined test-only body unit, direct startup invocation,
controlled frame sizes and a wait-entry observer. It does not prove per-module
output/imports, normal package/source scheduling, actual stack footprints,
platform waiting, native CLI/tool/path/debug/publication or a refreshed complete
source-built bootstrap. Those remain required, as does the outstanding reviewed
declaration-work bound. The full native-executable goal remains active.

## Normal package/source schedule - 2026-11-03

TryEmitNativeProjectInitialization validates canonical checked source/package
associations in M source-record visits. TryEmitNativeInitializationOrder then
emits M requirements, preserving manifest order within the direct library and
executable packages while initializing the library first. The private Boolean
helper is always-inline, skips completed dependencies through the existing
shared state helper, and returns false immediately on failed required startup.
It owns no scratch arrays and charges 2*M+3 emitted identities plus output bytes.
The checked adapter and schedule together charge 2*M work, without another
declaration or body traversal.

```powershell
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/initialization/check.ps1 -DiagnosticOnly
```

returned exit 0 in
`../../bootstrap/out/native-initialization/5253acf4ac2b45668f302f77991e20a5/report.json`:
118 groups, 222 bounded commands and 2,097,396 emission assertions per stage.
Normal order is independently observed as 231, 312 or 123 for three sources
with root-package counts 1, 2 or 3. Early dependency completion and an already
completed module are not repeated. Refusal stops the remaining schedule and
preserves the exact Err 28/revision result. O0/O2 optimized IR contains no
remaining initialize/require/admit helper boundary. The emitted schedule identity
inventory matches its charge, and invalid dimensions, zero/below/exact work,
identity/byte/payload limits, cancellation, allocation/root failure and cleanup
pass. Changed order and ignored-failure controls return exit 1 at their native
observer. The four timed-out children are the existing expected active-module
wait controls, each with its required waiting marker; all are terminal.

The component fixture extracts the exact scalar schedule/support functions from
the captured NativeInitialization source. It excludes only the checked-catalog
adapter, which requires the complete compiler and is qualified below. No mock
catalog implementation is substituted. The earlier abaae58c2d174ac6931f58d9bdf62eae
run passed before the final target-identity/inlining and extra dimension checks;
5253 is the complete component checkpoint.

```powershell
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/graph/check.ps1 -DiagnosticOnly
```

returned exit 0 in
`../../bootstrap/out/native-graph/794008b5eaad41528377963bf5c9b8d8/report.json`:
118 groups, 238 bounded commands, 967 graph and 2,107,571 body assertions per
stage. Actual checked projects exercise one package and an explicit UBECore
reference. The observer checks initializer completion, Main results 129 or 449,
retention of an early-completed dependency's modified value, no repeat, and
required-initializer failure. Failure leaves A unstarted when its library fails
first, but marks active A failed in the single-package schedule. Exact emitted
order and 2*M work/2*M+3 identities match at jobs 1/2/4; invalid source/package
counts fail before indexing or output. All retained body/guard/ABI/error/control
tests and negative controls pass through O0/O2.

| Current source/artifact | Bytes | SHA-256 |
| --- | ---: | --- |
| NativeInitialization.bas | 16,859 | 665D829BF3A833A98DE9E73818BB234B15A64ABEE2FCA72473FC476EF78C5221 |
| Component raw LLVM, both stages | 891,175 | 28C700F865C51ACDA1D8C65B69128CAE87C9B3B6B51204F14F00EDEC1C6BBFBC |
| Component order-2 unit, both stages | 3,729 | 71A1A8525892DA7B8D2FDF754E59EB2F64E736C9F89C04E75A288133261E18AB |
| Complete graph raw LLVM, both stages | 7,835,647 | 0429AAF25EEDE45332EEE60E5114790C5B759EDC304016F5B4A0E944AE301507 |
| One-package body unit, both stages | 20,439 | E304085E21EB1E6F894B6C51B36BA784632F5E2BF11FD1DBA8184F44ECEB8497 |
| Direct-reference body unit, both stages | 20,439 | A446361D1A81083571CA89AF93A15CAE0FFF65751F1048369800065944E0F062 |

All handles from this continuation (97567, 55567 and 82256) are terminal. Strict C
syntax checks, historical direct-reference source admission and
`rtk proxy git -c core.safecrlf=false diff --check` returned exit 0. These are
pinned-bootstrap/current-source component gates, not a refreshed complete
source-built bootstrap. The normal schedule helper is qualified; the test still
combines checked bodies into one LLVM unit and invokes the helper/Main through C.
Per-module typed imports, ordinary process entry, real stack footprints/platform
wait and tool/path/debug/CLI/publication remain unfinished.

The owner has approved 3*D declaration work for preparation and definitions.
The separate concrete 3*D+I typed-import proposal remains pending in
NATIVE-DECLARATION-WORK-REVIEW.md. That approval boundary does not prevent the
independent schedule work above and does not change any numerical cap.
