# Ordinary UBE backend gate

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File bootstrap/tests/native-backend-ube/check.ps1 -BootstrapExe <fresh UBE-Bootstrap.exe>
```

The gate compiles the actual `NativeBackend`, `CompilerAssets`, `CompilerMessages` and their ordinary library dependencies at O0 and O2. All tools run directly with literal arguments, never through a command shell. Private stages and evidence remain in a unique test directory.

Each optimization level checks thirteen compound source probes, a restored-deadline negative control and three missing-asset cases:

- Actual llvm-dlltool and Clang build a private AMD64 executable from LLVM; independently running it must return 42.
- Native tools returning zero, returning 29, writing 65537 log bytes, and remaining active exercise success, nonzero exit, log-limit detection, and the 60000ms deadline. Only the monotonic clock target is accelerated for the deadline test.
- A real zero-exit child completes at logical 40000ms: the injected clock advances once and then stays fixed, avoiding a scheduling race. It succeeds with released file/process owners under the current deadline. A separately emitted private copy of the actual backend source with the former 30000ms deadline rejects that same observation with failure 100 (probe exit 1100). The active-child timeout and retained-close tests reach logical 60000ms exactly.
- Independently compiled fake tools produce an invalid archive, no executable, or an invalid PE. Exact expected failures are 103, 3, and 16.
- Denied process closes return both retained owners while preserving timeout failure 100 and Err 57. Removing the fault allows explicit cleanup to release both owners without replacing the primary diagnostic.
- Asset sentinel bytes are loaded beside the actual probe executable while its working directory is elsewhere. Each of the three absent support files produces failure 3, Err 57, and no retained file owner.
- Standard output must be exactly `EMIT OK\r\nBUILD OK\r\n`. Standard error must match the independently written located compile diagnostic, including operation/code/reason values, path, line, column and CRLF.

Every probe checks explicit return status and ownership; context disposal must succeed. The log policy detects oversize output and is not a hard write cap. This gate tests private native building, not final output publication or complete compiler self-hosting.

The expanded gate passed at O0/O2 on 2026-11-27 using the e0874b0b seed:

```powershell
rtk proxy powershell -NoProfile -File bootstrap/tests/native-backend-ube/check.ps1 -BootstrapExe "C:/Users/Ubehage/AppData/Local/Temp/ube escape capacity e0874b0b-5f73-44cd-8072-0af838a0162f/seed/UBE-Bootstrap.exe"
```

Evidence: `%TEMP%/ube native backend e1b3de98-5484-4f3b-bf7f-630c762d8d1b`.
Both levels passed all thirteen probes, three missing-asset cases and the
restored-30-second negative control. The gate snapshots the current ordinary
backend source; this is not a claim that the seed implements that policy.
The fixture includes the loader's ManagedSourceAssets dependency and seeds its
shared import archive from the complete emitted runtime before smaller native
writer tools reuse it.
