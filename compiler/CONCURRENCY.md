# Concurrent compiler implementation assessment

Status: integrated source CallNew/runtime qualification, actual UBE lowering,
concurrent compiler correctness and useful parallelism measurements have passed
their scoped gates. Successive self-build comparison and final common
conformance have passed. See the final qualification below and Progress.md.
The governing gate is [ACCEPTANCE.md](ACCEPTANCE.md#final-compiler-concurrency-gate).

## Established requirements

Independent work inside one multi-module project must overlap on native
threads. Independent requests must also overlap in one compiler process.
Single-worker and multi-worker runs must agree on artifacts and ordered
diagnostics. Cancellation is cooperative; failed work must release its owners
without contaminating another request. Performance measurements accompany
correctness and overlap evidence.

Owner clarification, 2026-11-13: `CallNew` uses the same procedure-call syntax
and parameter semantics as `Call`, and accepts Subs and Functions. Both
`CallNew EntrySub(params)` and `WorkerId = CallNew EntrySub(params)` are valid;
the expression supplies a LongLong thread ID, not the called Function's return
value. ByVal retains ordinary independent value semantics and ByRef retains
ordinary reference semantics. Thread capture must keep referenced storage alive;
passing a caller stack pointer without lifetime protection is not admissible.
The grammar and both frontends now follow this decision. Explicit Call and
CallNew both allow omitted parentheses for a zero-argument target. A distinct
thread-start node retains ordinary argument binding and has LongLong result
type even when its target is a Function.

Shared ordinary module visibility, per-thread Err, cooperative stop, stable
thread identity and the approved waiting failure behavior remain required.
The bounded source worker gate below qualifies only its stated cases. A
compiler-specific callback-ID mechanism or separate compiler processes would
not establish the required source facilities.

## Measured source boundaries

- ProjectSyntax.TryAppendModule scans and parses into private candidate arrays
  before it checks duplicate module names, rebases and commits retained arenas.
  Candidate construction can execute independently; commit remains in manifest
  order. Refactor the existing implementation rather than duplicate it.
- ProjectLoader must continue validating containment and identity against the
  same open file owner before bytes become worker inputs. An unchecked worker
  reread of a pathname would weaken that guarantee.
- NativeLowering's public semantic passes independently rederive prerequisites.
  They can use immutable project inputs and separate scratch, with diagnostics
  selected in existing pass order. Their additional live memory must be measured.
- Procedure emission follows planning and resets numbering per function.
  Independent chunks could be combined in symbol order, while enforcing byte,
  line and work quotas for the whole request.

Two O2 diagnostic self-builds measured 66.191 and 69.120 seconds. Body emission
took 33.390/35.594 seconds, scanning 3.356/3.387, parsing 1.862/1.906, other
loading/publication 5.266/5.426, and native backend 5.141/5.110. Declaration,
expression, primitive and layout validation together took 16.657/17.250 seconds.
Therefore independent emission after immutable planning is the first measured
parallelization target. Parser-only parallelism would address about 5.3 seconds.

These are sequential measurements, not speedup claims. Test-only instrumentation
ran from an isolated source copy and compiled the unchanged 44-module compiler.
Both output executables matched the qualified self-build after only PE timestamp
normalization. Evidence, measurement scripts and results:
`C:\Users\Ubehage\AppData\Local\Temp\ube phase measurement 68e0a00c-507f-44f7-b803-9dabc97d8de9`.

### Emission worker ownership

`NativeCompilation` prepares authoritative semantic and layout facts once per
request. Workers borrow those immutable facts and own separate numbering,
traversal buffers, writer buffers and staged chunks. The private `EmitRange`
entry accepts the validated rendering catalog ByVal, using ordinary array
snapshot semantics to give each renderer its own descriptor and backing bytes.
This copies the small rendering asset, not project facts. The coordinator keeps
its original catalog for the header and footer. Single-worker calls and quota
replay use the same ordinary ByVal rule.

For CallNew, the catalog snapshot is prepared before worker publication and
retained by the typed capture until source execution ends. A failure preparing
a later snapshot enters the caller's failure path; previously started workers
must still finish before request-owned stages can be discarded. The additional
copies consume the existing shared 64 MiB program heap and introduce no separate
request allowance or change to output/work quotas.

The complete coordinator gate passed in
`ube concurrent compilation 95205396-5aaf-4636-b717-0b1298181b0b`. Its added O0/O2
cases return synthetic fresh FAIL with Err 8 from the second catalog copy-helper
call only after the first source worker enters. They assert completion/cleanup,
preservation of prior output and a usable subsequent request. This qualifies
copy-call failure handling, not the allocator's internal retry mechanism;
allocator fault qualification is separate.

The private-catalog and descriptor-stripe combination subsequently passed a
16-trial test-only experiment with identical outputs. Two striped workers
averaged 3499.33 ms versus 3821.21 ms for one worker with the original runtime;
the observed ranges did not overlap. Evidence is
`ube storage lock experiment d0c867f0-c730-4381-907a-bde46136113a`. The per-program
stripe state is now integrated. The final integrated correctness and idle timing
reruns described below qualify this combination; the earlier experimental
result alone was not sufficient for acceptance.

## Runtime and publication dependencies

The sequential context originally combined Err, call depth, module initialization,
module storage, allocator ownership and resource slots. Sharing it between
native threads would race. Giving each CallNew thread a fresh entire context
would instead duplicate module globals and initialization, violating the
approved visibility contract. Thread-local execution state and shared program
state therefore require distinct ownership; that partition is now implemented.

Array descriptors and block reference counts originally required exclusive
context ownership. The original atomic resource-slot busy flag did not protect
the allocator, Err or concurrent descriptor replacement. Both capture and
shared-storage access require explicit safety and failure tests; raw descriptor
or owner-token handoff is not a substitute.

Compiler work remains request-owned. Diagnostics should be returned to a
coordinator before rendering, so concurrent standard-stream writes cannot mix
messages. Private stages already use exclusive creation; competing publication
needs a defined coordinator order or controlled conflict refusal. No unfinished
project facts or partial output may become visible to another request.

### Approved runtime ownership change

Keep the existing root context allocation/init/dispose interface. Introduce a
small execution-thread header containing Err, call depth, program pointer and
thread-control pointer. A root context embeds that header and the program's
shared storage; each child thread has its own header pointing at the same
program. Independent root invocations have separate programs. Simultaneous
compiler requests within one program share its runtime resources while retaining
separate source facts, diagnostics and publication ownership.

The shared program owns module initialization/storage, allocation accounting,
resource registry, worker admission and completion records. Its storage lock
protects allocator bookkeeping and descriptor writers. Descriptor snapshots
instead take one program-owned descriptor lock, read all four descriptor cells
and retain the payload before releasing that lock. Clear and install take the
storage lock first, then the descriptor lock; final boxed-array release follows
the same order. No descriptor-lock path takes the storage lock. Byte-range copy
still holds the storage lock, excluding all published descriptor replacement,
and reads/writes payload cells atomically. Collection uses the storage lock and
atomic reference counts. Release these locks before a UBE call, wait or
child-process invocation. Existing original-storage alias semantics remain
protected by retaining storage before releasing the descriptor lock. Ordinary
shared scalar/element accesses require non-tearing atomic operations; volatile
alone does not prevent LLVM data-race undefined behavior. Compound source
updates remain non-atomic unless explicitly synchronized.

Program field 13 contains `[65 x [8 x i64]]`: one leading 64-byte padding region
and 64 lock words spaced 64 bytes apart. Mixed descriptor-address bits choose
indices 1 through 64. Colliding descriptors serialize safely; lock addresses
remain scoped to their owning program. This adds 520 cells to the context;
host and UBE sizing use `853 + 2 * ModuleCount + ContextCells` cells, and context
initialization zeros the entire allocation, including locks and padding.
The four-cell array descriptor, three-cell allocation header, quotas and imports
are unchanged. Canonical integration has runtime text of 152116 bytes and 170
templates totaling 23487 bytes (sum 1843860). Read-only review confirms the
implemented lock order and layout; refreshed context, contention, ownership and
compiler gates provide execution evidence separately.

The owner explicitly approved this necessary runtime ownership change on
2026-11-13 after the distinction between per-thread errors/call state and shared
program memory was explained. The partition, shared storage locking, owner
references and native lifecycle code are implemented. Qualification must still
be reported by the exact gates exercised; the assessment and phase measurements
do not qualify concurrent compiler execution.

### Source capture implementation and evidence

`NativeEscapes` and its host counterpart derive ownership from checked source
facts. Direct asynchronous ByRef aliases and grouped temporaries seed a bounded
reverse parameter-to-actual graph. A mark-once worklist propagates ownership
through ordinary calls, including recursive chains. ByVal aggregate thread
arguments always own independent snapshots; an ordinary aggregate ByVal parameter
that itself escapes also propagates ownership to its caller's snapshot. Scalar
ByVal parameters own their own promoted local storage. Global storage remains
program-owned. The analyzer uses existing node/symbol limits and the native
planning work budget, and publishes one complete fact array atomically.

Only escaping local storage is boxed. An escaping fixed local array uses a
boxed descriptor and a separately retained payload with its original bounds.
An indexed alias retains the selected payload; analysis also promotes its
underlying local/parameter path so inline fixed storage cannot escape. Hidden
owner pointers accompany escaping ByRef and aggregate ByVal parameters. Grouped
and aggregate argument boxes are allocated per evaluation, including repeated
execution of the same call site.

Each CallNew site has a statically selected worker thunk. Its capture contains
two cells per actual argument: the value/address and its retained owner. All
ordinary argument evaluation and conversion finishes before worker admission.
Successful start transfers the capsule to the runtime; failed start releases
its captured references and capsule. The thunk invokes the ordinary procedure,
discards a Function's own result, releases typed captures, and reports its fresh
outcome. The runtime releases the capsule and stores completion independently
of stale Err. No source callback registration API is introduced.

The host command
`rtk proxy powershell -NoProfile -File runtime/tests/callnew/check.ps1`
passed at O0/O2 using the freshly built host retained in
`ube native workers 6e56a4fa-607e-4158-bbb8-444bb4d39224`. Its source assertions
cover creator-return/multiple-call ByRef lifetime, an indexed fixed-array record
field, ByVal record/array snapshots, grouped temporary reuse across iterations,
discarded Function results, trusted Err.Clear, and repeated fresh failed waits
with captured Err.Number zero. This was an earlier host-only recording. The
integrated actual-UBE lowering gate subsequently passed at O0/O2 in
`ube native lowering 9532c629-4090-47d5-b971-a58723286aa4`, including capture-failure
recovery (`ube worker faults 777bebee-5f99-4ad5-9255-2176e9834f05`).

Static ownership qualification uses the expression-binding gate: 70 cases and
26,561 assertions passed at O0/O2, with its changed-expression control detected
at assertion 759 (`ube expression binding
792736cc-6fcf-44ac-9ec9-901f089729d9`). The host ownership probe passed against
the same fixture (`ube host escapes 3d16e5e9-8f4f-4f37-a34b-89eccc796f82`).
The shared allocation gate with `-Analysis Escape` passed 30 allocation/depth
checks after measuring six allocations, including failed publication, retained
old facts, retry and zero live owners after disposal (`ube escape allocation
d27a313a-b4b2-411b-ae3d-495f2094e6b2`). Its ordinary expression regression passed
48 checks (`ube expression allocation f13a2c5c-25a2-454c-8f15-4fabcbe2b58a`).

These results do not establish concurrent compiler requests, parallel emission,
schedule-independent compiler artifacts or performance gains. The ordinary
admitted datatype/call profile still applies; this work does not claim arbitrary
objects, optional arguments or aggregate Function results. The low-level source
library currently exposes `ThreadPrimitives.Wait` with an explicit timeout;
the complete public convenience interface requires its own qualification.

## Resource registry review and contention qualification

The shared resource registry already has a per-slot ownership protocol in
`bootstrap/src/NativeFileRuntime.bas`: reserve (line 108) and acquire (line 171)
claim the busy flag with compare/exchange and recheck the token after claiming.
The generated `compiler/llvm/windows-runtime.ll` implements these at lines 623
and 680. Forget (line 715) clears handle, allocation and token before releasing
the claim. File open publishes under the reserved claim (lines 847–964); close
holds it through handle release (lines 1134–1158). Final-path lookup also acquires
the owner (line 1586). Process start claims its own slot and claims the log owner
while duplicating its handle (lines 2675–2691); wait/terminate/close use the same
acquisition protocol. These are reviewed source locations, not execution proof.
No missing registry synchronization was found and no production patch was made.
The per-owner claim may span OS I/O; no shared registry or storage lock spans that
wait. Independent owners remain usable while concurrent use of one owner returns
the already specified Busy failure.

`runtime/tests/resource-concurrency/check.ps1 -BootstrapExe <qualified-host>`
passed O0/O2 (`ube resource concurrency
b0bd98d8-7b0c-43ab-b892-297f6579c03c`). Four fresh-context schedules each run eight
real source CallNew workers, with an eight-open barrier, conditional yields,
128 created/written/reopened/read/deleted files and 256 pairwise-distinct positive
tokens. Exact byte, length, transfer-count, status and cleared-token assertions
pass. A separate deliberately held slot makes a source worker's same-token write
return False/Failure 13/Err 5 with zero transfer. After worker drain, disposal
refuses the live owner; source cleanup then permits disposal with an empty
registry and zero native allocations. The same source corpus subsequently
passed through actual UBE lowering at O0/O2 via the native-lowering gate's
`-ResourceConcurrencyOnly` bridge: compiler-driver evidence
`ube native lowering 069314ae-ecd7-4a35-81ba-bdee112d0b18` and complete resource evidence
`ube resource concurrency a4ade310-e47f-4349-9062-dcbb496fd69b` under the system
temporary directory. These are bounded reviewed schedules. Process-owner
contention and full concurrent compiler execution were separate obligations;
the final integrated coordinator qualification below covers their stated cases.

After the pending-retirement context/drop update, the actual UBE bridge passed
again with bootstrap `ube native context 49f0f01f-46f9-41d6-ae3e-610eb5293a0e/build/UBE-Bootstrap.exe`:
`bootstrap/tests/native-lowering/check.ps1 -BootstrapExe <that executable> -ResourceConcurrencyOnly`.
O0/O2 each passed all four eight-worker schedules, 128 files and 256 unique
tokens per schedule, exact bytes, same-owner Busy, empty registry and zero
allocations after disposal. Driver evidence is
`ube native lowering 4d0448ef-3621-4c30-8c38-e16f43eff5ca`; resource evidence is
`ube resource concurrency de301f68-b1b8-4661-82a5-be42b3b2344d`.

## Approved worker completion failure

Owner clarification, 2026-11-13: an error ending the entry procedure allows the
worker to end normally; a caller waiting for its result receives FAIL.

- A fresh FAIL escaping the worker's entry procedure ends that worker through its
  normal lifetime cleanup. Preserve the fresh outcome and error information
  in completion metadata. A stale Err on normal return remains success.
- ThreadWait returns 1 for normal completion. Observing failed completion
  instead publishes the captured error on the waiting thread and returns a
  fresh FAIL, following that waiter's ordinary statement/handler rules. No
  usable return value is assigned. Each waiter, including a repeated wait,
  observes a fresh failure independently; the worker never executes another
  thread's handler. Preserve an explicit failure bit even when Err.Number is 0.
- Timeout or cooperative interruption returns normal 0 without modifying Err.
  A worker that observes cancellation and returns normally completes normally.
- Reserve bounded completion metadata before exposing a new worker and retain
  its outcome for that ID's program lifetime. Refuse creation before starting
  if the documented quota cannot admit another record. Release native handles,
  stacks and transient capture storage independently of retained metadata.

No separate ThreadCompletion query is introduced. Explicit user resources
still need explicit cleanup; compiler-owned locals follow normal cleanup.
Foreign callbacks, event/UI dispatch and other lifecycle boundaries remain
separate decisions.

## Acceptance and publication

### Performance baseline before collector optimization

The uninstrumented O2 source-to-LLVM request benchmark ran the same immutable
51-module compiler-plus-probe package (722,143 source bytes) in the order
1, 2, 2, 1 workers, while other agent build/test jobs were idle. This measures
the complete compilation request through the UBE-written routines; it excludes
the native backend and construction of the benchmark driver. Machine identity:
AMD Ryzen 9 3950X 16-Core Processor, AMD64, 32 logical processors. The sandbox
did not permit the CIM physical-core query.

| Trial | Workers | Milliseconds |
| --- | ---: | ---: |
| 1 | 1 | 120003 |
| 2 | 2 | 151002 |
| 3 | 2 | 152755 |
| 4 | 1 | 123077 |

All four outputs have SHA-256
`E04E6F1E1E189089040F4AD22798C56ADF4400C8F6EEED9927D6C1272682EBF2`.
The two-worker mean was 151,878.5 ms versus 121,540 ms for one worker, about
25% slower. This historical baseline did not establish useful parallelism;
overlap/correctness observations alone were insufficient.
Raw measurements, executable hashes and hardware metadata are retained in `ube concurrent compilation
38e1d451-c37a-4bfb-94d5-f36e273423a9` under the system temporary directory.

The subsequent [runtime profile](../runtime/tests/storage-profile/README.md)
recorded over one billion collection scans per request. Almost all reclaimed
nothing; two-worker collection lock acquisition recorded over 24 billion failed
CAS attempts. The implemented pending-retirement flag skips scans when no final
reference has been released. Its [focused regression gate](../runtime/tests/pending-retirement/README.md)
checks scan ordering, failed-release retry, forced allocation scans and context
reuse, including a deliberately incorrect clear-at-end negative control.
The subsequent idle comparison reused the original checked source ledger:
one-worker trials took 4022 and 4005 ms, and two-worker trials took 4735 and
5059 ms. That two-worker mean was still 22.01% slower (4897 versus 4013.5 ms).
All outputs matched SHA256
`4574D383A868F2466636E2AE44EE815DBDBBB13C534ED2C91ACB87342FE4E91C`.
Evidence is `ube concurrent compilation ff13c308-eb90-4949-a5b6-73be79b53f00`.
That absolute improvement did not establish useful parallelism. The later
private rendering catalogs, scalar formatting cache and per-program descriptor
stripes were qualified separately before the final integrated measurements.

### Final integrated qualification

The complete coordinator correctness command passed with exit zero in
`ube concurrent compilation 30afd7ad-b7cf-4153-a352-0b8b29e31988`, using the
compatible bootstrap
`ube native context 5b726a73-2fe7-48a4-865b-887e684959b6/build/UBE-Bootstrap.exe`.
The [gate command and source mapping](../bootstrap/tests/concurrent-compilation/README.md)
record the exact invocation and retained evidence. Assertions cover:

- Overlapping actual emission ranges and same-process requests, exact
  independent one/two-worker IR baselines and an O2 staggered schedule.
- Complete ordered diagnostics, work-boundary and footer byte/line quota
  replay, and atomic competing publication.
- Cancellation after both selected workers have emitted real symbols,
  request-selective worker failure alongside successful work, and fresh
  completion failure with Err.Number zero.
- All-worker observation before retained-close failure, successful cleanup
  retry, and synthetic second-catalog-copy failure after the first worker starts.
- Concurrent native backends with independent executable exit oracles,
  exit-7 failure and a 30-second timeout alongside successful work, prior-output
  preservation, and a subsequent usable request in the same process.

The final idle timing reran the same checked 51-module, 722143-byte frozen
workload on the same machine, with scheduling observers disabled. The exact
command is recorded in the linked gate README. Evidence is
`ube concurrent compilation 39e257c4-0c53-40d9-885a-7938c4adb51d`.

| Trial | Workers | Milliseconds |
| --- | ---: | ---: |
| 1 | 1 | 3939 |
| 2 | 2 | 3581 |
| 3 | 2 | 3517 |
| 4 | 1 | 3915 |

Two workers averaged 3549 ms versus 3927 ms with one worker: 9.63% less elapsed
time. The observed ranges did not overlap. All four output SHA-256 values were
`8D4021512E2C1F4F4DAE9D0B560DA3358D1D8B158E5F484C52AACF5D69B81115`.
The evidence retains raw times, the validated source ledger, hardware identity
and driver/runtime hashes. This establishes useful parallelism for the tested
workload and machine, not a fixed speedup for other inputs or hardware. It
measures source-to-LLVM requests and excludes driver construction and native
backend execution. Worker counts are explicitly bounded to one or two, and
simultaneous requests share the existing 64 MiB program heap.

The scoped synchronization review and contention/fault assertions complement
these measurements; neither stress schedules nor overlap alone prove absence
of all races. No race-detector result is claimed. Final successive self-build
comparison and common conformance have passed; exact commands and final
artifacts are recorded in Progress.md.

Qualify the admitted thread/capture/storage dependencies at O0/O2, with exact
fault, ownership, visibility and recovery assertions. Then exercise the real
compiler with single/multiple workers, repeated varied schedules, concurrent
requests, dependency and output contention, cancellation and worker failure.
Record overlap and phase/performance evidence without promising a fixed speedup.
Re-run self-hosting and common conformance after production changes.

Only after those gates pass, update the root README and completion checkboxes,
then commit and push to GitHub main under the owner's current authorization.
