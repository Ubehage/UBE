# Native program and process entry

This implements the existing First checked native executable startup boundary.
The checked adapter borrows the catalog and prepared declaration plan. It uses
the existing package-boundary validation once, imports the selected parameterless
root Main in one charged declaration visit, and emits the normal initialization
schedule once. No body rescan, owned scratch, copied input or new worker exists.
Source validation/order costs 2*M visits; Main's single startup import visit
uses the approved I allowance. Fixed support identities and output bytes remain charged.

The common output defines `ube.program.run`, which establishes startup safety,
initializes modules and admits/calls Main. A separate ordinary process adapter
defines `main`, returning that signed i32 result. The test adapter replaces only
the latter object and immediately reads same-thread Err after the same common
program entry returns. Neither adapter contains language initialization policy.

Before initialization, program entry reads its actual stack pointer and the
first initializer's complete footprint. Private platform support
`ube.stack.initialize(i64 stackPointer, i64 firstFootprint) -> i1` must query the
contiguous committed writable interval, validate reserve/first-entry capacity
using checked subtraction, and publish the TLS floor only after success. Query
failure or insufficient initial capacity returns false without setting Err.
The generated program returns 1 immediately on false, with no user code entered.
The startup support's own pre-invariant closure requires separate host and
machine-code qualification; this interface alone does not establish its safety.

After successful setup, the existing always-inline initialization schedule and
requirement helper execute dependency sources before root sources. Failure to
complete initialization returns 1. A subsequent safely refused Main call records
Err 28, skips Main, and returns zero. Admitted Sub Main returns zero; Function
Main returns its full signed Long value. Success never clears existing Err.

All output belongs to the caller's private current-unit writer and remains
disposable on any emission failure. Source, declaration and package identities
remain immutable. The scalar emitter validates dimensions before output; the
checked adapter additionally validates selected Main kind/type, no parameters,
root-module ownership and ordinary frame identity. Numeric caps are unchanged.

The platform implementation, complete object/frame/reserve binding, actual
platform wait and native builder remain required work. Controlled test support
must be identified as such and must not be presented as platform qualification.

## Focused entry qualification — 2026-11-03

Command:

```powershell
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/initialization/check.ps1 -DiagnosticOnly
```

Report ../../bootstrap/out/native-initialization/19d3709230a240c388e6dd12d886489f/report.json
passes 224 groups and 642 commands in 171,108 ms. Both stages pass 2,097,584
emission assertions. The focused component uses the exact scalar emitter and
shared schedule/require/stack support, with controlled setup and C initializers
and Main. It excludes only the checked catalog adapters, which are tested in
the whole-project gate. Sub/Function Main, root-only and dependency-first order,
O0/O2, setup refusal, initializer refusal, Main refusal and recoverable initializer
error all pass through ordinary and observed adapters sharing identical entry
code. The signed process result -2147483601 is preserved. Exact/below caps,
allocation/cancellation cleanup, invalid dimensions, target-identity inventories
and required helper inlining are checked. Five adverse controls detect bypassed
setup/initialization/Main admission, skipped initialization and missing Err 28.

The first retained attempt b51f38076c7f49a2b277c7e3b5df6d55 failed in test-adapter
construction: its unrestricted Main-name replacement also rewrote the compiler's
new emitted-text string constant without adjusting that constant's length.
Anchoring replacement to LLVM function-definition lines fixes this test defect;
production source was unchanged by that correction. The same focused correction
is applied to other complete-compiler test adapters that encounter this literal.
The complete refreshed bootstrap/semantic/warning gates remain pending.

This proves entry behavior with controlled platform support, not the Windows
page query, actual initial committed capacity or startup support's machine-code
closure. The completed checked-project qualification is recorded below.

The first checked-project attempt,
../../bootstrap/out/native-graph/1b8c851184f644eba8ae62b82653c799/report.json,
completed first-stage compiler emission but rejected the new Main-refusal oracle.
Its expected Calls=0 was incorrect: B.ReadValue increments Calls during required
initialization, so refusal of Main must preserve Calls=1. The checked fixture now
also increments A.Events only on Main entry; the observer checks Events=0 on
refusal and Events=1 on normal entry. No production change was needed.

Focused regeneration through that retained first-stage adapter passes 39 groups
and 137 commands in 24,437 ms:
../../bootstrap/out/native-entry-diagnostic/61f6f4a8bb624b13894fe37f64e250f7/report.json.
Command: rtk proxy powershell -NoProfile -File
bootstrap/out/native-entry-diagnostic/61f6f4a8bb624b13894fe37f64e250f7/check.ps1.

The maintained graph runner now permits explicit reuse of a completed raw
compilation, independently of whether subsequent tests passed. It checks the
prior successful compiler command, exact raw bytes, bootstrap tool/manifest
identities and every copied compiler/Core input against the new fixture before
reuse. Every current native oracle is rebuilt and rerun. This is test-cohort
provenance only; production UBE still does not monitor or retry source edits.
Two altered-report controls reject mismatched raw and source identities:
../../bootstrap/out/native-entry-reuse-controls/ce8d262c5177409192bee431aab753f4/report.json.
Both controls passed using that directory's check.ps1. The rerun reuses only the
completed first-stage raw output and compiles the other bootstrap stage normally.

## Next platform implementation constraints

The selected startup support will obtain the allocation containing the supplied
actual stack pointer, then inspect reported regions up to that pointer, retaining
only the final contiguous committed writable suffix. Validate returned byte
count, ownership, containment, overflow and strict address progress before using
a region. This avoids assuming a fixed page size or treating reserved stack
address space as committed capacity. Query behavior is specified by Microsoft's
[VirtualQuery documentation](https://learn.microsoft.com/en-us/windows/win32/api/memoryapi/nf-memoryapi-virtualquery).

Only read protection fields after checking committed state: Protect is undefined
for reserved pages, and allocation/protection/type fields are undefined for free
pages. Verify the selected target's structure size and field offsets against its
headers before emitting those accesses. See
[MEMORY_BASIC_INFORMATION](https://learn.microsoft.com/en-us/windows/win32/api/winnt/ns-winnt-memory_basic_information).
Exclude guards, inaccessible pages and copy-on-write mappings that could require
a new private page on a subsequent write; the ordinary native stack must remain
in its private allocation. The
[protection constants](https://learn.microsoft.com/en-us/windows/win32/memory/memory-protection-constants)
document those distinctions. Publish the TLS floor only after the complete scan
and checked reserve/first-footprint comparison succeed. The OS-query closure and
continued stack lifetime still require the host/machine-code gates in the stack
review; none is established merely by these API definitions.

## Completed checked-project entry qualification

Exact commands:

```powershell
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/graph/check.ps1 -DiagnosticOnly -ReuseCompilationReport bootstrap/out/native-graph/1b8c851184f644eba8ae62b82653c799/report.json
rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/resources/import-work/check-emission.ps1 -ReportPath bootstrap/out/native-graph/b876b8cda4074d529bae08d26cc66f3b/report.json
rtk proxy git -c core.safecrlf=false diff --check
```

Report ../../bootstrap/out/native-graph/b876b8cda4074d529bae08d26cc66f3b/report.json
passes 194 groups and 509 current commands in 384,628 ms. Its retained successful
first-stage compiler invocation took 690,496 ms; only that raw compilation was
reused after the strict checks above. Both bootstrap stages pass 971 graph and
2,108,517 body assertions. Their raw LLVM is identical: 7,956,169 bytes, SHA-256
83B7E8EC916043415DED725F426B3F4689048F428C4F313C0E7F59B06626A398.

Checked single-package and referenced-library projects select the actual root
Main and first initializer. Bad selected kind/type/role/parameters/source/scope/
frame/identity and out-of-range entry identities return controlled 1509 before
output. Accepted entry uses 2*M+1 work and 86 fixed/support identities for the
three-source Function case; no body or declaration scan is added. Jobs 1/2/4
preserve output bytes/work/identities. Separate common entry and user module
objects link with either the ordinary generated process adapter or the private
same-thread observer. O0/O2 checks cover setup failure before user code, required
initializer failure, refused Main, actual Main side effects and exact result/Err/
revision. Normal result is 129, startup/initialization failure is 1, and safe
Main refusal is 0 with Err 28. Platform setup/frame metadata remain controlled.

Source identities:

| Source | Bytes | SHA-256 |
| --- | ---: | --- |
| NativeEntry.bas | 8577 | 0E0159F0DD5ED50581F0C43FDF828B0EF00B9BD68D6F84BAE18883DD84EB0309 |
| NativeCalls.bas | 6559 | AED2B870CB499347FEE3E2A9AD5F67F3D321D51660431AA75DED3BDB8EB8F56F |
| NativeInitialization.bas | 17796 | EEC92A0B8D277FF26ADCAB794FFB2FCB72712790BBC9E3A7F1334B789EAD78F8 |

The common checked entry outputs are each 4,376 bytes. Root-only SHA-256 is
CFDB341D2D6FC75235A194EAECA63766C5CA3E5DA54A430EB1677D13108E6FD3;
direct-reference SHA-256 is
A365C2BA272C28E4D417CA0F36BBFB63583405BBDAA8819E0F707195867D20FD.
The ordinary process adapter is 160 bytes with SHA-256
B87A2EEAE5BB45A1943A71AFF147E5E4AE2C97F447D1B68AD00541811342F277.
The focused two-stage raw images are also identical, 915,906 bytes with SHA-256
F5C44DF6EB05AB2A119A9A1A42633FCDE22BDEE062DFBC67CEC900485A65F01C.

The retained import-work gate passes six groups and 56 commands in
../../bootstrap/out/native-import-emission/6660a403ad7944f681f520bb041642f1/report.json.
It preserves the exact 2,925-visit total, 126 own plus 210 import visits, cap
boundaries, immutable inputs, cleanup and eleven-object O0/O2 native result.
All handles are terminal. Runner syntax and diff whitespace checks pass. The
full refreshed source-built bootstrap and affected semantic/warning adapters
remain to be exercised together; the native builder is not qualified.

Next implement actual Windows stack initialization behind the selected private
setup signature, then qualify its query/initial-capacity failure behavior and
startup closure. Complete linked frame/reserve binding, fatal and wait support,
warning delivery and tool/debug/publication integration remain in the active goal.

The subsequent Windows setup/fatal/wait implementation and actual-platform
entry tests are recorded in NATIVE-PLATFORM-IMPLEMENTATION.md. That checkpoint
supersedes the implementation-next-step statement above; complete linked
frame/reserve and startup/API safety qualification remain pending.
