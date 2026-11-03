# Native build command diagnostics: reviewed interface

This defines the selected new-command interface for
`NATIVE-EXECUTABLE-CONTRACT.md`; the CLI and output boundary are unimplemented.
Reserve UBE1500 through UBE1514 for the active compiler's conditions below.
Existing frontend and `--check` diagnostics remain unchanged. Runtime/process
tests remain implementation acceptance gates.

The fresh-v3 source and project/semantic diagnostic inventories contain no
competing literal or numeric assignments in 1500..1514. A repository search
outside the native review/test package found no UBE15xx assignments or separate
reservation ledger. Historical compiler generations and generated experiment
outputs are not authorities for allocating fresh-v3 codes. This document is the
reservation for the native-build interface; future additions must check it.

## Selected byte and stream interface

The new-message formatter and redirected byte streams use UTF-8 without BOM,
with one LF byte after each line, including the last. Do not rely on text-mode
newline translation. Usage,
new errors, warnings and failure excerpts go to stderr. The optional success
confirmation is the only new stdout message. Existing frontend diagnostics
pass through with their established bytes and streams; in the current Windows
cohort that includes stdout/CRLF. The discrepancy between that implementation
and its older LF specification remains recorded in `NATIVE-CONTRACT-REVIEW.md`;
this new-command decision neither fixes nor silently changes `--check`.
For a confirmed console output handle, render the same characters through a
Unicode console write, such as `WriteConsoleW`, rather than treating UTF-8 as
the console's current legacy code page. Do not change the user's console code
page or modes. [Microsoft documents the console/redirected distinction](https://learn.microsoft.com/en-us/windows/console/writeconsole).
Byte-exact vectors apply to formatter output and redirected streams; actual
console character rendering and partial writes require separate host tests.

For the first Windows host, test stdout with
[`GetConsoleMode`](https://learn.microsoft.com/en-us/windows/console/getconsolemode) on its actual
standard-output handle. Success means the confirmation may be attempted;
failure, an absent handle or a redirected handle means no confirmation. Do not
use stdin state, the environment or `_isatty` alone to make this decision, and
do not open a console. After confirmed publication, the exact success line is
`built "<destination>"` plus LF. The quoted destination uses the path-display
rules below and the spelling selected for user-facing output diagnostics.
Prepare it before commit when possible; inability to prepare or write this
optional message does not change a successful build or produce an error.
Its write must have a bounded failure path; no prompt or input is allowed.
The terminal host probes below cover console/file/pipe classification only,
not production output delivery. The delivery policy below selects deadlines;
it does not claim those probes qualified them.

Each path detail is one line containing the quoted path, without a label,
using `PROJECT-DIAGNOSTICS.md`'s escaping: quote/backslash become `\"`/`\\`,
ASCII controls and DEL become uppercase `\xHH`, and other UTF-8 bytes retain
their spelling. Setting details are three lines after the primary line:
project path, exact key (`Optimization` or `DebugInformation`), then canonical
effective value (`0`, `1`, `2`, `3`, `Size`, `None`, `Line` or `Full`, as
appropriate). Resource and observation categories are one fixed ASCII token,
never arbitrary tool text. Resource tokens are `lowering-storage`,
`generated-bytes`, `target-symbols`, `pending-work`, `lowering-work`, `structural-depth`,
`tool-arguments`, `candidate-bytes`, `debug-information` and `diagnostic-storage`. Observation tokens
are `wait`, `capture`, `drain`, `containment`, `exit-status` and `timeout`.
Tool-status details are the quoted tool path, then its nonnegative decimal
status, without signs or leading zeroes (except `0` itself). A boundary unable
to represent the actual status uses UBE1511/`exit-status`, not a made-up child
status. Detail order in the table below is significant.

Successful capture labels are exactly `tool stdout (truncated=0): ` and
`tool stderr (truncated=0): `, replacing 0 with 1 only after excess bytes were
observed. A failed capture after some reading uses
`tool stdout (partial): ` or `tool stderr (partial): ` and its retained excerpt.
Capture never established uses `tool stdout (unavailable)` or
`tool stderr (unavailable)` with no colon or excerpt. Emit stdout's line first,
then stderr's, only as details of a tool failure. Empty completed streams retain
the colon and space with an empty excerpt. Use the strict UTF-8 rendering and
Unicode 18.0.0 escaping rules below; select their stated 4096-byte raw prefix
and sixfold maximum rendered expansion. A production renderer still needs its
independent Unicode, allocation and capture qualification.
Emit both capture-state lines for UBE1504, UBE1505 and UBE1511. UBE1503 is a
separately established validation result; it does not replay a successful
verifier's output. UBE1506 likewise does not replay chatter from a tool that
returned success. The exact vectors in `tests/native-executable/diagnostics.json`
are future acceptance data, not observations of an implemented build command.

The build interface retains the primary structured failure even if formatting
fails. UBE1509 is the allocation-free presentation fallback before any bytes of
that diagnostic have been sent. Once writing has started, a short/failed write
must not append a fallback to that partial record. Precommit failure remains
exit 1, usage failure remains exit 2, confirmed publication remains exit 0,
and an indeterminate publication remains exit 4, whether or not their messages
can be delivered. Precommit cleanup failures use UBE1510 after the primary
record when delivery is possible; postcommit cleanup failures use UBE1512 on
stderr and retain exit 0. Required diagnostics must not be redirected to stdout
as a fallback when stderr fails.

## Selected delivery ownership and deadlines

For this first build command, collect new source warnings until the build's
publication/failure outcome and immediate cleanup observations are known. Prepare
one final ordered stderr batch containing the applicable complete records; keep
the primary failure before its secondary cleanup records and retain canonical
source-warning order. Prepare the optional stdout confirmation separately.
Existing frontend/checker diagnostics keep their existing delivery path. Do not
wait for an unresolved tool merely to obtain a nicer message: use its selected
partial/unconfirmed state. An unresolved invocation's later reaping does not
start another diagnostic batch for that completed build.

Reserve message storage before starting delivery. The initial maximum is
67108864 bytes (64 MiB) of owned formatted UTF-8 payload across the final stderr
batch and optional confirmation. This is an engineering cap, not measured
usage; descriptor storage and other live owners remain separately charged.
Tests/internal callers may lower the cap. A precommit cap/size failure uses
UBE1502/`diagnostic-storage`; inability to prepare that failure record uses the
existing fixed UBE1509 fallback. Never use the precommit error fallback to
describe a successful publication. Inability to prepare optional confirmation
simply omits it, without another diagnostic.
Prepare source-warning records before commit so their formatting failure follows
the existing precommit diagnostic-storage/fallback policy. Postcommit cleanup
records can use their existing fixed warning if a path cannot be prepared.
The fixed fallback text needs no payload allocation, but OS handle/thread setup
can still fail; allocation-free text is not a promise of successful delivery.

Use one transient, dedicated host I/O thread for the prepared delivery, owned
by the existing build controller. It performs no compilation, formatting,
filesystem publication or tool management and is not a second compiler worker
pool or executor. This accommodates inherited synchronous redirected handles
and `WriteConsoleW`; do not pretend an arbitrary inherited standard handle can
be converted into an overlapped pipe. The generic host write/thread boundary
belongs in UBECore or its minimal host support; message policy stays in UBE.

The delivery owner retains immutable prepared payload, rooted storage, a thread
handle, synchronized stop/completion state and noninheritable duplicates of the
actual output handles it uses. Never close the caller's handles or change their
console modes, code page, pipe mode or file position as a separate operation.
Do not flush or reopen a redirected sink by pathname. Invalid handles, denied
duplication, unsupported handle modes or failed thread setup make delivery
unavailable without changing the build result. Only duplicate/use stdout when
its existing console test succeeds and confirmation is applicable.

The writer sends the stderr batch first. It uses counted `WriteFile` bytes for
redirected output and `WriteConsoleW` characters for a confirmed console, with
at most 4096 bytes or UTF-16 code units per call. Use fixed owned conversion
scratch, strict conversion of the prepared UTF-8 and no split surrogate pair
between requested console chunks. Account scratch separately from payload.
A successful short write with positive progress may continue the exact suffix;
zero progress or a failed call ends that stream's attempt. Never restart a
record, append a fallback after partial delivery, or route failed stderr to
stdout. Record completed, partial, unavailable or completion-unconfirmed delivery
independently from the compiler's primary result. Confirmed bytes/characters
accepted by a write are not a claim of disk durability or that a user read them.

| Interval | Initial default | Boundary |
| --- | ---: | --- |
| Required stderr delivery | 1000 ms | One deadline from delivery-thread start for the whole stderr batch, including handle classification and all its writes |
| Optional console confirmation | 250 ms | One deadline when the writer starts the stdout attempt, only after stderr delivery has completed or failed without an outstanding call |
| Stop observation | 250 ms total | One deadline after first delivery expiry/stop request, shared by all cancellation attempts and completion observation |
| Controller wait slice | At most 50 ms | Capped by the remaining applicable deadline |

Use monotonic elapsed time and checked arithmetic. Internal tests may reduce
these nonnegative intervals; zero means no write attempt for that interval,
not an unlimited wait. Do not renew a deadline per record, chunk, short write
or cancellation retry. The writer and controller check expiry between calls;
the writer checks synchronized stop state before admitting another call. Expiry
wins when completion is first observed at the deadline. These are bounds on
controller waits and decisions, not hard real-time bounds on Windows calls,
thread scheduling or process shutdown. Do not claim that expiry can retract
bytes already written or prevent a pending call from completing later.

On expiry, set the stop state and request `CancelSynchronousIo` on this dedicated
thread; never use `TerminateThread`. Observe/retry cancellation within the same
stop deadline to cover a request racing a just-starting write. Microsoft states
that [cancellation does not wait for completion](https://learn.microsoft.com/en-us/windows/win32/api/ioapiset/nf-ioapiset-cancelsynchronousio)
and [driver cancellation support is not guaranteed](https://learn.microsoft.com/en-us/windows/win32/fileio/canceling-pending-i-o-operations).
Do not equate a cancellation return value or `ERROR_NOT_FOUND` with writer exit.
The thread is never reused for unrelated work, so cancellation cannot target a
later compilation/tool operation. An expiry suppresses any remaining records
and optional confirmation; a completed sink failure may still allow the separate
confirmation when publication succeeded and stdout was confirmed as a console.

If writer completion remains unconfirmed, retain that one delivery owner and
all referenced storage/handles under the controller until it can be reaped.
Do not free its buffers, close its in-use handle, queue more messages, start a
second delivery thread or wait indefinitely to join it. Later builds may keep
their structured results but cannot start new delivery while this owner remains
unresolved. This bounds uncertain delivery state to one owner per compiler
process; it does not silently accumulate a new retained batch on each build.
Use the same finite observation policy for reaping and release each resource
once completion is established. Tool-invocation retained ownership remains
separate under `NATIVE-TOOL-CONTRACT.md`.
When there are no new stderr records and stdout confirmation is inapplicable,
create no delivery thread and perform no standard-output write. In particular,
an ordinary warning-free redirected success does not allocate a delivery batch.

Delivery failure itself never changes the already determined usage/build/
publication exit status, retries compilation or rolls back a committed file.
No diagnostic about a broken diagnostic sink is recursively sent to that sink.
Preserve delivery status in the structured build result when the caller can
observe it; a standalone process cannot promise to explain a failed output
channel through that same channel. Source changes remain entirely the user's
responsibility and have no role in this delivery policy.

This completes the delivery design selection only. The counted writer, thread
ownership, cancellation races, console rendering and retained-owner behavior
remain implementation dependencies and acceptance gates; no production output
capability or new public threading interface is claimed.

The earlier repository-root check below returned no matches in files visible to
`rg` outside this draft, the other two native review documents and native test
artifacts. It covers the full proposed UBE1500–UBE1513 range as literal codes,
but ignored/generated files and nonliteral reservations are still outside the
check. The subsequent source/catalog review and reservation above supersede
that checkpoint's unallocated status.

```powershell
rtk proxy rg -n -i -g '!compiler/UBE_Compiler_v3/NATIVE-BUILD-DIAGNOSTICS.md' -g '!compiler/UBE_Compiler_v3/NATIVE-EXECUTABLE-CONTRACT.md' -g '!compiler/UBE_Compiler_v3/NATIVE-CONTRACT-REVIEW.md' -g '!compiler/UBE_Compiler_v3/tests/native-executable/**' 'UBE15(0[0-9]|1[0-3])\b'
```

## Selected command behavior

Usage failures return 2 and one logical line:

```text
usage: ube --build-native <project.UBE> [-o <destination>] [--jobs N] (N: 1..4)
```

Successful checked, linked and published output returns 0. A later cleanup
problem is reported separately as a warning, without changing build success.
The owner requested a brief confirmation when run from a terminal,
without interrupting automated scripts. The selected rule prints one short
success line only when stdout is an interactive terminal; on success without any
warning, redirected stdout and stderr remain empty. Cleanup warnings and the
owner-requested detectable circular-initialization warnings must also be
reported for redirected runs, and no input or acknowledgement is requested.
For the build command, source warnings are nonfatal and must retain
source locations and severity for IDE presentation. Static analysis and the
future IDE transport still require qualification. This does not change the
existing `--check` command's behavior.
The selected warning analysis below covers a direct initializer cycle and the separately
admitted case in which an initializer reaches another module through a
same-module helper; both are specified in the independent native oracle. A
non-circular early-access program is a control. More complex dynamic call
targets and any conservative warnings must be described accurately rather than
claiming all cycles are detected. The analysis must use bounded work and a
nonrecursive traversal for input-controlled graphs.
The no-cycle controls include an uncalled helper that refers back to the first
module: a reference in an unreachable procedure body alone does not make it
an initializer dependency. The analysis follows initializer-reachable calls and
labels its conservative uncertainty as possible.
The `initializer-cycle-branch` fixture also has A depend on B, B depend on A,
and B depend on C. A and B form a cycle; C does not. A warning must not claim
that C participates in that cycle merely because it is reachable from it.

Select source warning `UBE1514`. Its first line is the quoted source path,
followed by `warning UBE1514: possible circular module initialization (next lines: line, column, byte)`,
then line, column and byte as three decimal lines. Use the existing
source diagnostic's escaped source path, one-based line and scalar column,
and zero-based byte offset; retain the original full span and warning severity
for the IDE. For the direct and helper-mediated fixture cycles, anchor
at the `B.y` access in A's source (line 3 and line 5 respectively), rather than
at an unrelated project or generated file. Any related cycle edges retained
for the IDE must use their own source spans. Sort warnings deterministically in
canonical source order and source position; worker completion order must not
change the output. A warning describes a possible cycle, not proof that every
program path reaches it. Termination hooks remain deferred; their warning wording
and analysis are outside this first target.

### Selected initialization-warning analysis

Analyze the successfully checked executable nodes, resolved declarations and
argument associations. Constants, type mentions and provably skipped operands
absent from the reduced execution graph add no dependency. For retained `If`
branches, loops and calls, conservatively include every branch/body without
attempting a path-feasibility proof. Ordinary recursion is not itself a module
initialization cycle. This analysis changes no runtime initialization behavior.

For each module M, begin at its executable declaration initializers. Use an
explicit worklist to visit each reachable procedure body once for this root,
including same-module helpers. Do not start from unrelated or uncalled bodies.
A cross-module variable read, write or exact ByRef storage access from a body
owned by P to storage owned by N records dependency M -> N when P differs from
N. An ordinary or admitted intrinsic call across that same module boundary also
records M -> N at its call span. Follow ordinary call bodies; intrinsic calls
have no body to traverse. The target module's initializers are analyzed in its
own root pass, not recursively expanded here. Own-module accesses alone add no
edge. A reachable foreign helper that accesses unfinished M can therefore add
M -> M even when that foreign module's own initializer is inert.

ByRef forwarding needs a second, bounded analysis. For each root M, a formal
parameter has one Boolean fact: it may alias M's module storage. Seed that fact
only when an exact ByRef actual resolves directly to M's module variable. A
ByRef formal forwarded as an exact ByRef actual supplies an edge from source
formal to target formal. ByVal copying, assignments, local/result storage,
forced temporaries and omitted optional temporaries neither seed nor forward
the alias fact. Include applicable intrinsic parameters despite their lack of
a body. After collecting reachable calls, propagate true facts with a worklist;
enqueue a formal only when it changes from false to true, and examine its
outgoing forwarding edges once.

Every direct seed or true forwarding edge into a procedure owned by another
module adds the conservative dependency M -> M at that call's span. This warns
even if the callee does not dereference the alias. Consider every qualifying
incoming call when choosing the witness, including a later-discovered earlier
source span whose target formal was already true. A local/temporary call is not
a qualifying witness merely because another call seeded the same formal.
Unions across call sites and inclusion of both branches can overestimate a
cycle; UBE1514 deliberately says `possible`. No path-sensitive alias or dynamic
dispatch analysis is promised. Stored pointer/array/field aliases and ByRef
returns are outside the admitted subset. The warning does not implement the
runtime rule: cross-module access through a ByRef alias must still respect
module initialization, and its lowering/runtime enforcement needs independent
native tests.

Deduplicate root/target dependencies, retaining the earliest canonical
source/byte span for each pair. Find strongly connected components with an
explicit-stack, two-pass traversal; no input-controlled native recursion.
Emit exactly one UBE1514 per component containing more than one module or a
self-edge. Anchor it at the earliest canonical source/byte span of an edge
whose two endpoints belong to that component. Sort warnings by that position,
breaking ties by the component's smallest canonical module identity. A module
only reachable from a cycle is not a member. Optional related locations may
identify dependency spans within the component; do not label downstream modules
as cycle participants. Thus the existing direct/helper fixtures retain their
specified A-source `B.y` anchors, and the branch fixture excludes C.

Let M be admitted module count, V executable nodes across all bodies, C call
occurrences, P ByRef formals and F exact ByRef argument mappings. Reuse scratch
between roots. Body discovery and alias propagation require work bounded by
O(M * (V + C + P + F)); the dependency matrix holds at most M squared pairs.
Two iterative component passes use O(M squared) work with O(M) traversal
stacks. After assigning component IDs, select witnesses in one matrix pass,
not a complete matrix scan per component. Root scratch and retained graph
storage are bounded by O(V + C + P + F + M squared). Use checked arithmetic and
charge all live storage to the shared native-build budget; these count bounds
do not supply the still-pending numeric byte budget. Exhaustion produces the
ordinary resource diagnostic before publication, never silently omitted
warnings or an error claiming the source's cycle is illegal.

The test-only `additional/check-initializer-warning-model.ps1` under
`tests/native-executable` uses hand-authored graph inputs, expected dependencies,
groups and anchors. Its small grouping oracle uses transitive closure, distinct
from the proposed production component traversal. Run:

```powershell
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/additional/check-initializer-warning-model.ps1
```

The command returned 0 for 21 cases and three omitted/overinclusive-analysis
controls. Cases cover direct/helper cycles, uncalled helpers, a non-cycle branch,
own-module access, foreign-helper reentry, recursive helpers, disjoint cycles,
direct/forwarded/recursive ByRef aliases, local/temporary/ByVal controls and
canonical qualifying witnesses, distinct argument/call spans and tied warning
anchors. A final independent review identified the latter two model gaps; the
added cases pass, including reversed warning collection before sorting.
An initial model run exposed its PowerShell
hashtable sort using the wrong property accessor; explicit source/offset keys
fixed the witness ordering before the passing run. These are policy-model
results, not emitted warnings, source extraction, native alias enforcement or
IDE transport. Existing source-span and checked-graph tests remain separate.

Repository-root literal and source/diagnostic numeric searches for `UBE1514`
and `1514` found no matches outside this draft and native test artifacts on
2026-11-03. These searches omit ignored/generated files and nonliteral reserved
code ranges. The selected interface above now reserves the code; this historical
search did not itself allocate it. The native warning, CLI renderer and IDE
transport are unimplemented.
The confirmation is best-effort after commit: inability to display it must not
change a successful build into failure or misstate publication. The selected wording
and terminal detection still require production tests. Existing `--check` output stays
unchanged. Any frontend invalid/deferred input preserves its established exit 1,
code, location and output before any tool starts. New precommit build failures
return 1; prepare a complete diagnostic before its first write, with delivery
best-effort if the output stream fails. Never append a fallback to a partially
written diagnostic. A diagnostic-format allocation failure uses the fixed
allocation-free fallback `error UBE1509: native build failed` and does not alter
or publish the destination. A failed cleanup is separately observable without
masking the original error; prepare complete messages before printing.
After confirmed publication, attempt the allocation-free logical line
`warning UBE1512: executable built; temporary cleanup failed` on stderr if
cleanup fails. When available, follow it with the quoted affected path using
the existing path-display contract. A broken output stream may prevent delivery,
but the build still returns 0. Code and text are selected; actual stream behavior
remains an implementation qualification requirement.
Postcommit cancellation without another failure returns 0. Never report exit 1
for a known committed artifact. Exit 4, with an attempted fixed line
`error UBE1513: native executable publication outcome is unknown`, distinguishes
an unexpectedly indeterminate host commit result; it makes no claim about final
bytes. A known unsupported primitive/filesystem must be rejected before commit.
This defensive disposition does not establish that a selected host primitive
can satisfy the stronger old-or-new guarantee.

## Selected new build failures

Inventory follow-up: a repository-root `rg` search for literal codes
`UBE1500` through `UBE1513` in tracked or unignored `.bas`, `.c`, `.cpp`, `.h`
and `.json` files found no matches. A separate search for numeric values 1500
through 1513 in `src`, `SEMANTIC-DIAGNOSTICS.md` and
`PROJECT-DIAGNOSTICS.md` also found no matches. These searches do not inspect
ignored/generated files or prove that no other reserved-code inventory exists;
the results alone did not allocate codes. The reservation above records the
subsequent decision for the active compiler.

Each primary line is exactly `error CODE: MESSAGE`, followed by the associated
detail lines below. Paths use the existing quoted/escaped UTF-8 path display
contract. Tool exit is decimal; no untrusted tool output is incorporated into
the primary line.

| Disposition | Exact primary line | Detail lines |
| --- | --- | --- |
| Unsupported selected project setting | `error UBE1500: build setting is not implemented` | project path; key and selected value |
| Output path cannot be resolved or safely distinguished from an input | `error UBE1501: output path is invalid or aliases an input` | destination path |
| Lowering/output resource budget exhausted | `error UBE1502: native build resource limit exceeded` | resource category |
| Verifier establishes generated LLVM is invalid | `error UBE1503: generated LLVM validation failed` | selected verifier path |
| Tool cannot start | `error UBE1504: cannot start native tool` | tool path |
| Tool returns representable nonzero status | `error UBE1505: native tool failed` | tool path; nonnegative decimal exit status |
| Successful tool produces no usable candidate, including inspection/read failure, missing required debug records or an unestablished complete stack bound | `error UBE1506: native tool did not produce an executable` | candidate path |
| Cancellation before publication | `error UBE1507: native build was cancelled` | none |
| Candidate/output write, close, flush or atomic replacement failure | `error UBE1508: cannot publish native executable` | destination path |
| No-allocation formatting fallback | `error UBE1509: native build failed` | none |
| Wait, capture, drain, containment, or unrepresentable child-status failure | `error UBE1511: cannot observe native tool completion` | tool path; observation category |

For the bounded settings matrix, resolve omitted settings to the project-file
defaults before checking support. Preserve project parsing and its diagnostics
first: an invalid value is a project error even if another valid setting would
be unsupported. If both effective settings are individually outside the first
build's supported choices, report `Optimization` and its effective value as the
UBE1500 detail; otherwise report the unsupported `DebugInformation` value.
Explicit spelling and omitted defaults must make the same support decision.
This precedence is selected for the new build command, not a change to the
existing checker.

If cleanup of an owned temporary fails before publication, add the complete separate line
`error UBE1510: cannot remove temporary build artifact` followed by its quoted
path; this line is secondary to the original failure and never turns it into
success. A successful atomic commit remains success even if a later cancellation
request arrives, as stated in the publication contract. When multiple
source-attributable lowering failures can be observed without an external
cancellation or infrastructure failure, select the lowest canonical source ID
and that source's deterministic first failure, independent of worker completion
order. Do not replace that rule with whichever worker finishes first. Complete
or drain the necessary earlier work under the existing worker policy before
choosing; cleanup remains secondary. Cancellation and infrastructure failures
can prevent a canonical source result from being established, so their races
must use an explicitly observed controlled disposition rather than a claim that
all timing-dependent failures are byte-identical. A cancellation request must
not erase a primary failure already selected for reporting.
Under `NATIVE-TOOL-CONTRACT.md`, if tool stop remains unconfirmed after another
primary failure, append a secondary UBE1511/`containment` record with the tool
path and current capture details. Do not repeat it if that is already primary.
If process termination/Job-empty are confirmed and only capture cleanup remains
unresolved, use secondary UBE1511/`drain`; if both are unknown use `containment`.
Emit only that one secondary observation record for the same stop attempt.
Report safely retained owned temporary paths with UBE1510; do not imply that an
unconfirmed writer exited or remove its file to make cleanup appear complete.
The existing primary exit status remains unchanged.
The existing process boundary's `-3` means an unrepresentable child status;
it must not be displayed as the child's status. The selected UBE1511 category
must distinguish this case from start failure and a representable nonzero child
status. A verifier that fails to start uses the tool-start disposition; an
observation failure uses UBE1511. UBE1503 requires evidence the selected
verifier rejected the actual module as invalid, rather than assuming every
nonzero verifier exit means invalid IR. That evidence must be a qualified
machine-readable verifier result tied to the actual module, not a pattern match
against localized text. Otherwise report the tool failure. A linker-side disk
full reported as a representable child exit is UBE1505; a compiler-owned
candidate write, flush or replacement failure is UBE1508.
The no-publication fallback and ordinary failure results apply before commit;
after confirmed publication, a cleanup problem is a warning and exit remains 0.
Redirected/scripted success must not require a diagnostic-formatting step after
commit. The optional terminal confirmation cannot determine success or trigger
a failed build disposition. Preparing a diagnostic completely does not guarantee an OS write is
complete: if writing fails partway, return the appropriate result without
claiming delivery or appending a fallback to a partial message.
The test harness must force each condition individually and test the fallback,
exit, exact logical message, related path/status and unchanged destination.

## Tool-output policy and host observations

A focused C probe in `tests/native-executable/terminal/probe.c` compiled with
the local Windows-target Clang and reported `_isatty(_fileno(stdout))` as 0
both through the default command transport and when the execution tool was
asked for a PTY. Both processes exited 0. The latter observation does not
establish how stdout was connected through the execution tool and `rtk proxy`,
nor does it prove that a real interactive Windows console is detected. It
therefore does not qualify terminal detection; test a confirmed console handle,
redirected file and redirected pipe independently before implementing the rule.
As a separate file-redirection observation, PowerShell `Start-Process` launched
the same probe with `-RedirectStandardOutput` and `-WindowStyle Hidden`; the
file contained `stdout_terminal=0`. This does not establish the true-console
case or production behavior. A second C probe, `terminal/console.c`, was
compiled with the same Windows-target Clang and launched with PowerShell
`Start-Process -WindowStyle Hidden -Wait`; it wrote its result to a separate
file. In that hidden-console run `GetConsoleMode` on stdout succeeded and
`_isatty(_fileno(stdout))` also returned true (`console=1 terminal=1`). This
supports the candidate detection mechanism for that confirmed console, but is
not a test of the production compiler, other terminal hosts or failures in
terminal detection.
An attempted combined PowerShell assertion observed the expected console and
redirected-file report text but could not reliably read the fast redirected
child's exit code through `Start-Process -PassThru` (the property was empty).
That attempted assertion is not a passed test. A future harness needs a
retained process handle and confirmed exit status before treating this probe as
qualified evidence.
The subsequent `terminal/runner.c` probe launches `terminal/console.c` with a
hidden new console and separately with stdout redirected to a file, retains
each process handle, waits and checks exit status, then compares each report.
Compiled with local Windows-target Clang and run as
`rtk proxy bootstrap/out/native-terminal-runner.exe
bootstrap/out/native-terminal-console.exe bootstrap/out/native-console-run.txt
bootstrap/out/native-file-run.txt bootstrap/out/native-stdout-run.txt`, it
returned exit 0 and reported both handle checks passed. This resolves the
previous probe's missing exit observation for this focused host experiment;
pipe behavior and production integration remain separate tests.
An extended runner also created an inherited stdout pipe and checked the
child's retained handle, successful exit and `console=0 terminal=0` report;
the same command returned exit 0 for console, file and pipe. These are focused
current-host checks, not production integration or exhaustive terminal-host
coverage.
For the extended run, SHA-256 identities were console source
`3A1961FBCEAD5A32279FA28A9B1776F04146DA76B92744D2C49CA84A639C5CE6`,
runner source `3068AF092D65351DB27B9BCD58628DC9F13BFB565A551C8AFEC9DAD6F4069CA8`,
console executable `29ACDFC71889F2088D0C6EF4509FF0FF449E157100A6A7A6FD968D6507C03FA2`
and runner executable `F7ED036D0BF142BD53CFDD78CD01D0556C6127D1D0B647FFA847D27D21F56E9A`.
The runner was then extended with a `wrong` argument that reverses expected
terminal states. The normal command again returned 0; the same command with
`wrong` appended returned 1 and `console=7 file=7 pipe=7`. The revised runner
source SHA-256 was `6FBECD71092BFE3977951A03B61CFC61F70C4FED41C1A288E234E2B64E68811D`,
and its executable was `BF295960EE80147ADD8C13A6F188DB8E9899507F16CD45106051A792AC17D895`.

The contract selects no interactive tool input: supply an EOF-only input stream and
capture stdout and stderr separately. Drain both concurrently until EOF even
after the retained prefix fills, so a noisy child cannot block on a full pipe.
Retain at most the first 4096 raw bytes of each stream plus a truncation bit;
discard excess while continuing to drain. Successful tool output is not relayed;
the terminal-only build confirmation follows the rule above. The owner confirmed on
2026-11-02 that tool failures should show a clear error and useful readable
details when possible, with a safe fallback for unreadable output. On
failure print labeled excerpts after the primary path/status lines, stdout
first. Illustrative logical lines:

```text
tool stdout (truncated=0): compiling
tool stderr (truncated=1): invalid input\u{0}\xFF
```

Render valid UTF-8 characters as readable text; escape control
characters, backslashes and invalid or incomplete byte sequences unambiguously
so arbitrary bytes cannot impersonate compiler diagnostics. Do not silently
discard or replace unreadable bytes. An empty completed stream has an empty
excerpt; the truncation flag is 1 only when more than 4096 bytes were observed.
When capture could not be established, label it unavailable. If capture began
but failed before EOF, label the retained prefix partial rather than claiming a
completed truncation status. The selected rendering below still needs its
Unicode classification implementation and tests; labels and line endings are
fixed in the selected byte interface above. Output must remain readable and safe if truncation splits a
multibyte sequence. A capture, pipe, wait or drain
failure is itself a controlled build failure and never permits publication.
When launch or capture fails, distinguish unavailable output from an actually
empty stream; never fabricate an empty, untruncated successful capture.
Close owned pipe handles and confirm child exit and drain when possible; a child
or descendant retaining a pipe must not produce an unbounded wait. If confirmation
fails, return a controlled precommit failure with cleanup explicitly unconfirmed,
not a false claim that the tree drained. `NATIVE-TOOL-CONTRACT.md` selects the
deadlines, overlapped capture ownership and unresolved-cleanup disposition;
their production implementation remains a host qualification prerequisite.

For the selected rendering, decode the retained prefix as strict
UTF-8 without normalization. Emit ordinary printable characters unchanged;
write a literal backslash as `\\`, and render each malformed or incomplete
byte as uppercase `\xHH` in source order. Render ASCII controls, DEL and C1
controls as `\u{HEX}` using uppercase hexadecimal and no leading zeroes. Also
escape Unicode format characters using that same form, so bidi controls cannot
visually reorder the surrounding diagnostic. Escape U+2028 LINE SEPARATOR and
U+2029 PARAGRAPH SEPARATOR in the same form: some renderers treat them as line
breaks even though they are not ASCII newline characters. Each excerpt occupies
one logical line; a newline in child output is escaped, never emitted as a new
diagnostic line. Pin format-character classification to Unicode 18.0.0,
matching the repository's checked-in `DerivedGeneralCategory.txt`. The
existing `Unicode.bas` exposes letter and simple-fold operations, not a
format-character predicate, so that predicate and its independently checked
data generation would still need implementation and qualification; do not
assume the existing API supplies it.
Arbitrary non-UTF-8 tool output is preserved byte-for-byte in escapes rather than
decoded using a guessed code page. The new-message line ending is LF as fixed above.
The 4096-byte raw limit is not a 4096-byte rendered-output limit. Under this
selected escaping scheme one retained byte can expand to at most six ASCII
bytes (for example, byte `1F` becomes `\u{1F}`). Thus each complete excerpt
needs at most 24,576 rendered bytes, excluding its fixed label, status, path and
line ending; both streams can require 49,152 excerpt bytes. Calculate all
additional space with checked arithmetic and account for simultaneous raw and
rendered storage within the build budget. This bound depends on the exact rules
above and must be rechecked if those rules change.

Independent rendering examples: bytes `41 5C 42` render `A\\B`; bytes
`41 0A 42` render `A\u{A}B`; bytes `FF E2 82` render `\xFF\xE2\x82`; and a
valid U+202E between `A` and `B` renders `A\u{202E}B`; U+2028 and U+2029
between `A` and `B` render `A\u{2028}\u{2029}B`. Test each example,
including the same truncated UTF-8 prefix at byte 4096, and mutate one expected
escape as a negative control. These examples specify future tests, not observed
compiler output.
Also render 4096 copies of byte `1F`: the excerpt must contain exactly 24,576
ASCII bytes, all 4096 escapes, with truncation false. Add a 4097th input byte
and require the same prefix with truncation true. Mutate the expected length
and truncation bit independently to check the comparator.

The test-only `tests/native-executable/tool-output-reference.ps1` implements a
candidate reference rendering from raw bytes using the checked-in Unicode data.
`check-tool-output-reference.ps1` independently specifies examples including
invalid UTF-8, a supplementary format character and the 4096/4097 boundaries.
The command below returned exit 0 with 11 examples and altered-value controls:

```powershell
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/check-tool-output-reference.ps1 -OutputDirectory bootstrap/out/tool-output-reference
```

The first comparator run found that PowerShell's composite format expression
rendered the newline escape incorrectly; the reference was corrected before
the passing runs. These checks qualify only the listed examples of the test
reference; they do not implement or verify compiler output, every Unicode
character, process capture, or the proposed memory budget.
The checker was then extended with an empty stream and uses the same comparison
function for correct and altered expectations. The same command returned 0
with 12 examples and altered-value controls. This only checks rendering a known
empty input; it does not test the production distinction between an empty stream
and unavailable capture.
The same checker now includes a 256-byte sequence containing each possible byte
in ascending order, with independently constructed expectations for ASCII,
backslash, controls and the standalone invalid UTF-8 bytes in that sequence.
The command passed 13 examples and altered-value controls. This particular
sequence does not enumerate all multi-byte UTF-8 combinations.
The same command now passes 17 examples, including a C1 control, malformed
UTF-8 followed by valid ASCII, and four-byte UTF-8 sequences truncated after
two and three bytes at the 4096-byte boundary. Each retains altered-value and
inverted-truncation controls. This tests the reference renderer only, not the
compiler's future capture or rendering path.

The existing synchronous `CompilerRunTool` inherits standard streams and does
not establish this contract. This proposal requires a separately qualified
process boundary, not a claim that the existing intrinsic already captures or
cancels a child. Independently test empty streams, interleaved output larger
than pipe capacity, exactly 4096 and 4097 bytes, binary bytes, slow child,
cancel/drain and capture failure. Verify full primary output, prefix, flags,
quiet redirected success, brief nonblocking terminal confirmation and, when
confirmed, no live child or handles; explicitly test
unconfirmed cleanup when observation or termination fails. Wrong-prefix and
wrong-truncation controls must fail. The bounded build selects the 4096-byte
per-stream retention limit; it must be included in resource accounting and is
not a language limit. This selection does not establish production capture.

## Implementation qualification still required

The selected interface above fixes codes, details, streams, new-message bytes,
confirmation detection and failure presentation. Qualify the actual renderer,
byte writer, bounded console-write path and child capture against it. Capture
raw bytes without newline normalization; test LF versus CRLF, BOM insertion,
wrong stream, incomplete output and denied writes as distinct adverse controls.
Preserve the separate existing frontend/checker byte comparisons. A failed
required diagnostic write takes the stated result without a delivery claim.
For the selected delivery owner, force a stalled redirected pipe and console
write, successful short writes, zero progress, denied handle/thread setup,
timeout before and during a write, cancellation returning before completion,
and delayed completion after the stop deadline. Check unchanged caller handles/
modes, exact prefix/suffix accounting, no fallback after partial output, no
second writer or retained batch while one is unresolved, and release exactly
once after reaping. Use a controlled monotonic-clock seam at each deadline and
verify the default intervals separately; a passing classifier or synchronous
write alone does not qualify them. Test the payload cap below/exact/above,
fixed-fallback allocation failure, redirected success with no writer, optional
confirmation failure preserving exit 0, and required diagnostic failure retaining
its original exit status. These tests are future implementation obligations,
not prerequisites to selecting this bounded design.
The circular-warning analysis and IDE transport remain separate open work;
these message decisions do not qualify that analysis or the native backend.

## Review evidence for this selection

The repository-wide search for `UBE15[0-9]{2}` outside native review documents
and fixtures found no competing assignment. Numeric searches for 1500..1514
in `src`, `SEMANTIC-DIAGNOSTICS.md`, `PROJECT-DIAGNOSTICS.md` and the project
diagnostic JSON likewise found none. The code reservation is the review decision
above, not a claim that generated binaries contain no matching byte sequence.

The existing reference-renderer check was rerun and returned 0 with 17 examples
and altered-value controls. The stage-one raw-checker test returned 0 at jobs
1 and 4, matching CRLF bytes and rejecting the LF-only comparison control:

```powershell
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/check-tool-output-reference.ps1 -OutputDirectory bootstrap/out/native-diagnostic-review
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/newline/check-checker-bytes.ps1 -Compiler bootstrap/out/semantic-cli/e5b3d482d7fd46539e190ea70d20ecef/stage1/ube.exe
```

The compiler hash was
`DA13D5B42CD03EBA032E8E7944C2FD39446F849C09C50745634B69C414D7343A`.
The maintained console/file/pipe classifier probe also returned 0, while its
inverted-expectation control returned 1 with `console=7 file=7 pipe=7`:

```powershell
rtk proxy bootstrap/out/native-terminal-runner.exe bootstrap/out/native-terminal-console.exe bootstrap/out/native-diagnostic-review/console.txt bootstrap/out/native-diagnostic-review/file.txt bootstrap/out/native-diagnostic-review/stdout.txt
rtk proxy bootstrap/out/native-terminal-runner.exe bootstrap/out/native-terminal-console.exe bootstrap/out/native-diagnostic-review/console.txt bootstrap/out/native-diagnostic-review/file.txt bootstrap/out/native-diagnostic-review/stdout.txt wrong
```

These are scoped reference/host and retained-checker results. They do not test
the new command, stderr routing, LF byte writer, console rendering or its
deadline. `diagnostics.json` supplies 24 independently written future output
vectors; parsing it successfully is only a data-format check. The future
production gate must induce each stated condition and compare actual status,
stdout and stderr bytes without normalization, alongside the failure oracle's
artifact and cleanup checks. Wrong stream, newline, BOM, exit status and one-byte
message mutations must be rejected by that gate.
