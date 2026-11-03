# Native executable contract review record

This records the completed bounded contract preparation and agent review against
the active workplan, not evidence of native execution. The owner approved the
initial feature scope and the specific behavior decisions recorded below.
Engineering choices are selected in the linked contracts; their implementation
and qualification remain the next work. Earlier dated investigation statements
below retain their historical scope and are superseded by the current selection.

Independent review found that initializer-order negative controls in the
hand-written LLVM model prezero all module storage before any initializer. The
language specification previously established each declaration's neutral storage
before its own initializer without explicitly defining reads from another
module whose declaration had not initialized yet. The model's reversed-order
values are not UBE semantics. The owner subsequently settled the non-circular
early-read case as described below.
The new `additional/initializer-events` projects provide such controls for
declaration and module order within one package: their shared event state is
initialized first in all three manifests. They were admitted by both local stage
CLIs at jobs 1 and 4, but their native outcomes are still unexecuted. The
cross-package order is covered separately. The native
oracle now proposes a test-only event recorder to check library-before-root
initializer entry without assigning a value to an early read. Its hand-written
host comparator passed normal and reversed event controls; the generated-code
observer is still a future acceptance requirement.

In response to the early-read question, the owner said modules should have time
to initialize on creation and their standard Initialize events and procedures
must run. The existing language specification already requires any defined
`Module_Initialize` hook to run during module initialization. The current
bounded checker defers projects that declare such hooks; it does not accept a
hook and silently omit its execution. The owner subsequently confirmed that
an early access completes the referenced module's initialization before the
read. The language specification records that exception to the normal manifest
schedule. The owner initially chose an error for a cross-module initialization
cycle, then clarified that such references should remain allowed, with a warning
when detectable, and that a different module cannot read an unfinished module.
The owner confirmed mutually waiting initializers may keep waiting until stopped,
and the future IDE should show the warning. The
owner also mentioned a temporary call that destroys its target afterward; do
not infer a new object-lifetime rule from this bounded module example.
The owner cautioned that self- and cross-references in Initialize and Terminate
events are dangerous. The agreed cycle rule covers cross-module initialization
dependencies; it does not by itself establish a general prohibition on same-
module access or define additional termination-time restrictions.

The proposed Err adapter also needs normal startup before Main and a same-thread
checkpoint when an oracle asks for an intermediate Err. The contract now states
both requirements and asks for controls that skip an initializer or alter
checkpoint placement. These are future tests, not generated-adapter evidence.
For a shorter overview of decisions and remaining work, see
`NATIVE-REVIEW-SUMMARY.md`.
The plan requires review before implementation; it does not require this review
to invent a new phase API, runtime subsystem or language rule.

## Concrete review points

Final read-only review checked the selected path and diagnostic delivery
contracts against output ownership, tool/resource ownership and the source-change
policy. A separate review checked debug/stack decisions against the main and
runtime contracts. It prompted explicit object-to-image symbol retention,
inline-only distinctions, required declaration metadata and UBE1506 mappings
for candidate reads and unestablished stack bounds. Those corrections are
included. Neither review claims implementation acceptance; no remaining owner
choice or preimplementation design contradiction was identified.

Document/data checks: `rtk proxy git diff --check` returned 0, and
`rtk proxy rg -n "[ \t]+$" compiler/UBE_Compiler_v3 -g "NATIVE*.md"`
returned no whitespace matches. PowerShell `ConvertFrom-Json` validation of
`tests/native-executable/diagnostics.json` asserted 25 unique names, string
condition/stdout/stderr fields, statuses in 0/1/2/4 and no CR in LF payloads;
all assertions passed. This checks definitions, not a production renderer.

The following are proposed engineering choices, not settled language semantics:

1. Build the currently checked scalar/native MODULE subset, preserving explicit
   direct reference admission, with no silent omission of unsupported bodies.
2. Propose `--build-native <project.UBE> [-o <destination>] [--jobs N]`, with
   the owner-approved project `build` folder as default and an optional override.
   Keep the existing check path unchanged.
3. Show a brief success confirmation on an interactive terminal, while keeping
   redirected/scripted runs quiet unless there is a source or cleanup warning. Drain and bound tool streams, and show useful
   failure details as readable text when possible, with a safe fallback for unreadable
   bytes. This requires a qualified process boundary beyond the current
   inherited-stream synchronous bootstrap intrinsic.
4. Publish at a single atomic replacement point, retaining old bytes on every
   precommit failure. An unsafe protected-input/path alias race or an unquiesced
   descendant must prevent commit; an ordinary file substituted at the output
   may be overwritten on success. Postcommit reporting must not imply the old
   artifact was preserved.
5. Keep exact raw LLVM deterministic for identical declared input/tool/options
   and worker counts, with source metadata preserved. Validate the actual module
   with the selected LLVM verifier and run independently expected native results.

On 2026-11-02 the owner accepted a first executable target covering the bounded
numeric, Boolean, variable, procedure, If, While and supported native datatype
features, with strings, arrays, classes and forms deferred. This decision does
not by itself approve the CLI or any later implementation; the subsequent
owner decisions on tool output and publication are recorded below.
The owner also confirmed that a tool failure should produce a clear error with
useful readable details where possible and a safe fallback for unreadable output.
The owner also requested a small terminal success confirmation that does not
interrupt scripts. For review, emit it only when stdout is an interactive
terminal; redirected/scripted output remains quiet when no warning is needed.
This owner decision does not by itself approve the CLI or publication mechanism;
the draft separately selects a 4096-byte per-stream capture limit for the bounded
build, subject to implementation and qualification.
The owner approved a `build` folder alongside the project as the default output
location, with an option to select another location. The default executable is
named after the project; create the folder when needed. The exact CLI syntax
and the publication mechanism remain proposals.
The owner confirmed that a failed build leaves the previous executable
untouched, and that a successful build overwrites it without another prompt:
the build command supplies confirmation, or the IDE handles it beforehand.
The mechanism for atomic, identity-safe publication remains to be qualified.
The owner confirmed that build success and cleanup success are separate: after
the executable has been published, report a cleanup problem as a warning while
the build remains successful. Failures before publication preserve the old file.
The owner accepted debugging information in the first build provided debugging
can be trusted to reflect the optimized program. Debug information must describe
the actual optimized executable and must not change observable UBE behavior;
an optimized-away value is unavailable rather than fabricated. This decision
does not itself verify debugger operation or generated code.
The draft requires Full and None at the default optimization level so the
same-optimization behavior comparison can actually run.
The owner also confirmed that a signed integer minimum `Mod -1` returns zero
without an error; it preserves any existing Err. The language specification and scalar
operator audit record that choice, and the native oracle separately requires
clear and preseeded Err observations.
The owner confirmed that when a call can be safely refused for lack of stack
space, the callee is skipped, a function returns its neutral value, and the
current thread records Err 28. The language specification records that rule;
the unsafe-recovery path and actual guard remain to be qualified.
The public scalar-operator article now states this rule as specified behavior.
Native implementation has not yet been demonstrated; the offline-site checks
required by `docs/AGENTS.md` are recorded in the documentation roadmap.

The owner confirmed scalar module initialization in declaration order during
module initialization, with referenced libraries before the executable; the
normative specification now records it. A separate checker issue was found:
the earlier local checker accepted lifecycle hook declarations and direct calls
despite the bounded deferral and normative direct-call prohibition. A focused
deferral correction has passed the two-stage CLI and retained qualification on
cohort 25f; `LIFECYCLE-DEFERRAL-EVIDENCE.md` records the scope. Direct calls are
deferred at their declaration in this subset: those checks do not qualify
direct-call enforcement when lifecycle hooks eventually become supported.

The owner-defined plan requires review before backend implementation. The
existing semantic approval did not by itself approve these new choices. The
completed review now selects common path acquisition and complete stack admission
in `NATIVE-PATH-CONTRACT.md` and `NATIVE-STACK-REVIEW.md`.
`NATIVE-TOOL-CONTRACT.md` selects tool identity scope, encoding/limits, deadlines
and capture/cleanup ownership; their implementation still needs qualification.
The error-state/observer boundary is selected in `NATIVE-RUNTIME-CONTRACT.md`.
Implementation measurements against the selected lowering limits
and target ABI observations are later acceptance obligations. The first-target
integral error numbers follow the existing v2 and VB6-compatible defaults. The first-build option matrix
is selected in the draft, but its native implementation remains untested.
The new-command diagnostic interface is selected in `NATIVE-BUILD-DIAGNOSTICS.md`:
reserved codes, detail formats, stderr routing, formatter/redirected UTF-8/LF,
and console-only success confirmation. Existing frontend bytes and streams
pass through unchanged; the historical checker's CRLF/LF discrepancy is separate.
Request decisions on actual conflicts or changed behavior; use established UBE
definitions and VB6 defaults for routine behavior choices.

| Workplan requirement | Review finding and evidence | Outstanding before implementation or acceptance |
| --- | --- | --- |
| Small included/deferred program set | `NATIVE-EXECUTABLE-CONTRACT.md` proposes the already checked scalar/native MODULE subset and explicit direct reference; unsupported bodies are deferred. The first build must honor optimization 2 with both Full and None debug information. | Confirm lowering coverage for the approved subset; do not silently ship a smaller set. Verify generated Full information and the supported/deferred option matrix. |
| Lowering from the checked result | `NATIVE-LOWERING-REVIEW.md` maps actual result ownership, facts, values and known complete graph evidence. Focused independent comparisons passed with both 25f stage observers for two numeric conditions, nested named call ordering, nested exit and four single-line If graphs, with mutation controls. `NATIVE-RESOURCE-CONTRACT.md` selects serial traversal/storage, limits and cost obligations. | Prove that a lowering consumer uses those records correctly and satisfies the selected work, copying, allocation, depth, failure and cancellation bounds; focused graph observations do not execute generated code. |
| ABI/native values | The normative language specification fixes a one-component aggregate, ByVal aggregate parameters/results, exact-type ByRef aliasing and target size/alignment 1/1, 2/2 and 4/4. `native` and `native-widths` specify value observations; `ABI-ORACLES.md` specifies independent layout, boundary and negative-control probes. | Implement and run these probes against fresh-v3 output; source-level values alone do not prove the internal ABI. |
| Runtime errors | Contract requires neutral result and thread-local Err, no silent clearing, and no LLVM UB. `ERROR-ORACLES.md` specifies independent failure, success, stale-state, thread and negative controls alongside the value fixtures. | Qualify the actual same-thread observer and any normative error identity; execute failure and success cases, thread isolation and exceptional boundaries. Do not treat zero as proof of Err. |
| LLVM and determinism | Contract fixes the same-input/path/tool comparison cohort, jobs 1/2/4, raw modules/metadata and separate binary observations. It selects Clang O2 verification, timestamp suppression, DWARF 4, explicit support inputs and an allowlisted environment. Verifier evidence records valid/dominance controls, object/link comparisons, the support cohort and source-location checks. | Qualify actual process/IR identity and corruption controls, serialization and reviewed UBE error/stack support. Enforce the scoped identity rules in `NATIVE-TOOL-CONTRACT.md`; qualify the finite final debug check in NATIVE-DEBUG-CONTRACT.md. Measure UBE binary determinism separately. |
| Tool handoff and publication | Contract selects `--build-native <project.UBE> [-o <destination>] [--jobs N]`, the build folder and optional destination. `NATIVE-BUILD-DIAGNOSTICS.md` reserves UBE1500..UBE1514; `diagnostics.json` supplies 25 future output vectors. `NATIVE-TOOL-CONTRACT.md` selects identity scope, argument encoding/limits, suspended launch and Job assignment, deadlines and overlapped capture ownership. Cancellation/replacement has a linearization point. | Implement the selected common path acquisition; qualify the output-identity policy, selected tool boundary and host replacement primitive. Qualify new byte/console delivery and its bounded failure path. Existing synchronous `CompilerRunTool` and text output do not prove them; warning analysis/IDE transport remain implementation work. |
| Exact independent results and failures | Nineteen pinned projects and a separately checked promotion project have hand-computed results in `tests/native-executable/ORACLES.md`; `COVERAGE.md` inventories gaps and the failure matrix supplies event/result experiments. The historical admission run covered 38 pinned and two separate runs; additional fixture admission evidence is recorded below. | Review independent boundary, call, native representation, rejected/deferred and failure diagnostic coverage against the full included scope. Run the eventual production path through both source-built stages; admission is not execution. |
| Source spans and preserved artifacts | Contract retains syntax owners and spans and requires old destination bytes to survive every precommit failure. | Exercise spans through a lowering observer and ensure failures/cancellation do not leak or replace the old artifact. Debugger operation itself remains a later deliverable. |
| Existing architecture and concurrency | Contract retains UBECore/compiler responsibilities, immutable input owners, private outputs, canonical publication and one worker budget. | Apply retained frontend/semantic gates and establish lowering-specific resource and determinism observations; historical correctness or speedup measurements do not prove the new consumer. |

The admission command in `tests/native-executable/ORACLES.md` checks only current
local frontend success and empty streams. It does not run the emitted programs,
exercise child processes, or qualify the stage/tool cohort. No row above asserts
those future results. All fixtures, expectations and failure seams need review
against the complete approved scope before a native acceptance claim.

The roadmap asks for preparation and review, not execution of an unimplemented
backend. The included/deferred set and owner-visible output decisions have been
reviewed; the other rows document concrete proposed contracts and independent
oracles. The final selections close preparation: `NATIVE-PATH-CONTRACT.md`
defines path acquisition, `NATIVE-STACK-REVIEW.md` defines the stack strategy
and reserve derivation, `NATIVE-BUILD-DIAGNOSTICS.md` defines delivery, and
`NATIVE-DEBUG-CONTRACT.md` defines finite debug admission. Tool lifecycle/identity scope is selected in
`NATIVE-TOOL-CONTRACT.md`. Initial lowering limits and serial
storage/traversal are now selected in `NATIVE-RESOURCE-CONTRACT.md`; actual
measurements remain implementation acceptance obligations.

`NATIVE-RUNTIME-CONTRACT.md` selects one shared extracted error-support unit,
the existing private native TLS semantics, closed error-recording paths and
same-thread final/checkpoint observations. The explicit support-link audit
passed its tested Err behavior but failed minimality: section GC still retained
24 unrelated UBE symbols, including four library exports. This rejects the
whole-runtime link recipe, not the existing error semantics. Extraction and
native observer integration remain future qualification work. The stack review
selects the cached committed floor, reserve derivation and startup/fatal paths;
host invariants and linked-code bounds require implementation qualification.

`NATIVE-BUILD-DIAGNOSTICS.md` now selects bounded initialization-warning
analysis: initializer-reachable bodies, root-storage ByRef forwarding and one
warning per cyclic dependency component. Its 21-case graph model and three
adverse controls pass. This resolves the grouping/conservatism policy, not
production source extraction, native alias enforcement or the later IDE.
The structural candidate profile is likewise selected with host evidence in
`NATIVE-CANDIDATE-REVIEW.md`; production validation/publication tests remain
future acceptance obligations. Neither missing implementation is itself a
reason to keep the preparation goal open after its contract choices are settled.

The support-resolution policy is now selected in the main contract: explicit
CRT/archive inputs, no implicit config or default-library discovery, and an
allowlisted child environment. The explicit-input host test recompiles LLVM,
checks object/executable equality, requires exit 7, inventories the reproduced
link inputs and checks config/default-library adverse controls in Full/None.
The exact 13-file support cohort and commands are recorded in
`tests/native-executable/verifier/EVIDENCE.md`. These settle input resolution;
they do not bind process images through path races, select the minimal UBE
runtime support, or qualify the combined production process boundary.

For tool identity, a focused Windows host experiment opened a test executable
for read with only read sharing. A pre-existing writer prevented that guard;
with the guard acquired, moving that executable name was denied, the test tool
still started and produced its expected result, and the move succeeded after
release. The command below returned 0:

```powershell
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/verifier/check-tool-guard.ps1 -Executable bootstrap/out/comparison-reference/comparison-2-False.exe -OutputDirectory bootstrap/out/tool-guard
```

This is a test-owned ordinary file on one host. It does not establish safe path
component acquisition, writable-mapping behavior, actual process-image identity,
tool descendants, other filesystems or a production launch boundary. It is a
candidate observation for the tool-identity failure oracle, not a selection.
The related `verifier/check-tool-mapping.ps1` created a writable mapping of a
test-owned executable, closed its original file stream, and attempted the same
guard. On this host the mapping prevented guard acquisition; after the mapping
was disposed, guard acquisition succeeded. The following command returned 0:

```powershell
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/verifier/check-tool-mapping.ps1 -Executable bootstrap/out/comparison-reference/comparison-2-False.exe -OutputDirectory bootstrap/out/tool-guard
```

This tests one mapped-file and sharing combination; it does not establish the
behavior of all mappings, paths, filesystems or tool-launch implementations.
`verifier/check-tool-junction.ps1` then held that read-only-sharing guard on
one test tool, moved a junction in its path, and put a new junction to a
different test tool at the selected name. The first launch returned the original
tool's 36; after the swap, the same selected path launched the other tool and
returned 33 while the original file stayed unchanged. This command returned 0:

```powershell
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/verifier/check-tool-junction.ps1 -Original bootstrap/out/comparison-reference/comparison-2-False.exe -Replacement bootstrap/out/comparison-reference/comparison-2-True.exe -OutputDirectory bootstrap/out/tool-guard
```

Thus a guard on the file reached by an earlier path lookup does not alone bind
a later pathname-based launch to that file. The experiment covers one junction
swap on this host, not every path or launch mechanism.
The same script with `-JunctionGuard bootstrap/out/native-junction-guard.exe`
held a separate no-write/no-delete-sharing handle to the junction. The actor's
move was denied and the original tool launched while it was held; after release,
the junction move and substituted-tool control succeeded. Both guarded and
unguarded script modes returned 0. This demonstrates one guarded junction, not
race-free acquisition of a whole path, all reparse types or process-image identity.

The publication review has several materially different observations. The
source-lock experiments below are historical comparisons, not requirements
under the owner's later source-change clarification. Publication protects the
admitted input/output entry separation and writes only the held output parent
and leaf; it does not track source objects after user-directed relocation.
The initial core commit direction is now nontransactional extended handle
rename. The combined ordinary-path prototype passed 16 assertions of process
and file effects, including user source edits and replacement saves; its exact
scope is recorded in `tests/native-executable/REPLACEMENT-PROBE-EVIDENCE.md`.
Complete path-domain/acquisition policy and production qualification remain
open. The historical alternatives below explain the selection; they do not
require restarting that comparison:

| Candidate | Evidence | Why it is not selected |
| --- | --- | --- |
| `ReplaceFileW` without an additional recovery protocol | [Microsoft's documented failure outcomes](https://learn.microsoft.com/en-us/windows/win32/api/winbase/nf-winbase-replacefilew) include `ERROR_UNABLE_TO_MOVE_REPLACEMENT`, for which, without a backup name, the replaced pathname no longer exists. Another documented failure can leave it under a different name. | A failed call alone cannot establish the approved preservation of the previous output. A backup name or a follow-up rename is not by itself proof of atomic visibility, safe recovery or race protection; a complete scheme would need separate qualification. |
| Hold each protected input open without delete sharing | A controlled host test blocked moving the original input name, but both tested native rename modes still replaced a hardlink substituted at the output name; the original's identity, bytes, creation and last-write times, attributes, security descriptor and named stream survived. See the guarded-input experiment in `tests/native-executable/REPLACEMENT-PROBE-EVIDENCE.md`. | The owner permits replacing a separate late input hardlink if the original is untouched. This one test does not qualify path acquisition, other protected inputs or filesystems. |
| Directory or file opportunistic lock alone | [Microsoft documents](https://learn.microsoft.com/en-us/windows/win32/api/winioctl/ni-winioctl-fsctl_request_oplock) that a directory-content change can proceed without waiting for the directory oplock holder's acknowledgement. A local level-1 file-oplock experiment blocked the tested same-process replacements instead of allowing commit; see `tests/native-executable/REPLACEMENT-PROBE-EVIDENCE.md`. | A directory notification alone is not an atomic destination-identity guard, and the tested file-lock combination did not permit replacement. Other lock types or combined protocols remain unqualified. |
| Nontransactional extended handle rename | The local repeated-reader probe saw complete old/new files; a separately held candidate can be inspected and reopened. | A separate late input hardlink can be replaced under the clarified policy. The held parent/candidate alone does not protect the selected path or all protected inputs. |
| Pathname-based transaction | A transacted destination lock blocked a tested entry substitution after its handle closed. | A parent-junction swap redirected both destination and candidate; this particular scheme violates the draft's identity requirements. |
| Handle-based transaction plus a junction guard | Coordinated tests combined external header inspection, candidate identity matching, guarded junction/ancestor moves, and selected rollback and reader cases. | Guard acquisition is not qualified for a full path; validation is only a marker experiment; other failures and filesystems remain unqualified. TxF is discouraged by Microsoft and conflicts with a sustainable portability goal unless that concern is resolved. |

All rows refer to test-only host experiments in
`tests/native-executable/REPLACEMENT-PROBE-EVIDENCE.md`. In particular, an
individual successful experiment is not a production selection or a reason to
claim source protection, arbitrary-path safety or complete failure handling.
The protected-input experiment was extended after the owner's source-change
clarification: with a test handle that allows write sharing but denies delete
sharing, a controlled in-place edit succeeded, then both tested rename modes
replaced the separate output hardlink and left the edited original unchanged.
This does not guarantee an editor that saves by replacing the original pathname
can save while such a handle is held; it is not a selected source-locking
policy or a complete publication protocol.

The selected nontransactional direction must satisfy these obligations as one
combined operation, rather than adding separate observations together:

1. Resolve and guard the selected output parent and its path components,
   failing before commit if their identity cannot be kept stable. Retain the
   original input identities/entry names for the initial output admission;
   the owner permits replacing a separate hardlink at the output name.
2. Finish and drain every candidate writer, inspect a stable candidate object,
   and retain an identity-bound handle to that same object through commit.
3. Use a qualified same-filesystem, handle-anchored replacement operation as
   the commit point. An ordinary substituted output or separate hardlink may be
   replaced. The compiler must not select an input entry as its output or
   redirect publication through a newly resolved parent pathname. Before commit,
   cancellation and definitive failure preserve the existing output.
4. Release guards and report successful publication separately from any cleanup
   warning. Do not impose source-change detection or a build-long source lock.

The acquisition order and access masks must be specified and tested together;
the existing junction, protected-input, candidate-reopen and reader tests are
separate observations and do not prove this combined sequence. In particular,
holding an input without delete sharing can block a rename-based editor save.
The selected direction does not use that source guard. An integrated test must
allow in-place edits and replacement saves, and cover already-open handles, redirected
ancestors, late hardlinks, candidate swaps, reader visibility, cancellation
and failure at the actual commit. This is an evaluation plan, not a selected or
qualified publication mechanism.
The owner approved preserving the previous executable on build failure and
overwriting without a prompt on success, and delegated the concurrent-output
choice. The selected policy permits successful publication to replace another
ordinary file placed at the destination during the build. Protection of inputs,
candidate identity and precommit failure preservation still apply.

Three earlier tests must be read against this entry-ownership rule:

- `check-protected-original.ps1` selects the source entry itself as output;
  initial admission must reject that collision. Its locking experiment does
  not establish a requirement to hold a build-long source guard.
- `check-protected-identity-swap.ps1` moves the source to a different name and
  leaves a separate output hardlink. Its publishing branch preserves both the
  moved source and the replacement source name, so that publication is allowed
  by the clarified policy. The old identity-rejection branch is not a current
  acceptance requirement.
- `check-guard-acquisition-race.ps1` also preserves the original while replacing
  a separate output link. Its useful finding is that binding a parent only after
  path substitution can lose the earlier selected directory. It does not prove
  that a late separate input hardlink must be rejected.

As documented in the main contract, if the user instead relocates the only
source entry into the admitted output slot, successful replacement may remove
it. This is the engineering interpretation of delegated output ownership and
the source-change clarification, not an additional explicit owner answer.
The bounded option matrix now selects optimization 2 with Full or None debug
information; all other valid combinations are deferred with a diagnostic.

## Source intake and publication protection

`src/ProjectLoading.bas` calls
`TryReadSourceFileIdentity` for each source; `src/SourceFile.bas` reads the
identity and bytes through one token, then closes that token before publishing
the document. In the Windows bootstrap,
`bootstrap/runtime/windows/file_primitives.c` opens that reader with read,
write and delete sharing. Thus the returned identity and frozen in-memory bytes
do not by themselves prevent a source write, replacement or change after intake.
The owner clarified that UBE does not monitor, detect or prevent user changes to
source files during a build, and does not reject or retry a build because they
changed. Such a build may succeed with unintended behavior in its output; source
consistency is the user's responsibility. The compiler must not itself modify
sources. Publication must reject input/output collisions initially and remain
bound to the admitted output entry. The source-change guard previously explored
here is not a requirement or a selected design. This is a source-code review
finding, not a reproduced corruption of the qualified `--check` command.

The test-only `verifier/check-source-intake-sharing.ps1` models the Windows
reader's read/write/delete sharing with a separate read-only handle. On the
tested host, a pre-existing writer prevented the proposed read-sharing-only
guard; once the guard was open, a reader using the current sharing flags read
the expected bytes while a new writer and a move were denied. Both operations
were possible after guard release. This command returned 0:

```powershell
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/verifier/check-source-intake-sharing.ps1 -OutputDirectory bootstrap/out/source-intake-sharing
```

This tests sharing compatibility for one ordinary test-owned file. It does not
invoke the UBE reader, prove both opens identify the same object during a race,
cover mappings or qualify path acquisition, lifetime through commit, other
filesystems. These observations do not create a source-locking requirement.
The same harness now also opens the guard through a test-owned junction, moves
that junction and substitutes another before opening the reader. The guard
still reads the original bytes, while the reader using the same selected path
reads the replacement. The command above returned 0 after observing both.
This is a concrete counterexample to treating a separate guarded open and a
later pathname-based intake open as the same object. It does not invoke the
actual UBE reader or establish a complete guarded-path solution.
Native, ABI, debugger,
determinism and failure execution are later acceptance gates and cannot be
substituted with frontend admission or the host-only probes.

Additional projects cover Boolean eager truth tables, nested loop exit,
single-line If, a recoverable module initializer error and operand order through
a recoverable error, division signs, and call aliasing and side effects.
`tests/native-executable/additional/ADMISSION-EVIDENCE.md`
records their local and two-stage frontend admission and input identities. They are separate
from the pinned nineteen-project inventory and its earlier cohort audit; their
native values, Err observations and negative controls are still future gates.

The current-host probes in `tests/native-executable/JOB-CONTAINMENT-EVIDENCE.md`
now include process-tree termination, descendant-held pipes, bounded retained
prefixes and a separate full-duplex experiment. They remain test programs: failed
observation and termination, arbitrary parent Job policies, the actual compiler
boundary and the currently proposed closed-stdin policy are not qualified by
those successes.

`tests/native-executable/REPLACEMENT-PROBE-EVIDENCE.md` records the separate
publication experiments. A create-only rename rejected a racing destination;
several existing-destination guards either allowed a swap or blocked the intended
replacement. A read-only candidate handle plus `ReOpenFile` retained the opened
object across a pathname swap, but an external verifier opening that pathname
could still read a substitute. A stdin handoff was tested separately and would
need an explicit change to the closed-input draft. These observations are
current-host evidence, not a qualified existing-output commit, complete path
protection or production tool boundary. Preserve the owner's approved overwrite
and failed-build behavior while resolving those gaps.

Diagnostic review discrepancy: the local Windows checker emitted CRLF for the
three concrete source diagnostics, while `SEMANTIC-DIAGNOSTICS.md` specifies LF
separators. `tests/native-executable/check-rejections.ps1` compares the observed
host newline exactly. The later diagnostic-interface review fixes new native
messages as UTF-8/LF and preserves the existing frontend output unchanged.
It leaves the old checker's documentation discrepancy recorded rather than
silently rewriting that path.

Follow-up evidence: `SemanticDiagnostics.bas` prints a prepared string; the
bootstrap runtime's `ube_print_string` uses `fputs` and its newline helper uses
`fputc`. `bootstrap/tools/verification.ps1` normalizes CRLF to LF when capturing
child output, so historical normalized-output checks do not establish raw pipe
bytes. The focused `tests/native-executable/newline/check-stdio.ps1` probe passed:
the same LF string emitted `41-0D-0A-42-0D-0A` in default text mode and
`41-0A-42-0A` after `_O_BINARY`. This supports Windows CRT text translation as an
explanation, but does not independently prove the exact mode of the compiler's
stdout or decide whether the specification means logical or raw separators.

The direct `newline/check-checker-bytes.ps1` test subsequently captured the
checker process's stdout and stderr as byte streams, without newline decoding
or normalization. For the divide-by-zero fixture, both local stage CLIs at jobs
1 and 4 produced the complete expected CRLF byte sequence, exit 1 and empty
stderr; an LF-only expected-byte control was rejected. The compiler hashes were
`DA13D5B42CD03EBA032E8E7944C2FD39446F849C09C50745634B69C414D7343A`
and `0AEB32332C8D2A9E1EB6BEB8229A2E5BC2EAEFCCA540A1139073CC3336DED084`.
For each stage the command was:

```powershell
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/newline/check-checker-bytes.ps1 -Compiler bootstrap/out/semantic-cli/e5b3d482d7fd46539e190ea70d20ecef/<stage>/ube.exe
```

This directly establishes the tested redirected bytes, not the internal stream
mode or an interpretation of the existing LF wording. Preserve existing
`--check` behavior while the raw-versus-logical specification issue is reviewed;
do not treat normalized output as a byte-exact observation.
