# UBE native lowering acceptance

## Complete source-to-native qualification

```powershell
rtk proxy powershell -NoProfile -File bootstrap/tests/native-lowering/check.ps1 -BootstrapExe <bootstrap-executable>
```

The bootstrap builds the actual UBE compiler modules and a test driver. That
native driver reads original source files at runtime, appends their scanner/parser
results to `ProjectSyntax`, and invokes `NativeLowering.TryEmit`. The latter
rebuilds declaration, expression, primitive, aggregate and native planning facts
before writing a complete LLVM module to the caller's private file. The test
closes the file and compiles it with Clang/lld. No host-emitted user procedure
bodies are inserted into this output.

At O0 and O2, the generated program runs 24 source-level checks covering
integer arithmetic/conversions/ByRef behavior, finite records and indexed arrays,
independent copies, ByVal record/array snapshots before later arguments,
original-payload aliases during resize, cleanup, counted byte
operations, conditional/loop failure behavior, and source worker ownership. The
worker checks include creator-return aliases, record/array value snapshots,
grouped temporaries, per-thread failure delivery, ignored/nested workers and
the 64-live-worker admission bound. The generated program then performs the existing
256-byte file roundtrip check; the runner independently compares the file with
bytes 0 through 255. Each result must be freshly successful, context disposal must
succeed, and the program must return zero. The harness publishes the root outcome
and drains workers before disposal. Changing a volatile runtime seed from
1 to 2 must produce exact assertion exit 101 at both optimization levels.

A separate fully generated executable checks forward module-initializer
dependencies and one-time initialization, a recoverable failing initializer
followed by successful initialization, real Main result transport, recursion depth
refusal with Err 28, and successful recursion after unwinding. Its exact native
exit is 42. Both projects must produce identical LLVM bytes when the UBE emitter
itself runs at O0 and O2, and generated source-location comments are required.

Finally, the actual compiler and portable library source bodies are themselves
lowered by UBE, then compiled into native objects at O0 and O2. Undefined symbols
must be only the 42 explicit reviewed Windows memory/file/system/path/process/namespace/thread API imports. This rejects hidden
`__chkstk`, `memcpy`, `memmove`, `memset`, or other unavailable helpers. Object
compilation verifies complete LLVM/code generation for those bodies; it does not
claim the resulting compiler object was used to bootstrap a further executable.

The complete compiler-source driver has a 120-second deadline: this unoptimized
driver measured 63.68 seconds after the ownership analysis was integrated. Other
source-emission drivers retain their 60-second deadline. This is a test-runner
allowance and does not change a compiler/runtime capacity or source-language limit.

The same command also runs the source worker capture allocation matrix on
UBE-emitted IR: both target attempts fail at each observed allocation site,
native startup fails independently, and every failure is followed by successful
recovery with zero live allocations after disposal. Use `-CallNewOnly` for these
fixtures and source ownership negative controls without the other integration
cases. Use `-ResourceConcurrencyOnly` for the separate eight-worker shared file
registry gate. Both selectors use the same actual UBE emission driver and pass
its bound entry identity explicitly to their native observation harnesses.

Template and runtime assets are copied alongside the compiler fixture snapshot
before driver compilation, so later workspace regeneration cannot silently mix
the driver's validated catalog with different emission assets.

The 170-template ownership snapshot completed the entire command with evidence
`ube native lowering 2e395f76-a7d8-4e9c-9ccc-0afc04a87e14` under the system temporary
directory. Both compiler objects passed the helper/import oracle. Its capture
matrix covered 11 allocation sites, and its final UBE-emitted dynamic-storage
segment passed 54 groups with evidence
`ube dynamic storage 09b1c4a0-e342-458a-a96d-ffa45c9e63a8`. The host executable was
`ube native workers 6e56a4fa-607e-4158-bbb8-444bb4d39224/UBE-Bootstrap.exe` under the
same temporary directory. This result came from one complete gate invocation.

The same gate lowers the dynamic-storage corpus with UBE and reuses its allocator
observer at O0 and O2. Procedure identities are mapped by unique source locations
from the identical source corpus. This checks ByVal snapshot ownership after
allocation failures, later-argument failure and callee depth refusal, including
exact allocation-attempt counts and zero live blocks after disposal.

The ByVal prerequisite qualification on 2026-11-13 retained the then-current
124914-byte runtime and compiler sources in `ube-byval-qualification`, while
thread-runtime integration continued separately. Its focused `byval-check.ps1`
passed the full-profile/changed-input comparisons, both compiler object/import
checks and all 54 native ownership groups. Evidence is in
`ube native lowering ae4f9742-f803-4bfe-b7aa-5b15fd1c093c` and
`ube dynamic storage db1c4c31-fb06-4db7-acc5-fbd863c3638f`.
The unchanged ownership corpus produced exactly the same 671962 LLVM bytes
before and after extracting assignment emission from statement dispatch.
This focused extraction reduced the measured O0 statement frame from 4232 bytes
to 2184 bytes, with a 2456-byte assignment helper, avoiding `__chkstk` without
changing the 128-cell source-frame limit.

The unchanged generated bridge deliberately contains hundreds of argument
preparations and scalar assignments. It retains the regression that originally
required an unavailable O0 stack probe: pure checked constant arguments now
materialize after module ensuring, while direct local scalar assignment addresses
materialize after the RHS. Indexed/global/aggregate address evaluation keeps its
original ordering. The test does not supply a stack-probe shim or split away that
regression.

Every child has a deadline, native executables must have AMD64 PE headers, and
process outputs, source inputs, complete LLVM, objects, and executables remain in
the printed temporary evidence directory. These are private staging files; public
destination publication remains a separate driver/backend responsibility.

Final main-gate evidence (2026-11-13):

```powershell
rtk proxy powershell -NoProfile -File bootstrap/tests/native-lowering/check.ps1 -BootstrapExe "C:\Users\Ubehage\AppData\Local\Temp\ube emission scopes 6d5a8c9e-4fb3-4bfd-9f36-88882244ddca\build\UBE-Bootstrap.exe"
```

Passed both generated-program executions, both exact changed-input controls,
both executable entry/initialization/depth checks, deterministic text and exact
source-coordinate assertions, and both actual-compiler object/undefined-symbol
checks. Evidence is retained at
`C:\Users\Ubehage\AppData\Local\Temp\ube native lowering 2f0ff2cf-a03a-4576-83af-0bdf3d39cc10`.

## Failure and ownership qualification

Run the companion gate with the same bootstrap used for the main integration
gate:

```powershell
rtk proxy powershell -NoProfile -File bootstrap/tests/native-lowering/allocation-check.ps1 -BootstrapExe <bootstrap-executable>
rtk proxy powershell -NoProfile -File bootstrap/tests/native-lowering/allocation-check.ps1 -BootstrapExe <bootstrap-executable> -CallNew
```

This compiles the actual complete UBE lowering pipeline, then supplies runtime
source bytes containing scalar arguments, a grouped ByRef call, finite records,
record assignment and equality. Source pools and installation assets are prepared
before fault injection. The caller opens each private staging token before the
observed emission, and closes it explicitly after success or failure.

The runner measures the allocation count for its exact source snapshot.
Every observed allocation site and its one retry are failed at both O0 and O2.
The rejected operation must return False with latched failure and a fresh
diagnostic, retain only the pre-existing owners, and permit a new stage to emit
successfully. Each recovered file must have exactly the baseline SHA-256 hash.
Both complete baseline LLVM files are independently compiled by Clang, and their
hashes must agree across optimization levels. Only named target allocator/release
definitions are instrumented; frontend and emission functions remain unchanged.

Additional cases corrupt a token span, root parent link, node count, template
catalog and runtime text separately. Seeded stale diagnostic fields must not
survive rejection. Named target write and flush wrappers inject real staging
I/O failures; FileFailure and Err are asserted separately, then a fresh stage
must recover with the baseline bytes. Depth probes use 0, 192, 224, 240, 248,
252, 254, 255 and 256 active frames. They distinguish refusal before the public
boundary is entered from a controlled diagnostic after entry. Caller close and
context disposal must leave zero observed live allocations in every case.

The earlier sequential snapshot passed 160 cases plus two baseline measurements:
128 allocation cases, ten malformed-input cases, four I/O cases and eighteen
depth cases. Evidence is `ube lowering failures
2adbba20-0fae-4f23-b5c6-4c5cb1e7ae0b` under the system temporary directory, using
the bootstrap in `ube emission scopes
6d5a8c9e-4fb3-4bfd-9f36-88882244ddca/build`. This includes the target header,
constant-conversion, shared initializer lookup and operand/address scheduling changes, with the final
114-entry, 15,641-byte catalog.

With escape analysis integrated, the ordinary fixture passes all 70 observed
allocation sites at O0/O2, alongside the same malformed-input, I/O, depth and
recovery checks. Evidence is `ube lowering failures
4909a005-0893-4fd2-85db-5989798b19f5` under the system temporary directory.

`-CallNew` adds source that requires local boxes, hidden owner arguments,
ByVal record/array snapshots, indexed fixed-array capture, grouped temporaries
and nested worker entry thunks. Its faults occur while the UBE compiler emits
that source; runtime capture-allocation faults are separately exercised by
`runtime/tests/callnew/check.ps1`. The compiler-side variant compares every
recovered output against its own complete baseline and requires zero live
allocations at disposal. It does not execute the emitted worker procedures.
This variant passed all 97 observed allocation sites at both O0/O2, plus
malformed-input, I/O and depth checks, with evidence `ube lowering failures
836f3156-cb37-4ab7-9800-856d3c3b0698` under the system temporary directory.

After the pending-retirement runtime change, both commands above passed again
with the freshly built bootstrap in `ube native context
49f0f01f-46f9-41d6-ae3e-610eb5293a0e/build`: all 70 ordinary and all 97 CallNew
allocation sites at O0/O2, plus the malformed-input, I/O, depth, exact recovery
and zero-live-allocation checks. Evidence is `ube lowering failures
0e2c3775-4d7d-4873-830d-4c15f4143cdb` (ordinary) and `ube lowering failures
66358234-312f-4152-bbfb-3e00d4e83708` (CallNew). Both used the 150717-byte runtime
and 170-template, 23451-byte catalog with exact source parity.

With program-owned descriptor stripes integrated, the same ordinary and
CallNew allocation commands passed all 70/97 sites and every malformed-input,
I/O, depth, recovery and cleanup check again at O0/O2. They used the bootstrap
in `ube native context 5b726a73-2fe7-48a4-865b-887e684959b6/build`, runtime
152116 bytes and 170 templates totaling 23487 bytes. Evidence: `ube lowering
failures 1d56a573-1fed-4637-ab71-09299d2c5ea5` (ordinary) and `ube lowering
failures 442c13c5-eb21-4444-9068-674d7065d5de` (CallNew).

These counts cover observed allocations in the stated fixture, not every
possible path through every compiler construct. Failed private stages may
contain accepted prefixes and are never treated as completed output. The gate
does not claim atomic publication or preservation of a public destination;
that remains the driver/backend's responsibility. All child processes have
bounded deadlines, and generated files and process diagnostics are retained.

Additional executable fixtures bind and emit the metadata, namespace and process
roles through UBE. Metadata compares hardlink identity, file lengths, exact
executable spelling and changed file input. Namespace operations exercise
exclusive creation, explicit absence and replacement preservation. Actual native
children exercise process start, wait, exit status, termination, close and
foreign-owner/alias refusal at O0/O2. These fixtures supplement the injected
target fault gates; they do not replace them.
