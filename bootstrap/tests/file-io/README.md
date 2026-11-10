# Counted file-I/O acceptance gate

Run from the repository root:

```powershell
rtk proxy powershell -NoProfile -ExecutionPolicy Bypass -File bootstrap/tests/file-io/check.ps1
```

`-BootstrapExe` selects an existing VB6-built compiler. The runner retains
manifests, LLVM, native executables, real files and child-process output in its
printed temporary directory. All child processes have deadlines.

All 56 groups passed on 2026-11-10 against the VB6-built executable in
`ube project loading 65843f86-7ee9-407b-8748-8d5ad6d40320/build`.
Final retained evidence: `ube file io 71990967-6774-46fe-a1a5-56978319903d`.

Actual portable FilePrimitives and FileBytes source executes at O0 and O2 using
the same emitted IR with volatile runtime inputs. Independent host byte reads
compare output against exact expected sequences. A separate `--build` executable
exercises production imports, entry and disposal; rerunning it must reject
exclusive creation without changing the existing file.

Coverage includes empty files, all 256 byte values, full 4096-byte files,
supplementary Unicode UTF-8 paths, nonzero bounds, partial reads/writes, EOF,
zero progress, malformed paths, invalid ranges and both wrong access modes.
Success preserves Err and refreshes Failure. Primitive False remains usable
inside an enabled handler. Failed reads leave every destination byte unchanged
even after the target writes into its private scratch.

Ordinary source policy rejects premature EOF and growth, closes before result
publication, and preserves the old result on failure. Failed result-buffer
allocation records Err 7; failed cleanup close then records Err 57. The helper
must restore primary Failure 8/Err 7 and retain the live token. A source caller
retries close before raising. Failed close after rejected open also returns
ownership, and a successful retry clears it.

Each scenario requires zero observed allocations and handles after explicit
close and disposal. Disposal with live files must fail without closing them.
Two contexts receive different tokens and reject each other's identities.
The 64-owner registry is exhausted without an extra OS open, then released and
reused with fresh tokens. Internal harness calls check scalar outputs overlapping
array descriptors/payloads: invalid aliases cannot alter storage or lose owners.

Test-only wrappers rename named target definitions in a copy of emitted LLVM,
delegating successful operations to their real OS implementations. They control
short transfers, failed reads after progress, partial failed writes, zero writes,
size-query changes, allocation retry/exhaustion, flush and close failure.
No production flags or replacement source procedure bodies are used.

Counters immediately after the three unique volatile movement stores measure
executed path packing, payload packing and unpacking. Each observation point
must exist exactly once. A normal 256-byte roundtrip packs/unpacks 256 payload
bytes; 7-byte short writes pack 4810 bytes because ordinary retries supply the
remaining suffix. Transfer scenarios require one scratch allocation per owner
and none per transfer. Successful allocation retry requires two target attempts.
A changed runtime offset must fail the source and counter observations.

Signature negatives cover all seven roles; Process.TryArgument stays deferred.
An arbitrarily named ReadChunk declaration exercises mixed-case role metadata.
The gate does not exhaust the process token counter or claim concurrent I/O,
cancellation, atomic publication or filesystem snapshot semantics.
