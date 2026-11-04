# Counted byte output evidence

Implemented on 2026-11-03 as a dependency of the existing First checked native
executable item. `FILE-OUTPUT-CONTRACT.md` defines the bounded API. This record
does not qualify native-build path acquisition or executable publication.

## Implementation and ownership

`src/portable/FileBytes.bas` declares `TryWriteByteFile` and `TryFlushByteFile`
with exact `File.TryWrite` and `File.TryFlush` bindings. The source-built v2
compiler validates their signatures and emits calls to the temporary Windows
adapter in `../bootstrap/runtime/windows/file_output.c`. The adapter shares the
existing file-token registry, busy state and close mechanism. A writable flag
prevents using read tokens for writes or writable tokens for reads.

Write pins the caller's immutable byte-array payload, validates the counted
range, and performs one OS write without allocating or copying that payload.
Positive short progress, zero progress and failed writes remain observable.
Flush is explicit; neither operation implicitly closes the token. No registry
or collector lock spans the OS operation. The eventual compiler consumer must
handle progress, cancellation, flush and close under its reviewed contracts.

The tests create writable tokens through a private native producer. Production
guarded relative creation is still pending; this change adds no general path
creation API that could bypass the native path contract.

## Executed gate

The maintained command is:

```powershell
rtk proxy powershell -NoProfile -File std-lib/tools/check-file-output.ps1 -SelectionPath bootstrap/out/v2/df15817344774026bebebfd1e9ae8eaf/candidate.json
```

`bootstrap/build-v2.ps1` invoked this gate with that candidate manifest and the
gate passed all 19 grouped assertions. Report:
`../bootstrap/out/file-output/d65a6be8893c4bb2824414bdb5da97ef/report.json`.
SHA-256: `15834B9A644753A1EBF68A4F798A5B1DA84403E4AEC6AA5ED9CFEDB8E2204D5C`.
The enclosing bootstrap subsequently exited 0 with 914 acceptance assertions.
Its final manifest SHA-256 is
`A8573742189253D557AD7527084E44C6A7E0ED56A937215DAF5EC8A083129445`.
That complete result qualifies this dependency within the bootstrap scope;
later native-builder/checker changes need their own final retained gates.

The direct adapter and actual UBE forwarding calls compiled through both
source-built stages each passed 2097276 native assertions. Many assertions
exercise the real full root table; this is not a count of independent cases.
The two raw LLVM files are byte-identical, 9964 bytes, SHA-256
`6D7F8BB9884F4EA636B39FEEF6B4DBC213A0B24E48D863D84B2D411875F986FB`.

Independent checks cover exact read-back of all byte values, 65536-byte writes,
nonzero lower bounds and subranges, empty ranges, invalid ranges and output
aliases, wrong/stale/busy tokens, short and zero writes, failed writes with
partial progress, flush and retained-close failure/retry, fresh status with
preexisting Err, unchanged source bytes, zero payload copies/allocations, full
root capacity and allocator denial. Four native workers overlap pinned writes
to separate files; same-token write/flush/close requests report busy. A caller
stopping between calls closes the prefix file. This does not claim interruption
of an OS write or native-build cancellation delivery.

Five deliberately defective controls independently omit the write, change its
reported count, corrupt a byte, ignore a failure, or lose token ownership. Each
returns 1 at its prescribed assertion. Ten declaration cases run through both
stages: renamed/mixed-case valid bindings succeed, invalid modes/types/results
and missing bindings diagnose UBE3232, and an unknown role diagnoses UBE3230.

Before implementation, the smallest declaration-only fixtures reproduced
UBE3230 and no LLVM for both new roles through both candidate stages. Command:
`rtk proxy powershell -NoProfile -File bootstrap/out/file-output-admission/check.ps1`.
That retained report diagnoses the prerequisite; it does not qualify its tools.

## Remaining integration

The enclosing bootstrap passed. The fresh compiler's known-but-deferred
primitive list now includes the new role names; this does not admit them into
the bounded scalar native language. Before the correction, the maintained regression
`compiler/UBE_Compiler_v3/tests/semantic/native/cli/check-output-deferral.ps1`
failed against the existing local checker at its first exact flush
oracle, retained in `../bootstrap/out/output-deferral/553ba73c1b704271bd220452734d75d7/report.json`.
The observed result is UBE1425; the required known-role result is UBE1435.
The isolated copied-source correction passed 28 exact source/project process
checks through each stage, with byte-identical compiler LLVM. Its report is
`../bootstrap/out/file-output-admission/correction-c061c3733095409e9d506e15363b6f96/report.json`;
child reports are `../bootstrap/out/output-deferral/3e3dbdf04eaa4a64a2c6113605272465/report.json`
and `../bootstrap/out/output-deferral/e88d09a1e8964de0b88d95ccfee266aa/report.json`.
Canonical and mixed-case flush roles now defer with UBE1435; the write role
retains the earlier UBE1433 array-type diagnostic. Unknown/missing bindings
remain invalid, and an ordinary function merely bearing the API name checks
successfully. Source and project jobs 1/2/4 return exact original locations and
create no artifacts. The production correction was promoted after the enclosing
bootstrap finished; its source hash exactly matches that tested copy. The
maintained semantic CLI parent now includes the regression. Final source-cohort
and retained frontend/checker qualification remain pending for those later edits.
Then integrate guarded writable-token creation and the
bounded compiler emitter. File identity, native tool execution, stack/debug
validation, cancellation delivery and publication require their own evidence.
