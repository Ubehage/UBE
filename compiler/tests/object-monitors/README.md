# Class admission and object monitor source gates

The admission gate isolates genuine native `.cls` input and typed class-reference
declarations before construction or locking is involved.

```powershell
rtk proxy powershell -NoProfile -File compiler/tests/object-monitors/admission-check.ps1 -CompilerExe <UBE.exe>
```

It requires successful LLVM emission for an empty class, Option Explicit, the
current package-qualified class name, and use of `Class` as an ordinary variable
name. Repeated package qualification and a module shadowing the package name
must be rejected. It requires controlled, exactly located rejection and unchanged output
sentinels for extension/header mismatches, duplicate class/module identities,
and unsupported fields, methods and lifecycle hooks. Emission is admission
evidence only; this gate does not claim execution or monitor cleanup coverage.

`-ReferencedPackages` additionally enables the imported-package class case when
that admission dependency is implemented. It is not part of the default gate.

`-AdmissionBaseline` instead requires the frozen counted compiler to reject a
genuine `.cls` at `Probe.UBE:5:1` with E_LOAD while preserving the output sentinel.
That baseline passed before class implementation, and the reusable baseline gate
passed with the frozen compiler in temporary evidence directory
`ube class admission 39d24e00-0a90-4668-8960-9705a3ed8410`.

All 13 default admission checks passed with the frozen compiler package
`ube loop dependencies compiler 934baae7-b163-4a48-a77c-febfa45bdcb2`:

```powershell
rtk proxy powershell -NoProfile -File compiler/tests/object-monitors/admission-check.ps1 -CompilerExe "$env:TEMP\ube loop dependencies compiler 934baae7-b163-4a48-a77c-febfa45bdcb2\UBE.exe"
```

Evidence is under `%TEMP%/ube class admission 54249d09-6d54-4fb7-a372-d85d41ec5778`.
Invalid qualified type names are located at the declaration name (`4:5`),
matching the parser's variable-node span. Duplicate module identities require
`E_LOAD`, operation/code/reason `8/3/1`, at the source start (`1:1`). The optional
referenced-package case is excluded from this passing result. These checks do
not establish native construction, locking or cleanup behavior.

The construct diagnostics gate checks the related For Each/SyncLock grammar and
binding failures:

```powershell
rtk proxy powershell -NoProfile -File compiler/tests/loop-control/construct-diagnostics.ps1 -CompilerExe "$env:TEMP\ube loop dependencies compiler d6c55de7-ddcd-40f9-9101-019142785421\UBE.exe"
```

All seven cases passed: a scalar For Each counter, mismatched Next variable, a Next
list crossing a SyncLock boundary, an incorrect lock terminator, Exit Loop inside
a lock without an enclosing loop, a scalar lock target, and Exit Loop after a
completed For Each while its enclosing SyncLock is still active. Each case requires
exactly located rejection in both emit and build modes, unchanged output
sentinels, successful emission after correcting the invalid construct, identical
recovery LLVM hashes, and no leaked publication stages. Evidence is under
`%TEMP%/ube construct diagnostics ac95cc72-a9c7-4053-ae67-db1e17972db0`.
This gate performs no native execution and does not establish runtime locking
or enumeration semantics.

Run the source execution fixtures with an integrated compiler:

```powershell
rtk proxy powershell -NoProfile -File compiler/tests/object-monitors/reference-check.ps1 -CompilerExe <UBE.exe>
rtk proxy powershell -NoProfile -File compiler/tests/object-monitors/lock-check.ps1 -CompilerExe <UBE.exe>
```

Both require O0/O2 execution results and changed-expectation negative controls.
Reference cases cover genuine construction, aliases, Nothing, ByVal/ByRef,
recursive returns and failed assignments. Lock cases cover mixed loops, exited
and enclosing monitors, reentrancy, evaluated-once targets, target reassignment,
collection with waiting workers, procedure/GoTo/named-loop exits, default failed
headers, inside/outside handlers and Err preservation. Native processes and
worker completion are bounded; process exit codes must be present and stderr
empty.

Worker entry flags and zero-time waits alone do not prove that a worker reached
monitor contention before a check. Their phase observations supplement the
native busy-state gate. The successful positive lock runs emit LLVM inputs for
the deterministic cleanup observer:

```powershell
rtk proxy powershell -NoProfile -File compiler/tests/object-monitors/cleanup-check.ps1 -ProgramIR <locks-positive.ll>
```

That observer wraps the actual allocation, acquisition and retirement functions
without replacing their results. It tracks the first six constructed identities
and the main thread, observes actual worker busy outcomes through bounded safe
handshakes, and checks retirement depth/count and source continuation markers.
This distinguishes retained outer locks, handler-local ownership, failed-header
cleanup and caller locks across recursive invocations. It checks the recursive
release depths `5,4,4,3,3,2,1`, preserving the caller until its own block ends.
Changed final release-count expectations form its negative control. The source
fixtures and this observer must be updated together when construction order or
the deliberately marked control-flow assertions change.

The hardened source reference and lock gates each passed six native runs at
O0/O2: positive exit 0, changed-expectation exit 1, and an escaping helper-FAIL
control exit 90. They used the frozen compiler in
`ube loop dependencies compiler d6c55de7-ddcd-40f9-9101-019142785421`.
Temporary evidence directories are
`ube object references 923d86a6-9917-4e9f-8004-4b6750e5eb63` and
`ube object references 5741bf8b-836e-45a0-9551-7336a564f9d0` respectively.
All 13 default admission checks also passed with that compiler; evidence is
`ube class admission b254967b-6c40-4ff5-a8b7-875969033a1b`.

The cleanup observer passed at O0/O2 with positive exit 0 and negative exit 99;
its evidence is `ube source monitor oracle a13f3d93-2eca-4919-9131-d1c1be11be85`.
The O0/O2 source-emitted lock LLVM files were byte-identical (SHA-256
`0CA6711AE7430943342EB4988D9D2265C57957F75D60E7490D58E2EB03EA9362`), and
the observer compiled that input under both native optimization levels.

These results supersede the initial runs made before hardening. Source entry
points route unexpected FAIL to failure exit 90, helper results use explicit
False staging and separate assertions, and waits use sentinel staging even
inside active handlers. The escaping helper-FAIL control produced exit 90 at
both optimization levels. This prevents default failed-If continuation from
hiding a failed test. The lock fixture also covers direct Err.Raise in the
owning locked procedure, which bypasses its own handler and releases its monitor
before a caller handles the failure.

Generated cleanup failure routing has a separate synthetic gate:

```powershell
rtk proxy powershell -NoProfile -File compiler/tests/object-monitors/retirement-check.ps1 -CompilerExe <UBE.exe>
```

The injected helper performs the real release first, then restores only the
cleanup metadata slots and returns FAIL with Err 5. This avoids an artificial
lock leak while exercising the compiler failure path. Both ordinary End SyncLock
and Exit Function from a held lock must bypass the callee handler, return FAIL
to its caller without changing the destination value, preserve Err 5, perform
exactly one terminal root cleanup, and never retry an acquired release. The
caller must subsequently acquire the same real monitor successfully.

All eight runs passed with the same frozen compiler: two source paths, O0/O2,
positive exit 0 and changed-terminal-count exit 99. Source evidence is
`ube retirement failure cc03b98f-3d4d-4e4d-8131-aff4e58e6f4a`; native evidence
is `ube source monitor oracle f064c90e-34b2-422f-a5b4-57d1122b7241` for statement
cleanup and `ube source monitor oracle 8a7dd19d-f6c6-405c-8417-ff0ff3f8275d` for
return cleanup. No production correction was needed for these assertions.

These gates cover the admitted empty-class/object-monitor dependency. They do
not establish class methods, user lifecycle hooks, forms/controls or unload.

The new NativeObjects module is included in the self-host source package.
`rtk proxy powershell -NoProfile -File bootstrap/tests/self-hosting/package-check.ps1`
passed all 340 packaging assertions after the source edits were stable; evidence
is `ube self-host sources 66079ee6-81bb-4a65-a1f2-741324b1e083`. This is source
packaging verification, not an executable self-hosting claim.
