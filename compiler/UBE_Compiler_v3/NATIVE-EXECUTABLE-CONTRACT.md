# First checked native executable: review draft

Status: **draft for review**, not implementation or acceptance evidence. This
proposes the existing development-plan deliverable; it does not change UBE 1.0,
approve an implementation architecture, or claim the current checker emits code.
The normative language, project and ABI documents override this draft. The
qualified input boundary is `PROJECT-INPUT-CONTRACT.md` and the checked facts,
including its deferred cases, are in `SEMANTIC-CONTRACT.md`.

## Included program and target boundary

Use the existing normal executable project and at most one explicitly referenced
UBECore source package, with native MODULE sources, canonical manifest order and
the semantic checker's supported scalar/native subset. The full compiler and
UBECore sources are not prerequisites or implied supported programs. All
declarations and bodies, including unused reference bodies, must be supported;
an unsupported valid feature is deferred with a controlled diagnostic, never
silently skipped or misclassified as invalid UBE. Preserve earlier project,
scanner, parser and checker failures and their original locations. The existing
check command keeps its current behavior and creates no executable.

The initial execution target is `x86_64-w64-windows-gnu`, using the project's
LLVM/Clang 23 and MinGW-w64 toolchain. A program has exactly one parameterless
module `Sub Main()` or `Function Main() As Long`. The process adapter returns
zero for the former and the signed 32-bit result for the latter. Tests must
observe the full Windows process result, rather than assume shell truncation.
No foreign exports, external declarations, other source kinds, startup forms,
managed types, arrays, strings, other primitive roles, or other semantics
deferred by the semantic contract are included. There is no implicit library.

## Checked semantics to native behavior

Consume the successfully checked graph and its resolved declaration identities,
types, conversions, argument associations, folded constants and original spans;
do not re-resolve identifiers by spelling or let LLVM/C semantics decide UBE
behavior. Publish no generated artifact for a failed or deferred check; retain
the required diagnostics. Keep immutable input
owners alive through every consumer, private worker results, canonical publication,
one shared worker budget and cancellation/drain; never publish partial work.
The initial serial lowering, storage, resource defaults and work/copy obligations
are selected in `NATIVE-RESOURCE-CONTRACT.md`. This reuses the checked graph and
existing UBECore facilities; it does not add a public IR or worker pool.

For the included checker subset, preserve neutral initialization, declaration
before initializer evaluation, checked arithmetic and conversion, signed
division truncating toward zero and dividend-signed remainder. Literal-only
integer arithmetic remains folded as required by the semantic contract. Evaluate
operands and call arguments once in source order; Boolean AndAlso/OrElse skip
their right operand where specified, while eager operators evaluate it. Preserve
named-argument association independently of evaluation order. ByRef aliases an
exact-type variable; a forced parenthesized temporary and an omitted optional
ByRef argument have independent temporary storage and discard writes. Functions
start with neutral result storage. Recursive calls and Exit behavior are included.
Calls must not turn input-dependent recursion depth into an uncontrolled stack
overflow. Specify a checked execution-depth or equivalent stack-safety boundary
and a controlled noninteractive failure path before implementation; test shallow
recursion, exact/beyond boundary and cleanup on the actual target. Do not invent
a language-wide depth limit from an implementation resource bound. The guard
must account for varying frame sizes and leave sufficient stack for its failure
and unwind path in every supported entry/thread configuration; a bare call-count
limit is insufficient without that justification. A host object-code probe
shows that a callee's stack probe can precede a guard in its body; account for
the frame before assuming that an in-body check is safe. See the recursion cases in
`tests/native-executable/ERROR-ORACLES.md` for independent observations.
The required space is the complete next-call footprint, not just a local frame
report. For the measured fixed-frame x86-64 calls, Clang's static report excludes
the eight-byte return address; the experimental guard metadata now includes it.
Caller stack adjustments, transient prologue/helper use and the recovery reserve
still require complete accounting, as specified in `NATIVE-STACK-REVIEW.md`.
When a qualified guard can safely refuse a call before the callee
starts, treat that refusal as a recoverable failure of the call: retain the
specified argument-evaluation order and effects, do not execute the callee,
return the result type's neutral value where applicable, and set the current
thread's Err to 28. The owner confirmed this recoverable behavior; it follows the familiar
[Visual Basic out-of-stack-space error](https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/out-of-stack-space-error-28);
and is recorded in the language specification. Success does not clear a prior Err. If
the runtime cannot safely perform that recovery, it must instead use the
separately documented controlled noninteractive failure path; this proposal
does not claim that handling an actual native stack-overflow exception is safe.
`NATIVE-STACK-REVIEW.md` proposes a best-effort stderr message and process
status 1 only for the unrecoverable case, not simply for absence of a handler.

The normal runtime initialization schedule follows dependency order, then each
package's manifest source order; it is not the root-first order used for checker
diagnostics. If an initializer reads or writes another module's variable or
calls one of its procedures before that module has begun initialization, complete
that module's initialization first and do not initialize it again when the
normal schedule reaches it. The owner clarified that circular references are
permitted and that the compiler warns about detectable circular initialization
or termination references without rejecting the program. A read from another
module cannot proceed before the referenced module finishes initialization;
mutually waiting initializers may remain waiting until the program is stopped.
Warnings must be available to the future IDE as well as the compiler command.
The warning code, text, location format and bounded conservative analysis are
selected in `NATIVE-BUILD-DIAGNOSTICS.md`. It follows initializer-reachable
helpers, accounts for exact ByRef forwarding and emits one warning per cyclic
dependency component. Source extraction, analysis implementation and native
initialization enforcement remain to be qualified.
Do not implement the previously proposed cycle rejection.
The admitted ordinary module storage and initializers must be established before
Main as required by the language, and successful initialization unwinds in
reverse order where applicable. Lifecycle hooks remain deferred. Independently
test observable cross-package/module initialization order and neutral storage;
do not silently choose an evaluation order for any unspecified case. The owner
confirmed on 2026-11-02 that ordinary scalar module variables initialize in
written declaration order as their module initializes, with referenced
libraries before the executable. A recoverable initializer expression failure
returns its neutral result and records Err under the ordinary rules; it does not
by itself abort startup. Distinguish it from a failure to complete module
initialization that invokes the specified initialization-failure/unwind path.
The previously qualified local checker accepted
lifecycle hook declarations and direct calls, contrary to the semantic
contract's deferral and the language's prohibition on direct calls. A focused
declaration deferral correction has passed its new two-stage CLI regression;
retained qualification has passed as recorded in `LIFECYCLE-DEFERRAL-EVIDENCE.md`.
Do not silently emit hooks as
ordinary procedures or skip their lifecycle behavior.

Run-time dependent arithmetic/conversion failures return the operation's neutral
result and record thread-local Err; success does not clear a prior Err. This
subset does not expose On Error or a public Err inspection API merely for testing.
Tests must observe error state through a separately specified test adapter at a
documented internal boundary, or through an already supported ordinary library
API; they must not invent source-language syntax. A candidate test adapter runs
the ordinary dependency and module startup sequence and the same generated
language Main on the same native thread, observes the actual runtime's
thread-local Err immediately after Main returns, and reports both Main's result
and Err to the harness. Its observation must precede any cleanup that
could alter Err; test it independently with known set/clear and thread-isolation
controls, and reject an adapter control that skips a required initializer.
Compare the generated startup and program bodies with the ordinary entry build to
ensure instrumentation does not replace an operation or change evaluation.
For cases that require an observation before Main returns, use a test-only
checkpoint immediately after the actual generated operation or call, on the
same thread, to read the same runtime Err before later operations. The
checkpoint must preserve the operation and its argument effects; compare the
instrumented and ordinary bodies and reject controls that change the observed
error or move the checkpoint past an operation that changes it. An end-of-Main
observation alone does not establish the intermediate state.
`NATIVE-RUNTIME-CONTRACT.md` now selects the private error-state boundary and
same-thread observer, including separate final-Main and typed-checkpoint records.
It selects one shared error-support unit extracted from the existing bootstrap
implementation, with an explicit replacement condition; it does not link the
whole runtime or introduce a permanent public ABI. Qualify that implementation
and observer together. Whole-object section GC alone failed the error-only
support inventory even though the host error-behavior tests passed. No signed
overflow, division by zero, invalid shift, uninitialized load or poison may become observable LLVM
undefined behavior. Resource exhaustion follows a controlled failure path.

For this first target, use Err 6 for checked integral arithmetic overflow and
out-of-range integral narrowing, and Err 11 for integral division or remainder
by zero. This follows the existing v2 checked arithmetic and narrowing contracts
and the project's VB6-compatible default; it does not finalize a language-wide
error ledger. Acceptance must compare the
actual same-thread number, not merely test for a nonzero Err. Successful
operations still preserve the previous number.
LLVM `srem` also has undefined behavior for signed minimum and -1, even though
the mathematical remainder is zero. Lowering must avoid executing `srem` for
that operand pair. For the minimum of each included signed integer type `Mod -1`,
return zero and preserve the existing Err, as the owner confirmed; do not equate
LLVM's restriction with a UBE overflow error.

Opaque native values have nominal identity and the adopted Byte, Integer or
Long representation. The adopted internal ABI is a one-component value
aggregate: ByVal arguments/results pass that aggregate, exact-type ByRef aliases
caller storage, and initial-target size/alignment are Byte 1/1, Integer 2/2 and
Long 4/4. Pack/Unpack are admitted only through
their resolved, validated declarations and exact roles, never by name; copies,
calls, returns and equality preserve the value and nominal type. Other internal
call and error-status details must respect that aggregate ABI, caller/callee
agreement and target process entry. Do not claim a
public foreign ABI from this private boundary. Verify every included call mode,
including cross-module and direct-reference calls, with independently observed
values and a target ABI probe. Link only the program support actually required;
the compiler may not rely on an installed UBE runtime.
Infallible Value.Pack and Value.Unpack preserve the incoming Err state.

## Tools, artifacts and failure

For this first target, select the invocation
`ube --build-native <project.UBE> [-o <destination>] [--jobs N]`. This is a reviewed
CLI choice, not an implemented command or a new public phase API. It follows the
existing project check's exact option order, default one worker and decimal
`N` in 1..4, including leading zeroes. Require one project; repeated options,
missing option values, signs, invalid worker counts, unknown
options and source-only input fail usage with exit 2 before loading inputs or
starting tools. The existing `--check` command and its output stay unchanged.
Successful publication returns 0, including when later cleanup needs a warning;
invalid/deferred programs
and precommit cancellation, resource, validation, tool or publication failures
return 1. Cleanup success is reported separately from build success. Concrete usage
text and new diagnostic codes are selected in `NATIVE-BUILD-DIAGNOSTICS.md`,
including streams and byte formatting; their implementation needs qualification.
Retain all prior frontend codes,
messages and locations.

By default, place the executable in a `build` directory alongside the project
file, named using the manifest's original `Name` spelling with an `.exe`
extension for the first Windows
target. Create that directory if needed; report creation failures normally.
If the derived name cannot be used as a file on the host, report a controlled
output-path error and allow the user to choose a valid explicit destination;
do not silently rename the project output.
An explicit `-o` selects a different destination and is resolved against the
invocation working directory. Check the selected destination so it
does not identify any source, project, reference manifest, selected tool or
runtime input, including host-supported aliases and links. If identity cannot
be established safely, fail before publication rather than risk replacing an
input. Keep the explicit destination spelling for user-facing diagnostics;
paths are individual arguments, never shell commands. An existing destination
is replaced without an additional prompt only after all checks and tool work
succeed; a build failure before publication leaves it untouched. Issuing the
build command provides the overwrite confirmation, or the IDE handles any
confirmation before invoking the build. An explicit
destination supplies its own filename and extension; no inferred library search
is promised.
The protected set includes the running compiler, all resolved source/manifests,
tools, runtime/support objects and any staged input. A successful build may
replace an ordinary file another program placed at the selected destination
during the build; the owner delegated this choice and the build command grants
overwrite permission. Bind output admission and publication to the same selected
parent-directory object and output leaf, so a later pathname lookup cannot
redirect compiler writes into another directory. If, after the initial
destination check, another program places a separate hard link to any build
input at the output name, a successful commit may replace that link provided
the input's original name, identity, bytes and other protected attributes remain
unchanged by the compiler. This does not authorize selecting an input's own
entry as output or following a redirected parent into it. Use a qualified
identity-protected or handle-anchored scheme: rechecking a pathname and then
separately replacing it is insufficient for that protection. Test cooperating
tools and test-controlled filesystem races; this proposal makes no claim against
arbitrary external handle injection.
Creating and removing a hard link necessarily changes the file's link count;
filesystem-managed change metadata may also change. The preservation promise
here covers input content, its original directory entry and the attributes
listed in the failure oracle, not a claim that hard-link operations leave every
filesystem metadata field unchanged.
The compiler reads source files and writes build outputs; it must not modify
source files. The owner clarified that source changes during a build are the
user's responsibility: the compiler does not monitor, prevent or detect them,
or fail merely because they occurred. No consistent on-disk source snapshot is
promised across a build. Intake can still report ordinary read, parse or checking
failures; a build can also succeed and produce a program with unintended behavior
from the bytes read. UBE does not diagnose that inconsistency as a source-change
error or retry the build to obtain unchanged sources. A source change need not
cause any compilation error at all; any resulting program inconsistency is
the user's responsibility, not something the compiler must discover.

The engineering interpretation of the owner's output-ownership and source-change
decisions is entry-based: reject input/output collisions at admission, then
publish only to the admitted output entry. Capture the actual intake identities
and entry names for that admission, using host filesystem name equivalence,
not UBE identifier folding. Establish the output parent binding before comparing
it with those inputs; a later lookup through a substituted path must not choose
a different publication directory. Input identity handles, if retained, allow
read/write/delete sharing and are not source-consistency guards.

There is no continuing promise to protect an old source object wherever another
program moves it. In particular, deliberately moving a source's only entry onto
the admitted output name can cause a successful build to replace that entry.
This is the stated engineering interpretation of the delegated overwrite rule,
not a claim that the owner separately answered this exact relocation example.
Do not turn such changes into a source-monitoring, locking or retry requirement.
With an unchanged input entry and a separate late output hardlink, publication
still leaves the original entry and contents untouched. Replacement removes the
output entry itself; it never follows that final link and writes its target's
contents. Path binding, candidate ownership and controlled precommit failures
remain required. A host unable to establish those guarantees fails before commit.

The same boundary must bind the candidate that was verified and linked to the
object actually committed, using an identity/content anchor through replacement
or an indivisible detect-and-commit operation. A separate swap check followed by
pathname replacement still races and is insufficient.

Select nontransactional extended handle rename as the initial Windows commit
direction: retain the inspected candidate handle, pass the admitted output
parent handle and final leaf name, and request replace/POSIX semantics using
`FileRenameInformationEx`. Do not fall back to remove-then-create, a newly
resolved absolute parent, `ReplaceFileW` or TxF. Microsoft's
[rename contract](https://learn.microsoft.com/en-us/windows-hardware/drivers/ddi/ntifs/ns-ntifs-_file_rename_information)
defines the relative parent and replacement flags; it is not a universal
filesystem or complete failure-handling proof.

The combined ordinary-path host prototype passes 16 cases, including source
edits and replacement saves, initial aliases, late output/hardlink replacement,
held candidate identity, cancellation and denied replacement. Exact commands,
hashes and limits are in `tests/native-executable/REPLACEMENT-PROBE-EVIDENCE.md`.
This selects the core commit direction. Complete path-name/reparse acquisition,
candidate creation, writer containment and production integration still require
their stated design/acceptance work. The prototype's reparse rejection is not
silently adopted as a permanent product restriction. A path/filesystem on which
the required binding and decisive replacement cannot be established fails
before commit; there is no unsafe fallback.

Record source and reference identities, compiler and external tool identities,
target, flags and relevant environment alongside acceptance evidence. Invoke
the selected tool by executable path with distinct bounded arguments, not a
shell command string; paths containing spaces and shell metacharacters are data.
When a compiler driver launches a linker, identify and account for that linker
separately: the driver's own identity does not determine which linker ran.
Qualify how the selected driver resolves its child and support inputs, and
include the actual linker in the protected tool set. A driver trace or an
earlier pathname hash alone does not prove which child image executed.
Capture tool start failure, nonzero exit, invalid IR and missing output as
controlled failures. Validate generated LLVM with the selected LLVM toolchain
before publishing the native output. Do not present a linker success alone as
proof that emitted semantics are correct. A build must not execute the user's
candidate to validate it: execution can have program-defined side effects and
may require input or an environment unavailable during a build. Acceptance tests
may execute their own controlled fixtures after the build and compare their
observable results against independent expectations.
Candidate checks must reject the wrong artifact kind, target and the specified
malformed-image cases in `tests/native-executable/FAILURE-ORACLES.md` using the
finite structural profile selected in `NATIVE-CANDIDATE-REVIEW.md`. Qualify its
implementation and the identity of the inspected file at the build boundary;
do not describe them as proof that an arbitrary image will load or implements
the source program. A structurally plausible image can still contain wrong code,
and successful execution of selected fixtures is evidence for those fixtures,
not proof of correctness for every program.

For this bounded build, retain at most the first 4096 raw bytes independently
from each tool output stream and drain all further bytes until EOF or a
controlled observation failure. Record truncation separately for each stream.
The limit is an implementation resource boundary, not a language limit. The
rendering and unavailable/partial-stream distinctions are specified for review
in `NATIVE-BUILD-DIAGNOSTICS.md`; the production capture boundary remains to be
implemented and qualified.
Do not infer a successful candidate validation from a truncated diagnostic
prefix. A validator that depends on a complete tool report must either receive
and check a complete report within its reviewed bound or fail safely; a separately
bounded streaming validator must account for the full stream and its own state.
The diagnostic prefix limit is not permission to ignore a later disqualifying
fact. See the late-marker control in
`tests/native-executable/REPLACEMENT-PROBE-EVIDENCE.md`.

Build a candidate at a unique sibling location on the destination filesystem;
only after successful verification, linking, close and required flush may an
atomic replacement make it the final executable. Prior to replacement, any
failure or cancellation leaves an existing final artifact byte-identical, or
leaves the destination absent if it was absent. Never delete the old artifact
as preparation. A precommit attempt must not replace its file identity or
modify its attributes, security descriptor, named streams, creation time or
last-write time; a read-induced last-access update is host-managed and is not
evidence of a compiler write. Concurrent external changes are attributed to the
actor rather than the compiler. Release handles, drain admitted work and remove owned temporary
files where cleanup can be confirmed; report cleanup failures without concealing
the primary failure. Cancellation during external tool execution must not
publish while a child can still write: terminate or wait for it and establish
it has exited before claiming complete cleanup. If confirmation fails, report
the unconfirmed state and do not publish. `CompilerRunTool` currently waits synchronously and does
not itself specify cancellation; a concrete qualified solution is a prerequisite,
not an assumed capability. A definitive no-commit replacement failure must preserve the old file;
prove the actual host primitive and its limits before relying on it.
Contain and account for the entire tool process tree, not just the direct child:
before validating or publishing, establish no descendant can still write the
candidate, and bound cancellation, pipe-drain and handle cleanup. A descendant
holding a pipe or candidate open must lead to a controlled failure if it cannot
be drained and stopped. Test exact Unicode argument round trips, including empty
arguments, quotes, trailing backslashes and shell metacharacters. The existing
ANSI process helper cannot by itself prove these guarantees.

For the initial Windows target, select the reviewed process-handoff direction:
`NATIVE-TOOL-CONTRACT.md` fixes argument encoding and limits, tool identity
scope, invocation/completion/cleanup deadlines and capture ownership. Use its
600000-ms invocation, 5000-ms completion grace and shared 5000-ms stop/drain
defaults; they are policy choices, not hard real-time OS guarantees. The
production mechanism remains to be implemented and qualified. In particular,
create the child suspended with `CreateProcessW`, an explicit inherited-handle
list and EOF-only stdin, place it in a non-breakaway Job before resuming, and
concurrently drain both pipes. On Windows, the reviewed EOF-only input uses an
inheritable read handle to `NUL` in the explicit handle list; it is not a null
or invalid `hStdInput`. Confirm the selected handle produces EOF and does not
read from the user's terminal. A failed input-handle setup is a prepublication
failure. On
cancellation or timeout, terminate only that contained job, then observe its
process count and pipe closure. If containment cannot be established, do not
resume the tool. If assignment or setup fails after process creation, terminate
and observe the still-suspended child before returning, or explicitly report
cleanup as unconfirmed. The selected process identity/path binding, deadlines,
handle cleanup and Job policy still need a qualified host implementation;
selecting these primitives does not make those guarantees automatic.
If termination, drain or observation cannot be confirmed,
return a controlled precommit failure, do not publish, and explicitly report
cleanup as unconfirmed; do not claim every descendant or handle was released.
The bounded wait, Job constraints and host/filesystem support must be qualified
using the independent failure experiments before production use.

For a tool that must inspect an already-open candidate, another review option is
to supply a read-only candidate handle as its standard input, rather than a pipe
or a separately resolved pathname. The host experiment in
`tests/native-executable/REPLACEMENT-PROBE-EVIDENCE.md` combines that handoff
with candidate reopening and extended rename. Selecting this option would amend
the closed-input proposal for that tool only. It must preserve the same object
and bytes from inspection through commit, exclude write access, contain and
observe all processes that inherit the handle, and close every such handle before
claiming cleanup. A tool exit or header listing alone is not a sufficient
candidate check. The experiment does not yet qualify these conditions or the
tool's report capture; it does not authorize production use.
The inherited handle can share its file position with the parent. A later reader
must explicitly establish its own starting position or use a qualified
independent handle; it must not assume inspection leaves the offset unchanged.

The atomic replacement is the publication linearization point. Before it,
observe cancellation and abort without replacing; once replacement has
succeeded, report the published build as successful even if a cancellation
request arrives later. A definitive no-commit replacement failure reports
failure and preserves the previous destination. An indeterminate host result
uses the distinct disposition below. When the commit outcome is decisive, a
cancellation racing replacement resolves to either old/cancelled or new/success;
it cannot report cancellation after publishing a new artifact. An unexpectedly
indeterminate host result uses the distinct exit 4 disposition even in a race.
Close all tool and candidate-writer handles before replacement;
a separately owned, qualified identity/commit handle may remain open through
the operation and must be released on every applicable path. Do not treat a
successful tool exit as proof its output exists or is usable.
An unremovable temporary is reported as a cleanup failure; it cannot justify
deleting or overwriting the destination. These requirements do not claim crash
durability across power loss or safety on filesystems that lack the required
replacement guarantee; unsupported host/filesystem behavior must fail safely.
Complete all fallible work required for success, including required cleanup,
before commit where possible. After a successful commit, never return the same
ordinary failure used for an unmodified destination: report successful
publication, and separately warn of any postcommit cleanup problem without
falsely claiming the old artifact remains. Return 0 after confirmed publication,
even if a warning cannot be delivered; postcommit cancellation alone likewise
remains exit 0. A host primitive whose commit
outcome can be indeterminate must not be used to claim the old-or-new contract
without a separately specified and reviewed indeterminate outcome. As a
defensive proposal, reserve exit 4 and the fixed message `error UBE1513: native
executable publication outcome is unknown` for an unexpected indeterminate
host result; neither old nor new bytes may be asserted. A filesystem/primitive
known in advance to lack the required decisive guarantee is rejected before
commit, rather than routinely using exit 4. This remains a review proposal.

If a proposed publication primitive can leave an owned candidate name linked to
the published object, assess that alias before selecting the primitive. In
particular, a failed postcommit removal must not leave an admitted tool or an
owned writer able to change the verified executable. The cleanup warning does
not itself establish that protection. This is an obligation on the compiler's
owned work and temporary names, not a promise to prevent a user from modifying
the final executable after publication.

The checked graph's current `SemanticResult` retains the catalog, ordered module
results and entry declaration. Each module retains its `Facts`, reduced `Values`,
root and source identity; the catalog owns declarations, types, shared facts and
source/syntax owners. Lowering may consume those records together with original
syntax, but it must not infer execution order solely from canonical declaration
order. A concrete coverage audit must identify every fact or syntax edge needed
for control flow, constants, calls and native types; missing or ambiguous retained
data is a prerequisite to fix and requalify, not permission to guess from text.

## Resource, lifetime and cost obligations

The existing admitted project/source and semantic limits remain authoritative;
they do not automatically bound generated bytes, target symbols, lowering work,
tool arguments or candidate disk use. Before implementation, define explicit
caller-controlled nonnegative maxima for those new resources, plus pending
traversal work and active structural depth. Check arithmetic used to derive
capacities, file offsets and argument counts; reaching a limit is a controlled
resource failure, not a language diagnostic. A valid input that exceeds an
implementation limit is not reclassified as invalid UBE. Use explicit bounded
traversal so input-controlled nesting cannot overflow the native call stack.
Distinguish a maximum candidate size accepted for validation from a hard bound
on disk consumed while an external linker writes. Checking the file only after
the tool exits, or periodically sampling it, cannot by itself establish the
latter. A selected hard storage bound must constrain the writer or its storage
and be qualified independently; otherwise describe the actual bound and the
remaining disk-consumption risk rather than calling the post-write check a quota.
For the baseline, reject an oversized candidate after all tool writers have
stopped and before publication; this is an accepted-length limit, not a hard
quota on temporary disk usage. `RESOURCE-ORACLES.md` reviews the distinct
Windows quota scopes and the additional conditions for any future hard-quota
claim. The selected accepted length is 256 MiB in `NATIVE-RESOURCE-CONTRACT.md`;
actual validation remains an implementation acceptance obligation.
For each active tool, budget up to 8192 retained raw bytes and, if both rendered
excerpts coexist with them, up to another 49152 bytes for the excerpts under the
current escaping rules. Account separately for labels, paths, pipe buffers,
reader scratch and process state; use checked arithmetic for multiple active
tools. An implementation that streams or reuses storage may charge its smaller
measured live peak, but may not omit a simultaneously live allocation.

The current project input defaults include up to 256 sources, 16 MiB per source,
64 MiB total source bytes, 1,048,576 syntax nodes and pending items, and depth
256. The semantic limit validation caps declarations, facts and pending work
at 1,048,576 and depth at 256. These are existing input/semantic bounds in
`ProjectLoading.bas` and `SemanticChecking.bas`, not estimates of emitted LLVM,
candidate binary size or lowering allocations. Do not treat frontend limits as
measured output bounds or evidence that every admitted project fits.

The resource review must also measure the overlap between the retained checked
graph and source owners, lowering results and scratch, and tool handoff state.
Their separate category limits are not evidence of a process-wide peak: report
the actual simultaneously live usage and state which overhead and external tool
memory the measurements include. If a process-wide limit is selected, enforce
it across that overlap rather than resetting its accounting at the lowering
boundary. Do not add individual category peaks and present their sum as a
measured simultaneous peak.

The compiler owns target/lowering policy and publication. General byte storage,
path and process operations belong to an already qualified UBECore facility or
its documented minimal host boundary. Frozen source owners remain immutable and
live until every lowering consumer and diagnostic finishes; each worker owns its
scratch and unpublished result. Reuse the shared jobs budget, drain earlier
work before reusing slots, and publish complete results in canonical order. No
worker receives a full source/project payload copy or starts a nested pool.
Do not release source owners while tool failure diagnostics still borrow spans.
Account simultaneous scratch and retained results under shared limits. As in the
existing semantic controller, a conservative parallel reservation must not
reject a build that fits the actual budget when run serially; delay admission
or use a bounded serial fallback where necessary.

`NATIVE-RESOURCE-CONTRACT.md` selects initial limits and algorithmic work/copy
bounds before coding. These are engineering caps, not measured peaks or a
promise that every admitted source fits. Qualify the implementation against
them with actual candidate measurements before release. At minimum count
actual syntax/fact visits, emitted bytes, allocations, growth copies/zeroing,
peak retained storage, roots, handles, worker admission/drain and tool/candidate
bytes. Require geometric rather than per-append full-output copying, zero worker
source-payload copies and no repeated whole-project scan per emitted node.
Exercise zero, below, exact and above each measured bound; inject allocation,
root, output and tool failures; observe cleanup and old-result preservation.
Compare real work and memory at jobs 1/2/4 with the serial reference and retain
existing frontend/semantic performance guards. No new parallel speedup is
claimed from earlier frontend measurements. Shared-budget contention, exact
boundaries and reservation cleanup have independent future checks in
`tests/native-executable/RESOURCE-ORACLES.md`.

For identical inputs, tool identities and options, compare generated raw LLVM
byte-for-byte across repeated runs and supported worker counts. Independently
run the produced executables and compare results. Record whether native binaries
are byte-identical; do not claim that property merely because LLVM matches.
Preserve source spans through lowering for future debugging; this deliverable
does not claim working source-level debugging.

The comparison cohort fixes exact source bytes, manifest/reference ordering,
selected project options, source paths, target triple/data layout, compiler and
tool identities, and the working-directory policy. Repeat with worker counts
1, 2 and 4 and fresh candidate names; timestamps, process IDs, worker completion
order and temporary paths must not enter raw LLVM. Preserve original source
identity and locations: the required equality does not authorize stripping debug
metadata or normalizing away differing instructions. Path relocation and binary
reproducibility are separate experiments, not implied by same-path equality.
For this comparison, source bytes mean the actual immutable documents retained
by each build after intake. The test harness supplies stable fixtures and
independently establishes that the builds read identical bytes. UBE does not
need to detect or prevent a user's concurrent source edits, and two builds that
read different bytes are not an identical-input comparison even if they used
the same pathname. This does not guarantee that a concurrently edited file was
read as a coherent version from one instant.
Current-host experiments observed changing COFF object and PE executable
timestamps with the default options. The object and link commands below select
timestamp suppression for this target. The corrected staged LLVM/object/link
test matched both Full and None pairs at two candidate paths, with an LLVM-only
value mutation proving that the linked program consumed the generated object.
Exact commands, the initially failed object comparison and the scope are in
`tests/native-executable/verifier/EVIDENCE.md`. These host results do not
establish binary reproducibility for UBE output.
Record and compare all generated modules in canonical source order, the target
identity and raw bytes, not just a combined success status. Reverse worker
completion in a controlled test and require the same bytes and diagnostics.

Project settings are not ignorable: `Optimization` supports 0, 1, 2, 3 and
Size (default 2); `DebugInformation` supports None, Line and Full (default Full).
They affect code/debug output without changing UBE behavior. The first build
must either implement each admitted setting or report a valid but unimplemented
setting as unsupported before output; it must never silently pretend to honor
one. It must implement the omitted-setting defaults (`Optimization = "2"` and
`DebugInformation = "Full"`), so an ordinary project with no explicit build
settings can produce the first executable while honoring the project contract.
For this bounded deliverable, the supported combinations are optimization 2
with Full or None information. Explicit and omitted values resolve to these
same combinations. Other valid combinations receive the unsupported-setting
diagnostic before tool launch and publication; invalid setting values retain
the existing project diagnostic. This is an implementation boundary, not a
change to the valid project-file settings or a permanent restriction.
For review, Full information for the included subset includes original source
file identity and line/column locations for executable statements, procedure
names and ranges where code remains, and declared parameter/local names and
types with their appropriate lexical scope. Inline instances must identify the
source procedure and call site; removed code must not acquire a fabricated
machine-code range. Optimized-away values may be unavailable at runtime; do not
fabricate their locations. Preserve original source identity through folding and
optimization, and associate generated locations with actual source constructs
rather than generated tool paths. Test the generated information
independently of executable behavior and without claiming an operational
debugger. Record the selected values in every acceptance result
and compare like with like. Support for nondefault settings and its diagnostic
require review.

The owner requires debugging to be trustworthy relative to the optimized
program. Debug information must describe the actual optimized executable and
must not change observable UBE behavior. For the same source, optimization
level and other settings, independently compare execution with Full information
and with debug information disabled;
also check that debug locations and any displayed value locations correspond to
the code actually executed. A value optimized away is unavailable, never a
fabricated or stale value. This does not assert identical machine code or
instruction timing, and an operational debugger remains a later deliverable.
For a Full build, tool success alone is insufficient: a host probe compiled
IR with an invalid debug version successfully while warning that it discarded
the debug information. Require the finite admission profile in
`NATIVE-DEBUG-CONTRACT.md` to detect discarded or missing required program debug
records before publication, including when the relevant tool diagnostic occurs
beyond a retained output prefix. Independently
inspect the actual final debug information against the requirements above; a
warning search or the mere presence of a section is not sufficient.
The first build must therefore also support the documented
`DebugInformation = "None"` setting at optimization level 2, so this
comparison cannot be skipped as an unsupported-option case.

For the first Windows target, select an out-of-process Clang verification and
object-compilation invocation with separate arguments
`--no-default-config --target=x86_64-w64-windows-gnu -O2 -mno-incremental-linker-compatible -Xclang -llvm-verify-each -c -x ir <input> -o <object>`.
This follows the maintained bootstrap toolchain
and avoids adding a production LLVM DLL dependency. The same invocation must
verify and compile the same stable IR bytes; separately linking its object does
not replace validation. A nonzero Clang status is a tool failure unless a
separately qualified boundary establishes a more specific cause; output-path
failures can mask invalid IR. Full debug information needs the separate final
artifact check above, because verifier success does not establish it.

For Full, select DWARF 4 source debug metadata in the emitted LLVM, including
the required source and value locations; for None, omit program source debug
locations. The same object command consumes either module. A `-g` flag cannot
reconstruct missing source metadata, and a late `-g0` flag is not a substitute
for emitting the correct None module. Existing support objects may contain
their own debug information; do not mistake it for the program's source records.
The host debug probes use Clang-generated metadata only. They do not approve
the UBE metadata emitter or prove debugger behavior.

Select the Clang driver and the explicit LLVM MinGW linker path for the link
command, with each item a distinct argument:

```text
<clang> --no-default-config --target=x86_64-w64-windows-gnu -nostdlib --ld-path=<absolute-ld.lld-path> <crt2.o> <crtbegin.o> <ordered-program-objects> <required-UBE-support-objects> <ordered-explicit-archives> <crtend.o> -Wl,--no-insert-timestamp -Wl,--subsystem,console -Wl,--threads=1 -Wl,--Xlink=/nodefaultlib -o <candidate>
```

Object sequences are frozen in canonical order before invocation; worker
completion cannot reorder them. This command links compiled objects, never
recompiles a source file. Use the normal console startup for the existing
parameterless Main adapter. No LTO, stripping or incremental link is selected.
`-mno-incremental-linker-compatible` avoids object timestamps needed by an
incremental linker, and `--no-insert-timestamp` requests a zero PE timestamp.
The [Clang argument reference](https://clang.llvm.org/docs/ClangCommandLineReference.html)
documents the driver options; the [LLD release notes](https://releases.llvm.org/9.0.0/tools/lld/docs/ReleaseNotes.html)
document MinGW timestamp suppression. The actual installed Clang/LLD 23.1.3
commands were exercised by the host tests in
`tests/native-executable/verifier/EVIDENCE.md`.

### Selected support resolution and child environment

The qualified compiler installation supplies the explicit Clang/LLD paths and
the startup/archive cohort. This is toolchain configuration, not another source
project reference or a new user project syntax. Resolve and record each complete
input path before tool launch; never substitute an ambient PATH search or a bare
`-l` name when a required cohort input is missing. Keep the established target
and source/library boundary. The command uses ordinary console CRT startup;
`-nostdlib` suppresses implicit additions and does not remove the explicit CRT.

For the currently reviewed WinLibs cohort, use `crt2.o` from its target library
directory and `crtbegin.o`/`crtend.o` from its GCC library directory. Preserve
this explicit archive sequence, including repetitions, with every name expanded
to its recorded absolute `.a` path:

```text
libmingw32 libgcc libgcc_eh libmoldname libmingwex libmsvcrt
libadvapi32 libshell32 libuser32 libkernel32
libmingw32 libgcc libgcc_eh libmoldname libmingwex libmsvcrt libkernel32
```

`libgcc.a` and `libgcc_eh.a` come from the selected GCC directory; the other
archives come from the selected MinGW target library directory. Record actual
bytes/hashes, not just version strings. Qualify native COFF startup/support
objects and ordinary archives with embedded members; thin archives, linker
scripts, bitcode/LTO payloads and unenumerated external member paths are outside
this cohort. Generated objects must not introduce unreviewed linker directives.
Any directives in the qualified support members need explicit inspection and
acceptance with that cohort; a pathname alone does not approve them.
For the recorded 13-file cohort, the independent archive/section inventory
checked all 7,310 AMD64 COFF records and found only four `-aligncomm` directives:
`__dso_handle,3`, `__mingw_optreset,2`, `optarg,3` and `__stack_chk_guard,3`.
Accept those common-symbol alignment directives for these pinned members.
The evidence names the containing members and records the raw/tool comparison.
No entry, stack, subsystem, include, default-library or file-loading directive
was present. A different cohort must establish its own inventory before use.

Disable implicit Clang configuration on both invocations.
[Clang documents `--no-default-config`](https://clang.llvm.org/docs/UsersManual.html#configuration-files).
Driver-generated search directories can still appear with `-nostdlib`; explicit
paths alone also do not disable COFF default-library directives. The selected
`--Xlink=/nodefaultlib` pass-through suppresses that library-discovery route.
It does not suppress all other object directives. This follows the installed
revision's [MinGW option forwarding](https://raw.githubusercontent.com/llvm/llvm-project/0d261d1ca552c95a8f007e061c787ac7132fbcbc/lld/MinGW/Driver.cpp)
and [COFF default-library handling](https://raw.githubusercontent.com/llvm/llvm-project/0d261d1ca552c95a8f007e061c787ac7132fbcbc/lld/COFF/Driver.cpp),
with omitted-flag controls in the evidence below.

Construct the tool child environment from an allowlist, leaving the user's
environment untouched: SystemRoot and WINDIR identify the actual Windows
installation; TEMP and TMP identify the owned build working directory; PATH
contains only the selected Clang and LLD directories and Windows System32.
Set the tool working directory explicitly to that owned directory and pass
absolute input/output paths. Do not inherit compiler/linker override variables,
library/include search variables, profiling outputs or environment-requested
reproduction archives. Adding a required variable or DLL directory to this
profile requires recording it and rerunning the tool cohort controls. A
controlled error reports an unavailable prerequisite; there is no automatic
download or fallback installation search.

Select LLD's `--threads=1` work setting and schedule external invocations under
the existing build controller. This is not a one-OS-thread or total-memory
guarantee: the reviewed Windows COFF driver also performs asynchronous file
reads independently of that setting. Account for the contained external process
tree separately from compiler-worker storage; resource and containment limits
still need their own qualification.

`tests/native-executable/verifier/EVIDENCE.md` records the concrete 13-file
startup/archive cohort and the exact commands. With the selected environment,
Full and None tests recompiled LLVM and linked the explicit sequence. Both
matched their earlier object/executable hashes and returned 7. LLD reproduction
archives contained exactly those 13 inputs and the generated object. Config
and default-library controls passed with the protections and failed without
them. The fixture imports Windows kernel and UCRT API sets; archive names do
not establish which DLLs the resulting executable imports. Reproduction/tar
inspection is test-only and is not a production dependency.

This selects support resolution, not a fully qualified compiler installation
or implemented error/stack support. `NATIVE-TOOL-CONTRACT.md` selects the
executable/dependency identity scope while treating Windows loader/system
components as host prerequisites; it does not require freezing all OS DLLs.
The error support boundary and extraction dependency are selected in
`NATIVE-RUNTIME-CONTRACT.md`; its actual objects and the stack support still
require implementation and recorded identities before use. No installed UBE
runtime is introduced. The root dependency document's referenced
`project-docs/toolchain.md` and `toolchain.lock.json` are absent in this working
tree, so these tests do not claim coverage by an existing lock or a portable
release bundle. Generated IR/candidate identity, admitted executable/path
binding and combined process/failure qualification remain implementation
obligations. The selected support-member
inventory is inspection evidence, not proof of every linked runtime path.

Clang 23.1.3 accepted the valid test module and rejected a parseable dominance
violation at O2, with and without `-g`; the test modules contain no UBE debug
metadata. Exact commands and identities are in
`tests/native-executable/verifier/EVIDENCE.md`. This selects a review direction,
not a claim that the production process boundary or every structural error is
qualified. Before use, establish safe executable and IR identity, complete
bounded process handling, cancellation, and object ownership; run the valid
and corrupted controls through the actual build boundary. Record exact
arguments, version/hash, exit and diagnostics. The same evidence describes a
test-only LLVM C API probe; it is not a selected production dependency.

## Independent acceptance obligations

`tests/native-executable/ORACLES.md` defines hand-computed observations and
`tests/native-executable/FAILURE-ORACLES.md` specifies failure experiments before
production implementation. The eventual gate must
run fresh-v3 output, not a bootstrap compiler's output, under both qualified
source-built compiler stages. It must record exact source/tool/artifact hashes,
commands, exit status, diagnostics, LLVM validation and observations. Exercise
one and multiple workers and retained semantic/project/frontend/resource gates.
Fault-injection controls must show each failure was actually reached; a passing
test with an untriggered fault is a failure. Resource and cancellation tests
must observe children/workers drained and owned temporary artifacts/handles
released when the host confirms cleanup. For deliberately denied termination,
observation or cleanup, require explicit unconfirmed/failed cleanup and no
precommit publication; the test harness accounts for and removes its own
survivors where possible. Never claim cleanup completed when it did not. Keep
failure fixtures independent of emitter internals.

## Reviewed decisions before implementation

The program/ABI/error semantics, CLI/diagnostics, warning policy, support-input
resolution, candidate structural profile and initial lowering resource policy
are selected above and in their linked contracts. `NATIVE-PATH-CONTRACT.md`
selects the initial Windows path domain and guarded acquisition sequence;
`NATIVE-STACK-REVIEW.md` selects the cached committed floor, linked-code reserve
derivation and startup/fatal dispositions; `NATIVE-BUILD-DIAGNOSTICS.md` selects
bounded delivery ownership/deadlines; `NATIVE-DEBUG-CONTRACT.md` selects the
finite Full-information admission profile. These close the preparation's
engineering choices. Missing execution of the future backend is not itself a
design gap. Host restrictions and implementation gates remain explicit, and
an implementation that cannot satisfy them must not be qualified by weakening
the contract or silently excluding an admitted source construct.
The error-support/observer boundary is selected in `NATIVE-RUNTIME-CONTRACT.md`;
extraction, bounded setters and generated-program tests are implementation gates.
The tool identity scope, argument limits and lifecycle deadlines are selected
in `NATIVE-TOOL-CONTRACT.md`, using the selected common path policy.

## Acceptance obligations after implementation

The following remain required before the native builder is qualified. They
must not be reported as passing based on host probes or design selection, and
must not require a working backend before its design review can finish.

1. Implement and qualify the reviewed Windows process-launch, cancellation and
   atomic-replace mechanisms; the existing synchronous
   intrinsic and text-write contract alone do not prove a cancellable native
   executable publication.
2. Implement and qualify the reviewed test-only observer for actual thread-local
   Err and evaluation order without adding syntax or replacing generated operations.
3. Qualify the selected command grammar and `NATIVE-BUILD-DIAGNOSTICS.md`
   interface, including raw-byte output vectors, streams, partial/failed writes
   and bounded console confirmation. Keep existing frontend bytes unchanged.
   Codes and details are selected; the new renderer and process boundary are not
   implemented. The warning policy is selected; its implementation and future
   IDE transport remain open.
4. Demonstrate every construct in the reviewed included subset against the
   checker's retained facts and actual target support. Do not silently qualify
   a smaller implementation as completion of this contract.
5. Run the independent fixtures and controls, including signed process exits,
   concurrency, filesystem and target ABI probes. Any discovered conflict with
   the normative specification needs resolution, not a changed test expectation
   that follows the implementation.
6. Measure and enforce selected lowering/output resource limits across
   simultaneously live owners. Qualify the reviewed stack strategy on varying
   frame sizes, included entry paths and failure paths; existing frontend
   bounds do not establish either implementation result.
7. Implement and qualify the finite candidate-image profile selected in
   `NATIVE-CANDIDATE-REVIEW.md` and the boundary that binds its inspected bytes
   to the object committed. The host layout and Full/None mutation suites
   support the profile choice; they do not qualify production publication or
   prove arbitrary machine-code behavior.
8. Qualify the selected Clang LLVM-validation boundary against the actual bytes
   compiled. Distinguish tool-start and observation failures from a completed
   tool invocation. A nonzero Clang exit is a tool failure unless a separately
   qualified mechanism establishes invalid IR; do not infer that cause from
   the exit alone. The current probes are not production qualification.
