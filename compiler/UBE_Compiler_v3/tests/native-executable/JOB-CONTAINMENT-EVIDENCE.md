# Focused Windows process-containment probe

On 2026-11-02, the test-owned probe source in
`bootstrap/out/job-containment-review/probe.c` had SHA-256
`2E62BEB6762C84AC2405B8B65F9AD04FA90C5287D30B6E63CA7FA67A430F885F`.
It was compiled using Clang 23.1.3, SHA-256
`F3425B2BFF01BC401C84AF6E5E180629182FAFC2EB35CF971A3E50C9CF13F263`:

```powershell
rtk proxy "C:\Program Files\LLVM\bin\clang.exe" --target=x86_64-w64-windows-gnu -std=c17 -Wall -Wextra -Werror -municode bootstrap/out/job-containment-review/probe.c -o bootstrap/out/job-containment-review/probe.exe
rtk proxy bootstrap/out/job-containment-review/probe.exe
```

The executable SHA-256 was
`B0C4EA6D30DDBAFA7123051B191DF0EE6C5764B40ADDA9126880F9D3B3C081BA`.
It exited 0 and printed `ready: active=2` followed by
`terminated: active=0 child_exit=73`. The parent created a kill-on-close Job,
started its test-owned child suspended with `CreateProcessW`, assigned it before
resume, and waited for a named event from the test-owned grandchild. Job
accounting reported two active processes; after `TerminateJobObject(73)`, the
direct child wait succeeded and accounting reached zero. A separate repeat of
the executable produced the same exit and output. The first compilation attempt
failed on redundant `UNICODE` redefinition with `-municode`; removing the
redundant macros produced the passing source and command above.

This demonstrates only the described test on the current host and Job context.
It does not verify pipe drainage, exact Unicode argument transport, independent
grandchild-handle observation, restricted/nested/breakaway Jobs, cancellation
deadlines, arbitrary filesystem behavior, or production compiler integration.
Job accounting is the observation used here; it is not a universal no-orphan
proof. The source and executable are generated OUT artifacts, not production
implementation or a permanent host API. The final build contract still requires
the independent failure cases and a qualified host boundary.

The same source is now retained at `job-containment/probe.c` under this test
directory. Compiling it with the command above after substituting that source
path and `bootstrap/out/job-containment-review/maintained-probe.exe` as output,
then running that executable, returned exit 0 with the same two reported lines.
This preserves the focused test input; the qualifications and exclusions
above remain unchanged.
The retained source SHA-256 remains
`2E62BEB6762C84AC2405B8B65F9AD04FA90C5287D30B6E63CA7FA67A430F885F`; the
recompiled executable was
`00BDBEDF533721D62B21044D6BD8BE23787BB1E061E52E0CC77BD2A3673CBA84`.

The retained probe was extended with a `child-exits` mode, in which the direct
child starts the grandchild and returns 0. The controller waits for both the
grandchild's readiness event and the direct child's exit before querying Job
accounting. On the current host the following commands both exited 0:

```powershell
rtk proxy "C:\Program Files\LLVM\bin\clang.exe" --target=x86_64-w64-windows-gnu -std=c17 -Wall -Wextra -Werror -municode compiler/UBE_Compiler_v3/tests/native-executable/job-containment/probe.c -o bootstrap/out/job-containment-review/maintained-probe.exe
rtk proxy bootstrap/out/job-containment-review/maintained-probe.exe child-exits
```

The second command reported `ready: active=1` and
`terminated: active=0 child_exit=0`. The ordinary two-live-process control
also passed and reported the earlier active-2/exit-73 observations. This shows
that a successful direct-child exit is not sufficient to establish that its
contained descendant has exited. It does not test a descendant writing a
candidate or holding a pipe, or qualify production containment. The revised
source SHA-256 is
`7329E77F74F45903D2026C12FA5C5D29340AA5443C2697D0CFC59CA6DD1BB1CB`
and executable SHA-256 is
`35306B25A5FD38250350C6CE071C53DB53357A4A63497E0AD4BF5F7228774DB9`.

The probe was subsequently revised to poll the expected initial Job count for
at most five seconds after readiness (and child exit in `child-exits` mode),
instead of requiring the first accounting query to show that count. Rebuilding
with the same command and running both modes again returned exit 0 with the
same respective active-2/exit-73 and active-1/exit-0 observations. The revised
source SHA-256 is
`9A542C456D36C140D4739AAEAEB6AE314D05BCA33C1397E7BE277AA95DACDE03`
and executable SHA-256 is
`A64EFC8C232C56FFDEA5C794786AADD20D622B8114F3A786D462DDF9418FCD1D`.
This bounded polling does not change the probe's scope or establish pipe or
candidate-write handling.

A separate retained probe, `job-containment/late-write.c`, creates a new
test-owned candidate with `CREATE_NEW`, starts a contained child, and waits for
both the child's successful exit and its descendant's readiness. It confirms the
candidate still contains `prefix`, releases the descendant, waits for Job
accounting to reach zero, then checks the candidate contains `prefix-late` and
removes that test file. On this host these commands returned exit 0:

```powershell
rtk proxy "C:\Program Files\LLVM\bin\clang.exe" --target=x86_64-w64-windows-gnu -std=c17 -Wall -Wextra -Werror -municode compiler/UBE_Compiler_v3/tests/native-executable/job-containment/late-write.c -o bootstrap/out/job-containment-review/late-write.exe
rtk proxy bootstrap/out/job-containment-review/late-write.exe bootstrap/out/job-containment-review/test-candidate-72394.tmp
```

The run printed `child exit 0; descendant changed candidate after release`.
It demonstrates the late-write hazard under this controlled Job setup, not the
compiler's handling of it, pipe drainage, or unrestricted external processes.

The same probe now also has a `cancel` control: after observing the successful
direct-child exit and unchanged prefix, it terminates the Job instead of
releasing the waiting writer, waits for active count zero, and checks the
candidate is still exactly `prefix`. Recompiling with the command above and
running the following two commands returned exit 0; the first reported the
late change and the second reported the unchanged candidate.

```powershell
rtk proxy bootstrap/out/job-containment-review/late-write.exe bootstrap/out/job-containment-review/test-candidate-control-0.tmp
rtk proxy bootstrap/out/job-containment-review/late-write.exe bootstrap/out/job-containment-review/test-candidate-control-1.tmp cancel
```

This is a controlled host experiment using a waiting descendant and Job
accounting; it does not qualify production cancellation, pipes, timing bounds,
or behavior when termination or observation fails.

The retained probe was further extended with an inherited anonymous pipe. After
the direct child exits, the controller observes an open, empty pipe while the
waiting descendant holds its write end. After normal release or Job termination
and a zero Job count, it waits up to five seconds for the read end to report a
broken pipe. Recompile with the `late-write.c` command above, then run:

```powershell
rtk proxy bootstrap/out/job-containment-review/late-write.exe bootstrap/out/job-containment-review/test-pipe-control-0.tmp
rtk proxy bootstrap/out/job-containment-review/late-write.exe bootstrap/out/job-containment-review/test-pipe-control-1.tmp cancel
```

Both returned 0: the normal case observed the descendant's late candidate write,
and the cancellation case observed unchanged candidate bytes. Both observed
pipe closure after the descendant exited. The first version required closure on
the first check and the cancellation case failed; the bounded-wait revision
passed both. This result does not identify why the first check failed, or prove
concurrent pipe drainage, bounded production waits, or an explicit inherited
handle list.

The separate `job-containment/breakaway.c` probe creates a Job without either
breakaway permission, starts a child suspended, assigns it to that Job and
resumes it. The child confirms it is in a Job and attempts to start a short-lived
grandchild. On this host the ordinary creation control succeeded, while a
`CREATE_BREAKAWAY_FROM_JOB` request failed with access denied. The following
commands each returned 0:

```powershell
rtk proxy "C:\Program Files\LLVM\bin\clang.exe" --target=x86_64-w64-windows-gnu -std=c17 -Wall -Wextra -Werror -municode compiler/UBE_Compiler_v3/tests/native-executable/job-containment/breakaway.c -o bootstrap/out/job-containment-review/breakaway.exe
rtk proxy bootstrap/out/job-containment-review/breakaway.exe test-normal
rtk proxy bootstrap/out/job-containment-review/breakaway.exe test-breakaway
```

This checks one explicit breakaway request in the current Job context. It does
not establish behavior for inherited or nested Jobs with different policies,
other process-creation mechanisms, cancellation, pipes or production integration.
The probe was then extended to assign its controller to a test-owned outer Job
before creating and assigning the child to the inner Job. After recompiling with
the same command, both `breakaway.exe test-nested-normal` and
`breakaway.exe test-nested-breakaway` returned 0: ordinary descendant creation
worked and the explicit breakaway request was denied. The two original controls
also passed after the rebuild. This covers that one nested configuration on
this host, not arbitrary parent Job restrictions or all escape mechanisms.
The probe now gives the inner Job a test-owned name and has both child and
grandchild query membership in that particular Job. After recompilation, the
normal and nested normal cases both reported the grandchild in the expected
Job; both explicit breakaway cases remained denied. A `test-wrongjob` control
substituted a nonexistent Job name for the grandchild and was rejected. All
five probe invocations returned 0. This still does not cover arbitrary parent
Job policies or production process containment.

The independent `job-containment/drain.c` probe starts a suspended child with an
explicit three-handle inheritance list, a NUL input handle and separate stdout
and stderr pipes. Two reader threads drain concurrently while the child writes
65,536 bytes to each stream and exits 41. On this host the probe checked both
complete byte counts, each 4096-byte retained prefix, the actual child exit and
negative controls for wrong prefix/count. These commands returned 0:

```powershell
rtk proxy "C:\Program Files\LLVM\bin\clang.exe" --target=x86_64-w64-windows-gnu -std=c17 -Wall -Wextra -Werror -municode compiler/UBE_Compiler_v3/tests/native-executable/job-containment/drain.c -o bootstrap/out/job-containment-review/drain.exe
rtk proxy bootstrap/out/job-containment-review/drain.exe
```

This is a host-only capture experiment. It does not combine the drain with the
Job probe, validate NUL-input behavior, inject failures, test an inherited pipe
held by a descendant, or prove production cancellation and bounded cleanup.
The probe was then extended to assign the suspended child to a kill-on-close Job
before resuming it, require the child to observe EOF on its NUL input, and
require Job accounting to reach zero after the child exits. Rebuilding and
running the same commands returned 0 with input EOF, child exit 41, zero active
Job processes, both 65,536-byte stream counts and 4096-byte prefixes, plus the
wrong-prefix/count controls. This combines the specific Job and pipe success
cases on this host; descendant-held pipes, cancellation, fault injection and
production integration remain untested by this probe.
The probe now also accepts `cancel`: after writing both complete streams, the
child signals an event and waits. The controller terminates the Job, observes
child exit 73 and zero active Job processes, joins both readers, and checks the
same byte counts, retained prefixes and negative controls. After rebuilding,
both `drain.exe` and `drain.exe cancel` returned 0 on this host. This exercises
one controlled cancellation after completed writes; it does not cover a
descendant retaining a pipe, failure to terminate or observe, cancellation
while writes are partial, or production integration.
The additional `drain.exe cancel-partial` case makes the child write and signal
after exactly 5,120 bytes on each stream, before its normal 65,536-byte total.
The controller then terminates the Job and checks exit 73, zero active Job
processes, both 5,120-byte drained counts, the retained 4,096-byte prefixes and
negative controls. After rebuilding, normal, `cancel`, and `cancel-partial`
all returned 0. The event is raised between completed writes, so this does not
test termination in the middle of a pending OS write or a descendant-held pipe.
The `drain.exe descendant` case now starts a contained descendant that inherits
both pipe write handles and signals readiness. After the direct child exits 41,
the controller confirms that both reader threads are still waiting; it then
terminates the Job, observes zero active processes and joins both readers with
the expected 5,120-byte counts and 4,096-byte prefixes. This mode and the three
earlier modes all returned 0 after rebuilding. The observation uses Job
accounting rather than a separately retained descendant process handle, and it
does not test failed termination, a pending write, or production integration.
The probe now also creates an inheritable event that is omitted from the
three-handle inheritance list. A `leak-control` mode adds the event to the list
and requires the child to detect it instead. The first check incorrectly assumed
the numeric handle value must be invalid in the child; intermittent failures
showed that handle values can be reused. That check has been replaced by a
test-only comparison against the named event's actual object identity. After
rebuilding, all seven modes, including the intentionally leaked-handle control,
returned 0; 20 additional parallel `excess` runs also returned 0. This checks one
unrelated event handle and an inverted control on this host; it does not prove
exclusion of every handle type or a production implementation's inheritance list.
The new `exact` and `excess` modes additionally check 4096 and 4097 bytes per
stream respectively: both retain the same 4096-byte prefix, with excess observed
only in the latter. The first excess run failed before the handle-identity
correction; the corrected run and the repetitions above passed.
The probe now also has `out-excess` and `err-excess` modes. Each writes 4097
bytes to one stream and 4096 to the other, checks both counts and prefixes, and
requires the independently computed excess states to differ. After rebuilding,
both modes and all seven earlier modes returned 0. This is a host-only probe;
it does not establish the future compiler's truncation flags.
The separate `duplex` mode explores the unselected streamed-input alternative.
The contained child writes 65,536 bytes to each output before reading 131,072
input bytes; the controller writes input and drains both outputs concurrently.
The test checks the exact input pattern and count, output counts and prefixes,
child exit and empty Job. `GetNamedPipeInfo` reported 4096-byte capacities for
all three pipes, so each transfer exceeded the observed capacity. After the
same compile command, `drain.exe duplex` and the nine existing modes all
returned 0. This is one successful host experiment, not approval of streamed
stdin, a production implementation, or evidence about cancellation, a broken
input pipe or arbitrary tool behavior in this mode.
The `duplex-undrained` negative control starts the same large exchange without
starting output readers. After one second both child and input writer were still
blocked; terminating the test Job stopped the child with exit 73 and released
the input writer with an incomplete write. The normal `duplex`, `descendant`
and `leak-control` modes also passed after the rebuild. This confirms sensitivity
to an undrained-output stall in the host probe, not a production timeout policy.

The test-only `duplex-close-input` mode makes the contained child close its
input before producing both 65,536-byte output streams, then exit 0. After
rebuilding with the compile command above,
`rtk proxy bootstrap/out/job-containment-review/drain.exe duplex-close-input`
returned 0: the writer observed Windows error 232 after 5,120 complete input
bytes, both output streams were fully drained and checked, and Job accounting
reached zero. The byte count depends on scheduling and is not an expected
constant. The child exit alone did not report the input failure; a real
streaming handoff must account for the writer outcome independently. The
`duplex`, `cancel-partial`, `descendant`, and `leak-control` modes also returned
0 against this rebuild. This is a host-only experiment for the unselected
streamed-input alternative; it does not qualify the production tool boundary,
prove every broken-pipe result, or establish a bounded cleanup guarantee.

The `candidate-descendant` mode passes an empty test-owned file as the child's
read-only standard input, with delete sharing but no write sharing. The direct
child starts a contained descendant that inherits this handle and then exits 41.
After observing the direct child exit and descendant readiness, the controller
could not open the candidate for writing; after Job termination and an observed
zero active-process count, the same write-open succeeded. Both output pipes were
drained and checked. The file was created empty with
`[IO.File]::WriteAllBytes('bootstrap/out/job-containment-review/empty-candidate.bin', [byte[]]@())`,
then `rtk proxy bootstrap/out/job-containment-review/drain.exe candidate-descendant bootstrap/out/job-containment-review/empty-candidate.bin`
returned 0. The probe was rebuilt with the Clang command above; `descendant`,
`duplex-close-input` and `leak-control` also returned 0. This observes one
inherited read handle and a cooperative containment scenario, not production
integration, failed termination, arbitrary inherited handles or publication.

The mode was then strengthened and now uses a two-byte `XY` test file rather
than the earlier empty file. The direct child reads `X`; after the controller
observes that child exit, it signals the retained descendant to read `Y` and
waits for its completion event. A duplicate parent handle then reports position
2. The controller closes that duplicate before checking that a write-open is
blocked, so that check depends on the descendant's retained handle. After Job
termination and zero active processes, the write-open succeeds. Create the test
file with `[IO.File]::WriteAllBytes('bootstrap/out/job-containment-review/candidate-position.bin', [byte[]](88,89))`,
then run `rtk proxy bootstrap/out/job-containment-review/drain.exe candidate-descendant bootstrap/out/job-containment-review/candidate-position.bin`.
That command, `descendant`, `duplex-close-input`, and `leak-control` returned 0
after rebuilding. The earlier empty-file command describes the prior probe
version and is not a valid input for the current mode. This observes one
cooperating descendant and shared file object, not arbitrary tool behavior or
production cleanup.

The separate `late-write.c` controlled descendant now opens its candidate with
append access before signaling readiness and holds that writable handle after
the direct child exits successfully. The controller confirms the prefix is
still unchanged, then attempts a read-only inspection open that withholds write
sharing: Windows returns sharing violation. In the release control, the
descendant appends `-late` before exiting; in the cancellation control, Job
termination leaves the prefix unchanged. Both controls wait for zero active
Job processes, observe the inherited pipe close, compare the complete expected
bytes and remove the test-owned candidate. These commands returned 0:

```powershell
rtk proxy "C:\Program Files\LLVM\bin\clang.exe" --target=x86_64-w64-windows-gnu -std=c17 -Wall -Wextra -Werror -municode compiler/UBE_Compiler_v3/tests/native-executable/job-containment/late-write.c -o bootstrap/out/job-containment-review/late-write.exe
rtk proxy bootstrap/out/job-containment-review/late-write.exe bootstrap/out/job-containment-review/late-retained-success.bin
rtk proxy bootstrap/out/job-containment-review/late-write.exe bootstrap/out/job-containment-review/late-retained-cancel.bin cancel
```

This is one controlled writable file handle on the local host. It does not
establish a production process boundary, protection from writable mappings,
failed termination, or every form of externally retained writer.

The retained `probe.c` now has an `assignment-failure` control. It creates a
marker child suspended, deliberately calls `AssignProcessToJobObject` with an
invalid Job handle, confirms that error, terminates and waits for the child,
and confirms the marker was not signaled. The `assignment-control` assigns and
resumes the same marker child and confirms that it reaches the marker. After
rebuilding with the maintained-source command above, both new modes and the
original two modes returned 0:

```powershell
rtk proxy bootstrap/out/job-containment-review/maintained-probe.exe assignment-failure
rtk proxy bootstrap/out/job-containment-review/maintained-probe.exe assignment-control
rtk proxy bootstrap/out/job-containment-review/maintained-probe.exe child-exits
rtk proxy bootstrap/out/job-containment-review/maintained-probe.exe
```

This forces an invalid-handle failure; it does not reproduce every environmental
Job-assignment failure, confirm injected termination or observation failures,
or exercise the production compiler's tool boundary.
