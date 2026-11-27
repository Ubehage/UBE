# IDE execution-context gates

The accepted language and launch boundary is documented in
[IDE-CONTEXT.md](../../IDE-CONTEXT.md). These are repository-owned acceptance
fixtures, not a finished IDE or debugger.

Run the actual Windows host/session gate with a qualified compiler:

```powershell
rtk proxy powershell -NoProfile -File compiler/tests/ide-context/session-check.ps1 -CompilerExe <UBE.exe>
```

`-HostOnly` checks the host fixture independently. `SessionHost.cs` is compiled
with the installed .NET C# compiler through Windows PowerShell; no third-party
host dependency is installed. Its child starts atomically in a named job, with
only standard-I/O handles inherited and a private Unicode environment block.
The host retains the non-inheritable job handle until the run ends. Source and
host artifacts, process output, compiler identity and `report.json` remain in a
fresh `%TEMP%\ube ide session ...` directory.

The complete gate has 35 checks: three host controls, then 16 checks at each of
O0 and O2. It builds separate standalone and IDE artifacts and checks ordinary
and conditional `IS_IN_IDE`, source initialization, wrong-value and escaping-FAIL
controls, and exact exit125/diagnostic rejection for direct, missing, malformed,
stale, unrelated-job and wrong-job-flags launches. Lowercase and uppercase hex
session names are exercised. The initializer writes exactly one byte42; invalid
launches must leave that sentinel absent.

The debug fixture creates the child suspended. The supervising test checks that
the child is alive and the initializer sentinel absent before signaling resume;
the host retains the session while the resumed program succeeds. Closing the
session before resume must terminate the child without source initialization and
produce an explicit host status. Killing the host while paused or while source
is running must terminate its child within the bounded wait. Readiness signals
and observed process completion establish these facts; elapsed time is only a
deadline. This uses process suspension, not a claim of Windows debugger support.

The generated initializer's path-byte assignments are split into helpers of at
most24 stores. The initial unsplit test produced a7448-byte O0 frame requiring
`__chkstk`; the fixture was corrected without changing production lowering or
suppressing stack checks. The source still writes and verifies the same path and
sentinel. The host publishes its ready PID through an atomic file rename.

`SessionHost.exe` takes six arguments: target, environment mode, lifetime mode,
child stdout path, child stderr path, ready-file path. Environment modes are
`valid`, `uppercase`, `missing`, `malformed`, `stale`, `unrelated`, `wrongflags`,
and `collision`. Lifetime modes are `normal`, `paused`, `running`, `debug`, and
`suspend-close`; `debug` waits for `<ready-file>.resume`. All waits are bounded.

`loading-check.ps1`, `binding-check.ps1` and `admission-check.ps1` separately
exercise frontend context propagation and admission. Runtime fault injection is
covered by the runtime guard's focused gate; this session gate uses real Windows
jobs and processes. Neither gate substitutes for final compiler self-build,
conformance or compiler-concurrency qualification.

The complete gate passed35 checks with the qualified generation-2 compiler at
`%TEMP%\ube compiler rebuild 5c66c361-60ad-4cae-9670-1c1ab27e8e10\generation-2\UBE.exe`,
SHA256 `3BB5B9E82A39BBEC607F5ED07926FF3B8E30A3B54EA03CD129FAD8E52D492116`.
Run the command above with that path. Evidence is retained at
`%TEMP%\ube ide session 619cd81c-46a9-4a8a-91a5-d36c1392bd57`, including the host
hash, all case outcomes and exact child output. Earlier candidate runs are
superseded by this qualified-compiler result.
