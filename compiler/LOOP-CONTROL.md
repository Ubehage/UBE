# Loop control implementation and acceptance

This is the existing Workplan Exit Loop increment, implementing
`lang-doc/language-spec.md` section 9.1. Completion requires the full approved
contract, not merely nested Do execution.

## Completion audit

The corrected final compiler passes the contract and regression gates below.
Earlier frozen-compiler and isolated primitive results are historical checkpoints;
the final qualification update identifies superseding evidence.

Resolved evidence caveat: the enumeration-lease oracle exposed a test that
raised directly in a procedure while expecting its own handler. UBE Err.Raise
exits that procedure; only a caller handler can receive that failure. Several
functional entry points used `If Not Test() Then ...`, whose entire assertion
can be skipped if Test reports FAIL. Affected fixtures have been corrected to
call a raising helper and to reject unexpected FAIL independently of the
condition and rerun with deliberate escaping-FAIL controls. The hardened
evidence below supersedes those earlier functional passes. Exact ownership
instrumentation also passes with the corrected source fixtures. No
language-definition change was involved.

The hardened non-enumeration fixtures have now been rerun on d6c55de7:

```powershell
rtk proxy powershell -NoProfile -File compiler/tests/loop-control/check.ps1 -CompilerExe <UBE> -Counted -Floating -Managed -Resources
rtk proxy powershell -NoProfile -File compiler/tests/loop-control/counted-boundaries.ps1 -CompilerExe <UBE>
rtk proxy powershell -NoProfile -File compiler/tests/loop-control/helper-failure-check.ps1 -CompilerExe <UBE>
```

All pass: 24 native executions plus 15 rejections in `ube loop control
fa8b7b5e-a927-4b88-80d7-007da1f47173`; four native executions plus six
diagnostic/recovery cases in `ube counted boundaries
8bdec57a-4a4d-4d8d-abe0-477ec806a85d`; and ten deliberately escaping helper
failures in `ube loop helper failure d8fa7938-4fdf-4d5c-9f0c-c73d5ee7098f`.
The last gate injects Err.Raise 47 and requires the fixture-specific nonzero
result at O0/O2, proving those entry points cannot silently pass a skipped
If assertion. Intentional default-continuation tests retain disabled handlers.

The corrected/hardened enumeration-lease gate also passes:
`compiler/tests/loop-control/foreach-lease-check.ps1 -CompilerExe <UBE>`,
14 O0/O2 positive and deliberately incorrect balance/root controls in
`ube foreach lease check 41bdd897-a987-4e63-8413-6a0d38d1e293`.
It wraps actual emitted snapshot/drop calls, retains their behavior, and checks
the owner ledger at source-visible boundaries: nested enumeration, nearest
Exit For, Exit Loop, default failed boxing, handlers outside/inside enumeration,
and negative-bound String arrays. Actual drop sites must see cleared lower,
upper, payload, owner and index slots. The source control variables remain
readable after construct-owned state is retired. This supersedes the earlier
failed handler test; no production correction was needed.

The hardened full enumeration gate subsequently passed all ten native runs on
d6c55de7 in `ube foreach control dcfc726e-66d3-4486-a285-b5f1cd99a358`:
`compiler/tests/loop-control/foreach-check.ps1 -CompilerExe <UBE>`.
This includes scalar/String/Variant/record and object arrays, nominal/generic
reference boxing, mixed-loop variable preservation, recursive Exit Loop,
O0/O2 exact-zero and changed-expectation-one results, and injected escaping
helper FAIL returning 10. The syntax gate also passed six cases in
`ube foreach syntax 1e3d09e7-18e5-4562-a4dc-12e8eaf8a465`.

Hardened class references and locks each pass six O0/O2 runs, including
escaping helper FAIL returning 90. Evidence: `ube object references
923d86a6-9917-4e9f-8004-4b6750e5eb63` and `ube object references
5741bf8b-836e-45a0-9551-7336a564f9d0`. The updated deterministic cleanup oracle
passes four runs in `ube source monitor oracle
a13f3d93-2eca-4919-9131-d1c1be11be85`. Direct Err.Raise in the lock-owning
procedure is included. `compiler/tests/object-monitors/retirement-check.ps1
-CompilerExe <UBE>` additionally passes eight injected cleanup-failure runs,
covering ordinary block exit and procedure return, caller Err/output retention,
local-handler bypass, exactly one terminal cleanup and no acquired-release
retry. Full paths, source hashes, commands and exclusions are in
[the object-monitor test record](tests/object-monitors/README.md).

| Requirement | Final evidence on corrected compiler 68e264aa |
|---|---|
| Outermost lexical loop across For/For Each/Do/While | Hardened all-four-kind fixtures and scalar/String/Variant/record/object enumeration pass O0/O2 with changed-expectation and escaping-FAIL controls. |
| Intervening non-loop blocks | do-control retains its enclosing If continuation; locks.MixedExit retains the outer SyncLock while retiring the inner lock. Exact busy-result and release-count observer passes. |
| Current invocation only, including recursion | RecursiveExit(4), NestedCall(4), and recursive enumeration return 5. RecursiveLocks observer checks depths 5,4,4,3,3,2,1 and exactly seven releases, preserving caller ownership and Err 75. |
| Invalid placement and named exits | Diagnostic gates preserve output sentinels and recover deterministically. Nested named Do/For/While assertions require the outer loop to continue; lease/lock gates prove named-exit cleanup. |
| Skip increments and conditions | Counted/floating counter assertions, Do/While condition-call counts, and mixed enumeration control-variable values prove the exit path bypasses remaining bodies, increments and tests. |
| Managed lifetime correctness | Retained(3) keeps procedure-local strings/arrays usable through collection and resizing. Enumeration lease oracle requires 1→2→1→0 active leases and cleared 0/-1 bounds, null payload/owner and index 0 before actual drop. |
| Automatic lock cleanup | MixedExit observes inner worker phase 1 and retained outer worker phase 2. ReentrantExit checks depths 2 then 1. Failure/return tests prove one terminal cleanup, no acquired-release retry and later successful acquisition. |
| Preserve explicit user resources | resource-control preserves the file token, writes after Exit Loop, then explicitly closes. The harness requires exact file bytes 41,42. |
| Ordinary flow and failure recovery | Err 17 survives Exit Loop; unexpected FAIL controls fail independently. Header/conversion/allocation/retirement failure gates preserve unfinished destinations and recover without using failed values. |
| Regression qualification | Renewed fixed point, both generations' 518 common CLI assertions, unchanged fresh seed corpus, current-source concurrency and 340 package assertions pass. Exact provenance follows. |
| Documentation | All 32 final-compiler manual-example checks, structural validation and 13 navigation-logic groups pass. Fresh browser rendering remains unverified due to tool-access restrictions; no visual pass is claimed. |

The ownership observer checks six selected identities and real contention;
resource coverage uses a real file handle. Managed-local checks prove lifetime
and usability, not a reclamation time. These are the scopes of the evidence.

## Corrected compiler qualification update

These results use generation 2 of `68e264aa` identified below and supersede
the earlier checkpoint results for these gates. Each script uses
`rtk proxy powershell -NoProfile -File` and `-CompilerExe` pointing to that
executable. Evidence directories are under `%TEMP%`.

| Script under `compiler/tests/` | Result | Evidence directory |
|---|---|---|
| `loop-control/check.ps1 -Counted -Floating -Managed -Resources` | 24 native executions and 15 rejections | `ube loop control 92d5640f-421c-4a30-91fd-83b004305a80` |
| `loop-control/counted-boundaries.ps1` | 4 native and 6 diagnostic/recovery cases | `ube counted boundaries 371acfc0-173c-4cfe-96b8-77b8f8a91b83` |
| `loop-control/helper-failure-check.ps1` | 10 injected helper failures | `ube loop helper failure bfd6f88e-f80f-43f4-98ea-82daa2698a6e` |
| `loop-control/foreach-check.ps1` | 10 native controls | `ube foreach control 39fd1376-dc9d-469d-acab-7108cf0f5881` |
| `loop-control/foreach-lease-check.ps1` | 14 ownership/root controls | `ube foreach lease check 3dc30e7c-b0a5-45c2-b667-9d05f98953b1` |
| `loop-control/foreach-failure-check.ps1` | 8 failed-value controls | `ube foreach failed values dd67b90f-1204-46de-95a3-99cff1261ba3` |
| `loop-control/foreach-syntax-check.ps1` | 6 diagnostic/recovery cases | `ube foreach syntax fca74f75-22c5-4585-b9a4-ef88b55dac72` |
| `object-monitors/admission-check.ps1` | 13 admission cases | `ube class admission 272859cc-813e-46af-8c1c-c44e5639918c` |
| `loop-control/construct-diagnostics.ps1` | 7 diagnostic/recovery cases | `ube construct diagnostics bc55725e-e667-4124-9b74-03ca6460a100` |

Corrected generation 1 also passes all 518 compiler-only common CLI assertions
in `ube compiler conformance d3734aab-c932-423a-a23b-4ab9237472bd`, using
`bootstrap/tests/self-hosting/check.ps1 -CompilerExe <generation-1/UBE.exe>
-CompilerOnly`. This explicitly reuses the unchanged seed corpus described below.

`rtk proxy powershell -NoProfile -File bootstrap/tests/self-hosting/package-check.ps1`
passes all 340 assertions on final sources, including ancestor-junction
rejection and sentinel preservation. Evidence: `ube self-host sources
d5597e89-91f3-48ea-b1bb-ff9f29c8e5ad`.

Final audit inspection of `NativeControl.TryEmitEach` confirms that the
increment block compares index >= upper bound and exits before advancing.
`CompareGreaterEqual` emits signed `icmp sge i64`; subtracting -1 to advance
is reached only below the upper bound. This resolves the suspected maximum-index
wrap concern by source inspection, not a new runtime-test claim.
Final object/monitor repetitions also pass on corrected generation 2:

| Script under `compiler/tests/object-monitors/` | Result | Evidence directory under `%TEMP%` |
|---|---|---|
| `reference-check.ps1 -CompilerExe <UBE>` | 6 O0/O2 runs | `ube object references 47e66ae3-d4e9-4df7-a7b3-08182d6ba72d` |
| `lock-check.ps1 -CompilerExe <UBE>` | 6 O0/O2 runs | `ube object references a6c0bff0-6f37-4b0a-8658-4d7f5e9479f5` |
| `cleanup-check.ps1 -ProgramIR <locks evidence>/locks-O0-positive.ll` | 4 O0/O2 runs | `ube source monitor oracle 90000466-1440-4013-a042-6f204b6025a9` |
| `retirement-check.ps1 -CompilerExe <UBE>` | 8 O0/O2 runs | `ube retirement failure 4c1224dc-b5cc-45ec-a979-ed0a1dfc340b` |

The retirement statement and return oracles are respectively `ube source monitor
oracle f2176b11-3b2e-4b0a-8fa6-efe490583524` and `ube source monitor oracle
06b296f6-fc5b-4bea-b809-8fb649aca200`. All four scripts exit zero, including
changed-expectation, escaping-FAIL, cleanup-counter and injected retirement
failure controls.

The final compiler also passes all 32 extracted manual-example runs:
`rtk proxy powershell -NoProfile -File docs/assets/tools/check-loop-examples.ps1
-CompilerExe <UBE>`. Evidence: `ube loop examples
c4a66fcb-edea-43ba-a84b-1b9c9c534e85/report.json`, with matching compiler hash,
article/source hashes and exact O0/O2 positive 6/negative 7 results for For,
Next, Step, While, Wend, Each, New and SyncLock. The empty-class support source
for the last two examples is extracted from the public manifest documentation.
`rtk proxy powershell -NoProfile -File docs/assets/tools/validate-docs.ps1`
passes 278 HTML files, 4793 local links/assets/anchors and 191 word pages.
Fresh browser rendering remains unverified for the automation limitation
described below. The requirement-by-requirement audit is complete;
the completion matrix above records the final clause-by-clause audit.

## Current implementation

After the O0 helper correction, the renewed fixed point passes in
`ube compiler rebuild 68e264aa-a894-4b53-83cc-6ebf408cd931`.
The two fresh builds took 34524 and 34268 ms. Current source/assets match,
LLVM is byte-identical (SHA256
`2F55A135405F0E23696CC95822EED065EE562DB9D4F406D6ECCF1817254E9B65`),
and native differences are confined to the COFF timestamp. Its
`generation-2/UBE.exe` has SHA256
`B552033397CAAEA7A86FAF2F541A47F11318F0C1CC04C85F4905D998809A65DC`.
This is the current candidate for final qualification. The following earlier
fixed-point and conformance records are checkpoints, not substitutes for
regression gates on this corrected compiler.

The corrected current-source concurrency gate passes:
`bootstrap/tests/concurrent-compilation/check.ps1 -BootstrapExe <0c4aedea seed>`,
evidence `ube concurrent compilation 5ad82366-ee4e-466c-a814-c8cff1c72129`.
It covers single/two-worker emission, simultaneous independent requests,
failure beside success, staggered O2 scheduling, cancellation, worker failure
and recovery, fresh failure with Err zero, catalogue-copy failures, cleanup,
quotas and competing publication. Backend timeout/isolation checks include a
real 30.824-second timeout followed by recovery. The original O0 link defect
is resolved with no missing helper or runtime shim.

Corrected generation 2 also passes all 518 compiler-only common CLI assertions
in `ube compiler conformance c2db950e-ea62-431e-bdcc-d3e8ab45835b`, using
`bootstrap/tests/self-hosting/check.ps1 -CompilerExe <68e264aa generation-2/UBE.exe>
-CompilerOnly`. The unchanged fresh seed's assertions are explicitly reused
from the passing full 1004-assertion run `2564cada`; this is not a claim that the
corrected compiler and seed were rerun together in one invocation. Generation 1
and the final focused fixture repetitions pass as recorded above.

Earlier checkpoint rebuild qualification passed in `ube compiler rebuild
bce837ee-91d1-4d22-8a91-b719e1ba34b0`, using
`bootstrap/tests/self-hosting/rebuild-check.ps1 -InitialCompilerExe <d6c55de7/UBE.exe>`.
Both fresh builds completed (33.8 and 34.0 seconds); source and asset ledgers
match, LLVM is byte-identical, and native images differ only in the COFF
timestamp. LLVM SHA256 is
`BF0ED470FEF5AD8ACE3BD6E0362C98BB9CBDF79E066947957642B78C8178441C`.
That checkpoint compiler is `generation-2/UBE.exe`, SHA256
`716DFCFD29A3F636EFCE942D6785E07FA1E81D46095B2C0497D17DC2B05ADEBC`.
The current-source VB6 seed passed all 90 source-scanning groups in
`ube source scanning 0c4aedea-2c28-449d-8870-179595af913a`; use its
`build/UBE-Bootstrap.exe` for final common/concurrent qualification.
Its later integrated gates exposed the O0 frame issue described next; the
corrected 68e264aa results above supersede this checkpoint.

Common CLI qualification passed on this checkpoint: generation 2 plus the fresh
seed passed 1004 assertions (`ube compiler conformance
2564cada-70ed-459e-819a-596ab0fe4f90`), and generation 1 passed the 518
compiler-only assertions while explicitly reusing that seed result
(`ube compiler conformance d57b17a5-58f9-4db7-9ae0-0eb810d5fc20`).
The current-source concurrency gate then stopped before its assertions because
the fresh seed's O0 native driver requires an unresolved stack-probe helper.
Assembly isolates four production routines: BindCall 5928 bytes,
BindAssignment 5752, NativePlanning.PlanNodes 4104, and NativeFrames.EmitFrame
4704. Evidence is `ube concurrent compilation
8090bb75-2f9f-48c0-8315-e0c160cf8a64/single worker.s`.
Following the existing native-lowering precedent, focused helper extraction
now passes the whole production-plus-driver O0 assembly check: no __chkstk
reference remains. BindCall is 2072 bytes, BindAssignment 920, PlanNodes 1656,
and EmitFrame 2160. The new domain helpers range from 1224 to 3856 bytes.
Evidence is `ube compiler frame verification
21b68fb7-4a5b-4d03-b7dc-4ffd10d01091/corrected-o0.s` and its frame report.
Ordered-body comparison retains the checks and evaluation order; no stack-probe
suppression, test-only shim or runtime change was introduced. Fresh rebuild and
regression qualification are running after that correction.

Both the VB6 bootstrap and UBE compiler parse, bind and lower Exit Loop within
Do, While and counted For loops. Conditional loops share parsing and emission routines,
retaining distinct syntax kinds and nearest named-exit targets. The outermost
continuation is selected by lexical emission depth, separately from its label:
label zero is a valid procedure return. All state belongs to the existing
emission request; no runtime search of callers or global loop state is used.

The UBE project-snapshot validator also admits the While syntax kind. A focused
mixed-loop client exposed its old upper-kind bound as controlled E_COMPILE
0/9/1; updating that bound permits the same client to execute successfully.

The owner delegated implementation choices on 2026-11-27 while requiring that
established definitions remain intact. Header failure rules are reconciled in
`../lang-doc/error-handling.md` and `../project-docs/Error-Handling.md`.

The current integration sources now contain real Variant boxes, retained array
enumeration, genuine empty class identities, reference assignment/conversion,
and SyncLock emission. These changes are awaiting a coordinated integrated
build and source-level gates; their presence is not a qualification claim.
The clean VB6 seed retains its documented scalar bootstrap profile. Production
compiler sources remain seed-admitted; recreating the production managed-value
pipeline inside the seed is not a dependency of this increment.

Construct-owned state is invocation-local frame storage. Destination entry
retires exited enumerations and monitors in reverse lexical order; enclosing
constructs remain active. Each SyncLock retains its evaluated identity and a
separate acquired flag. Failed acquisition never releases an unacquired lock.
A destination inside a monitor body requires an active acquisition before
executing source statements. Internal cleanup failures aggregate into a
controlled procedure failure instead of recursively reentering source handlers;
failed release slots are not retried during terminal cleanup. Valid owned
monitor releases are allocation-free and infallible under their invariants.

Class type metadata is nominal, with one managed reference cell rather than a
copied value-record payload. Native class descriptors retain the actual type
identity when a generic Object is boxed into Variant. Empty Variant converts
to a neutral reference; Null or incompatible boxed values report controlled
failure without committing the destination. Class members were excluded from
this loop increment; the later CLASS-MEMBERS.md increment qualifies ordinary
fields/methods and Me. Lifecycle hooks, forms and controls remain unsupported.

The first integrated class admission probe exposed a missing class-container
entry in `DeclarationBinder.TryBuildIndex`. Its completeness check returned
False, which expression binding reported as E_COMPILE 0/7/1 even though Err was
zero. A frozen compiler with only the container-registration correction emits
the same empty-class project successfully. The production index now registers
both module and class containers. The function-result restriction likewise
distinguishes value records from scalar nominal object references. Fresh
integrated source execution remains the acceptance gate for these changes.

The next package, `ube loop dependencies compiler
934baae7-b163-4a48-a77c-febfa45bdcb2`, includes the corrected index and all 15
managed-support sources. Its expanded non-object enumeration fixture passes
all four O0/O2 controls, including the new control-variable preservation
assertions, in `ube foreach control c4b6aa99-3fe3-4fd8-b34b-90a38fc82991`.
Object emission then exposed an undefined class-container initializer wrapper.
Startup already calls these wrappers for every loaded source container;
NativeLowering now emits them for classes too, with matching frame planning.
That correction awaits the next build and native object execution gate.

On package `934baae7-b163-4a48-a77c-febfa45bdcb2`, the combined command
`compiler/tests/loop-control/check.ps1 -CompilerExe <UBE> -Counted -Floating
-Managed -Resources` passed its negative diagnostics and O0/O2 execution
controls in `ube loop control 9ee4d443-b79e-45c1-a29f-fdf60ebcee97`. This repeats
the procedure-local survival and explicit file-resource assertions with the
integrated construct-cleanup emitter.

On the same package, `compiler/tests/object-monitors/admission-check.ps1
-CompilerExe <UBE>` passed 13 admission/rejection checks in `ube class admission
54249d09-6d54-4fb7-a372-d85d41ec5778`.
`compiler/tests/loop-control/construct-diagnostics.ps1 -CompilerExe <UBE>`
passed six cases in `ube construct diagnostics
e73ca5f9-666e-474a-86e7-b7beb92309fd`: scalar For Each counter, mismatched Next,
Next crossing SyncLock, wrong lock delimiter, Exit Loop without an enclosing
loop, and scalar lock target. Each asserts emit/build rejection at its exact
source location, sentinel output preservation, admission after one correction,
and deterministic successful recovery with no leaked publication stages.
These checks do not qualify native class execution or lock release semantics.

Package `ube loop dependencies compiler d6c55de7-ddcd-40f9-9101-019142785421`
then passed native class references and source locks:

```powershell
rtk proxy powershell -NoProfile -File compiler/tests/object-monitors/reference-check.ps1 -CompilerExe <UBE>
rtk proxy powershell -NoProfile -File compiler/tests/object-monitors/lock-check.ps1 -CompilerExe <UBE>
rtk proxy powershell -NoProfile -File compiler/tests/object-monitors/cleanup-check.ps1 -ProgramIR <positive lock fixture LLVM>
```

Reference evidence is `ube object references
a5ba85ce-f551-4843-ab61-c990abadc12b`; lock evidence is `ube object references
0fa38f36-917c-4e1e-8097-60c0018dda18`. Both pass O0/O2 zero/one controls.
The independent emitted-cleanup oracle passes O0/O2 zero/99 controls in
`ube source monitor oracle 3f1cb9f5-1a54-4804-8b94-ca1f3d31f409`. It observes
actual worker busy results, checks exact reentrant depths and release counts,
and verifies release placement across Exit Loop, enclosing locks, retained
inside handlers, failed headers, and recursive invocation returns. Its bounded
handshake requires an observed monitor result; elapsed time is not its proof.
The O0/O2 source LLVM is identical with SHA256
`64196F89E6B504E1EC088E22482CF58EDC1C053C8CA7402E07AE059E010B7EBB`.
The package source gate also passes 340 assertions in `ube self-host sources
66079ee6-81bb-4a65-a1f2-741324b1e083`; this does not establish executable
self-host fixed point or final common/concurrent regression gates.

The expanded scalar/String/Variant/record enumeration fixture passed O0/O2
positive and changed-expectation controls on package `ube loop dependencies
compiler a53d6ac1-d1ee-4a5b-8998-0f88ee0aab03`, evidence `ube foreach control
8de229bb-b3ff-4513-a5ef-b52fb6c9e133`. Its separate object fixture encountered
the class-index defect above; this is not a whole-suite pass. Later assertions
for preservation of the control variable after empty and completed iteration
still require a rerun.

`compiler/tests/loop-control/foreach-failure-check.ps1 -CompilerExe <UBE>`
passed all eight injected-boxing-failure cases in `ube foreach failed values
61644aa9-654a-4948-90e4-f0b68e476b03`: first/second iteration, default skip or
enabled handler, at O0/O2. It checks Err 7, body count, preservation of the
previous control value, and empty native stderr. This synthetic call failure
isolates continuation semantics; real allocation refusal is tested separately
by the native Variant storage gate.

## Completion and handoff

The approved Exit Loop increment is complete for the admitted compiler profile.
No production changes followed the corrected fixed-point build. The final audit
added one test-only nearest-While assertion: two nested While loops separated
by Do must leave the inner While and execute the outer body twice.

Both commands use the corrected generation-2 executable:

- `rtk proxy powershell -NoProfile -File compiler/tests/loop-control/check.ps1 -CompilerExe <UBE>`: seven rejections and eight O0/O2 positive/negative executions pass, evidence `ube loop control 6884158a-640b-41c8-87a4-cf5be1fce47a`.
- `rtk proxy powershell -NoProfile -File compiler/tests/loop-control/helper-failure-check.ps1 -CompilerExe <UBE>`: all ten injected escaping-FAIL controls pass, evidence `ube loop helper failure b6efe30d-f2bf-4f28-b997-bddedf25b9f2`.

The full loop/ownership/monitor contract and required compiler regression gates
have passed. Documentation limits admission: array For Each, empty named
classes and the Variant/reference operations needed here do not claim collection
objects, class members/hooks or a complete Variant library. The scalar bootstrap
profile is unchanged by the managed dependencies. Explicit Resume targets beyond
If/Do remain a separate documented decision.

Fresh browser rendering remains unverified: the browser access host was
unavailable and native browser automation could not enforce URL policy.
Structural links/assets, navigation logic and compiled examples passed within
their stated scopes; none is claimed as visual verification. This limitation
is retained in the public documentation verification record.

The existing IS_IN_IDE workplan item remains unstarted; completing this goal
does not start another increment or expand its architecture.

## Counted-loop checkpoint, 2026-11-27

Counted For now retains initial value, bound and step, evaluating them once in
source order before assigning the counter. Bound and step live in invocation
frame storage. Checked increments preserve the counter on overflow. Stable
record-field counters and shared `Next inner, outer` terminators are admitted;
array-element counters and active reuse of the same counter are rejected.
Exit Loop skips the increment and preserves nearest-kind Exit For behavior.

The frozen UBE package is `%TEMP%/ube counted compiler
adaa8918-0a76-47c4-aa12-e13e044a4839/UBE.exe`; its bootstrap counterpart is
`%TEMP%/ube source scanning d79863ff-efbd-40d4-ab9e-6f6637d33bd4/build/UBE-Bootstrap.exe`.
Commands below use those two paths:

```powershell
rtk proxy powershell -NoProfile -File compiler/tests/loop-control/check.ps1 -CompilerExe <UBE> -Counted -Floating
rtk proxy powershell -NoProfile -File compiler/tests/loop-control/check.ps1 -CompilerExe <bootstrap> -Counted
rtk proxy powershell -NoProfile -File compiler/tests/loop-control/counted-boundaries.ps1 -CompilerExe <UBE>
rtk proxy powershell -NoProfile -File compiler/tests/loop-control/counted-boundaries.ps1 -CompilerExe <bootstrap>
rtk proxy powershell -NoProfile -File bootstrap/tests/source-scanning/check.ps1
rtk proxy powershell -NoProfile -File bootstrap/tests/self-hosting/check.ps1 -CompilerExe <UBE> -BootstrapExe <bootstrap>
```

All passed. The focused UBE/seed evidence directories are respectively
`ube loop control 01e1c948-7e80-44d4-9bc7-080251f8d375` and
`ube loop control 30ce4b80-7914-4835-8d45-27983d18e2b8` under `%TEMP%`.
These assert 15 rejected programs, preserved output, and positive zero versus
changed-expectation one at O0/O2. UBE also checks Single/Double counters.
Independent header-conversion, increment-failure, handler and malformed/depth
checks passed in `ube counted boundaries f6351b0a-c65f-4d67-8a66-b9664ad2317e`
and `ube counted boundaries 68ef56de-9538-4e7c-9c07-ed3ca9e552c2`.
The fresh source-scanning gate passed 90 groups. Common CLI conformance passed
1004 assertions in `ube compiler conformance 760d55c6-5b1a-4366-810d-3296ecaca9f4`.
These do not establish the final expanded-loop fixed point or concurrency gate.

`compiler/tests/loop-control/vb6-order-check.ps1` passed its actual VB6 trace
oracle 293919 in `ube vb6 loop order 0d379df1-9366-4ab8-b999-471fdec86006`.
Classic VB6 evaluates bound/step/start before committing the counter. UBE's
explicit left-to-right rule takes precedence over compatibility fallback, so
UBE deliberately evaluates start/bound/step instead.

For Each requires real Variant storage, retaining the source array's original
payload during enumeration, and cleanup for exited constructs. This dependency
is being implemented; typed-only array iteration is not a substitute for the
classic Variant-counter requirement. SyncLock needs genuine object identity and
reentrant monitors. Neither dependency is qualified by the scalar gates above.
Ordinary Dim locals remain procedure-scoped: leaving a loop must not clear a
local merely because its declaration text appears inside that loop. Retained
enumeration state and acquired monitors instead belong to their constructs.

Two additional lifetime guards pass on the frozen counted-loop compiler:

```powershell
rtk proxy powershell -NoProfile -File compiler/tests/loop-control/check.ps1 -CompilerExe <UBE> -Managed
rtk proxy powershell -NoProfile -File compiler/tests/loop-control/check.ps1 -CompilerExe <UBE> -Resources
```

The managed-local fixture declares a String and dynamic String array inside
mixed For/While/Do loops, exits the outermost loop, explicitly collects, reads
and resizes the retained values, and repeats through four recursive invocations.
O0/O2 exact-zero and changed-expectation-one checks pass in
`ube loop control c15792d8-0e2d-48b9-921b-768b12d785fd`. The initial test's
negative result was wrapped as 91 by the recursive helper; the fixture now
propagates the failing assertion code, and the complete gate passes.

The resource fixture opens an explicit file inside the outer For, writes byte
41, exits through While/Do nesting, writes byte 42 afterward, and closes only
by explicit call. O0/O2 zero/one controls and external exact-byte assertions
pass in `ube loop control 9b2449ea-b5fe-4c54-a784-8a4b5cfbb6d4`. The harness
runs inside its private temporary directory. These are guards against clearing
procedure locals or closing user resources; monitor/enumerator cleanup still
requires separate positive ownership-release tests on the final compiler.

## Focused evidence, 2026-11-27

Object dependency baseline: an actual empty `Gate.cls` with `UBE SOURCE 1 CLASS`
and a Main module declaring `Dim Value As Gate` fails on the frozen counted
compiler at the manifest Source entry (E_LOAD 4/6/0), preserving sentinel output.
Evidence: `%TEMP%/ube class admission baseline 701cd772-4cad-46ed-a232-9ec4b750608d`.
The manifest previously admitted only .bas. Current unqualified edits add .cls
loading, extension/header agreement, an explicit ClassNode root and nominal
reference types. Empty classes can contain Option Explicit; class members and
hooks remain explicitly rejected until implemented. These edits are not yet
source-execution-qualified and do not implement New/Set/SyncLock by themselves.

The independent native object/monitor gate passes:

```powershell
rtk proxy powershell -NoProfile -File runtime/tests/object-monitors/check.ps1
```

Evidence: `%TEMP%/ube object monitors f38a2a03-a3c1-43c2-a6d4-b1fde4e59fcf`.
At O0/O2, three runs each assert real object allocation, Nothing failure,
reentrant ownership, owner/waiter identity roots, collector rendezvous,
release/acquire visibility and preserved Err. Deliberately clearing reentrant
depth on the inner release fails the oracle. The automatic collector callback
in this native test is intentionally a no-op: this gate does not prove ordinary
UBE reclamation or generated source-level cleanup. See its README for scope.

All paths below beginning with `ube ` are beneath `%TEMP%`. Run commands from
the repository root. No generated artifacts are stored in the root.

The unchanged numeric compiler is
`ube compiler rebuild bd4240e3-5cdd-434a-81d9-a09803a0aedf/generation-2/UBE.exe`.

```powershell
rtk proxy powershell -NoProfile -File compiler/tests/loop-control/check.ps1 -CompilerExe <numeric compiler> -AdmissionBaseline
```

Passed in `ube loop control 10f86c59-e792-4841-9af7-ede4370c9d07`:
Exit Loop, While, For, For Each and SyncLock parsing rejected with preserved
sentinel LLVM; invalid placements rejected; existing Do control runs returned
0 and deliberate result controls 99 at O0/O2. This establishes parser admission
gaps; the SyncLock probe is not a positive object-type semantics test.

Earlier Do/While UBE package:
`ube loop compiler aced0f78-fb3c-48b7-9dcb-707b34bb1d53/UBE.exe`.
Its source compiler was package `ube loop compiler
bcbcb31d-7da8-454e-9b3e-6f41aa207f9d/UBE.exe`.

Earlier Do/While bootstrap:
`ube source scanning 113e06af-a18e-4654-8505-4edbbaeeaf35/build/UBE-Bootstrap.exe`.

```powershell
rtk proxy powershell -NoProfile -File bootstrap/tools/build-compiler.ps1 -CompilerExe <source compiler> -Destination <fresh temporary package>
rtk proxy powershell -NoProfile -File compiler/tests/loop-control/check.ps1 -CompilerExe <current UBE package>
rtk proxy powershell -NoProfile -File compiler/tests/loop-control/check.ps1 -CompilerExe <current bootstrap>
```

UBE evidence: `ube loop control 91dacfb1-b462-447f-91b3-b1b598e876e3`.
Bootstrap evidence: `ube loop control 0d70a737-0d9e-4174-9667-3b4966b1dc68`.
Both pass seven negative fixtures with asserted source line/column and unchanged
LLVM, plus two executable fixtures at O0/O2. Positive execution returns zero;
changing the expected outer-loop count returns exactly one. Assertions cover
mixed Do/While, all Do condition forms, named exits across the other loop kind,
recursive calls, caller continuation, surrounding If continuation, a terminal
loop whose exit is procedure return, following sibling loops, skipped
postconditions, sticky Err, default While failure and enabled handlers.

```powershell
rtk proxy powershell -NoProfile -File bootstrap/tests/source-scanning/check.ps1
```

Passed all 90 groups with fresh VB6 6.00.9782 in the current bootstrap directory
above, including actual If/Do failure semantics O0/O2 and the exact changed-input
failure count 22. VB6 registry access failed inside the sandbox; the same gate
was authorized outside it and succeeded.

The earlier Do-only source checkpoint passed a rebuild fixed point in
`ube compiler rebuild 35f0afb5-a94d-4828-8b2e-6336ddf38225`:

```powershell
rtk proxy powershell -NoProfile -File bootstrap/tests/self-hosting/rebuild-check.ps1 -InitialCompilerExe <numeric compiler> -FirstGenerationDirectory <ube loop compiler 42d69a00-4a24-4681-9f3f-56d5ddab81d9>
```

It reused a separately witnessed first build; source/assets and LLVM matched
exactly and native images differed only in the PE timestamp. This predates
While changes and does not qualify the current final fixed point.

Full common conformance passed for the current UBE/bootstrap pair with
`bootstrap/tests/self-hosting/check.ps1 -CompilerExe <current UBE package>
-BootstrapExe <current bootstrap>`, evidence directory
`ube compiler conformance 0806faf8-1abc-42ba-82fc-35a68b2a916e`.
All 1004 assertions passed: O0/O2 execution, deterministic IR, source/output
identity guards, malformed input, missing/failing/empty/timed-out backend
preservation and recovery. This qualifies the shared corpus for this checkpoint;
it does not supply the remaining For/For Each or cleanup acceptance.
