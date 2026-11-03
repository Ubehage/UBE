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

## Current design decisions - 2026-11-03

The bounded contract preparation and review is complete. Final selections are
in `NATIVE-PATH-CONTRACT.md` (path domain and guarded acquisition),
`NATIVE-STACK-REVIEW.md` (cached committed floor, linked-code reserve derivation,
startup/fatal dispositions), `NATIVE-BUILD-DIAGNOSTICS.md` (delivery ownership
and deadlines), and `NATIVE-DEBUG-CONTRACT.md` (finite Full admission).
They supersede the earlier open-decision statements retained below. No
production backend or complete host qualification is claimed. Implementation
must pass the main contract's separate acceptance checklist.

Next action: implement the existing First checked native executable item under
these reviewed contracts, beginning with the shared error-support extraction
and counted byte-output dependency, then the checked-graph lowering/tool path.
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

Prepare the existing First checked native executable deliverable's bounded
contract review: included/deferred programs, lowering from the checked result,
target ABI/native values, runtime errors, LLVM validation and tool/cancellation/
publication failures preserving an old artifact. Author independent native and
failure expectations before implementation. Reuse qualified source owners,
generic library facilities, private results and the shared worker budget.
This does not reopen semantic rules or introduce a new compiler generation,
phase interface, executor, commit or push.
