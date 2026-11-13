# Ordinary UBE backend gate

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File bootstrap/tests/native-backend-ube/check.ps1 -BootstrapExe <fresh UBE-Bootstrap.exe>
```

The gate compiles the actual `NativeBackend`, `CompilerAssets`, `CompilerMessages` and their ordinary library dependencies at O0 and O2. All tools run directly with literal arguments, never through a command shell. Private stages and evidence remain in a unique test directory.

Each optimization level checks twelve compound source probes and three missing-asset cases:

- Actual llvm-dlltool and Clang build a private AMD64 executable from LLVM; independently running it must return 42.
- Native tools returning zero, returning 29, writing 65537 log bytes, and remaining active exercise success, nonzero exit, log-limit detection, and the 30000ms deadline. Only the monotonic clock target is accelerated for the deadline test.
- Independently compiled fake tools produce an invalid archive, no executable, or an invalid PE. Exact expected failures are 103, 3, and 16.
- Denied process closes return both retained owners while preserving timeout failure 100 and Err 57. Removing the fault allows explicit cleanup to release both owners without replacing the primary diagnostic.
- Asset sentinel bytes are loaded beside the actual probe executable while its working directory is elsewhere. Each of the three absent support files produces failure 3, Err 57, and no retained file owner.
- Standard output must be exactly `EMIT OK\r\nBUILD OK\r\n`. Standard error must match the independently written located compile diagnostic, including operation/code/reason values, path, line, column and CRLF.

Every probe checks explicit return status and ownership; context disposal must succeed. The log policy detects oversize output and is not a hard write cap. This gate tests private native building, not final output publication or complete compiler self-hosting.
