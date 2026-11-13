# Counted target path operations

The three path roles supply OS operations needed by the runnable compiler's
loader. Ordinary WindowsPaths code owns joining, prefix normalization,
containment policy and source-path validation. These primitives do not grant
containment or publication authority.

```vb
File.TryFinalPath(ByVal Token As Long, ByRef Destination() As Byte,
                 ByRef Count As Long, ByRef Failure As Long) As Boolean
Path.TryFullPath(ByRef PathUtf8() As Byte, ByRef Destination() As Byte,
                 ByRef Count As Long, ByRef Failure As Long) As Boolean
Path.TryCompareOrdinal(ByRef First() As Byte, ByRef Second() As Byte,
                       ByRef Ordering As Long, ByRef Failure As Long) As Boolean
```

All inputs use their complete logical array spans, with arbitrary lower bounds,
at most 4,096 bytes, strict UTF-8 and no embedded NUL. FullPath rejects empty
input; CompareOrdinal accepts empty spans and returns -1, 0 or 1. On Windows,
comparison uses CompareStringOrdinal with case ignored, independent of the
user's locale. This is path comparison, not UBE language identifier folding.

FullPath delegates lexical resolution to GetFullPathNameW without changing
the current directory. It is not a physical-path or file-existence check.
FinalPath acquires the existing explicit file owner, queries
GetFinalPathNameByHandleW on that exact handle, and releases its busy claim
without closing, seeking or reopening the file. Windows extended prefixes are
returned intact for ordinary library code to normalize.

Returned paths also have a 4,096-byte UTF-8 limit, including any extended prefix.
Expansion past that limit, a Windows result requiring more than 4,096 UTF-16
units, or inadequate caller-provided destination capacity produces a controlled
failure. Destination arrays are never resized. The first returned byte is
stored at the destination's logical lower bound. Both path bytes and Count,
or comparison Ordering, retain their old values on failure. Scalar output
aliases and overlap with either input/output array descriptor or payload are
rejected before mutation. FullPath can use the same byte storage as its input
and output when the existing capacity suffices: decoding completes before
publication.

Successful calls return usable True, set Failure to zero and preserve sticky
Err. Failure returns usable False rather than FAIL. Codes are 1 for invalid
input/encoding/capacity (Err 5), 3 for allocation (Err 7), and 5 for an OS or
second conversion failure (Err 57). FinalPath additionally preserves the
existing file-registry codes 9 for invalid/stale owner and 13 for a busy owner
(both Err 5). An invalid output alias records Err 5 without writing through
the aliased Failure location.

Shared target helpers pack/decode counted UTF-8, encode completed UTF-16 output
before publication, and release scratch/owner claims. One 36,864-byte scratch
payload is charged as 40,960 bytes using the existing allocator, quota and retry
machinery. No large stack buffer, new dependency, managed String feature,
directory owner or process primitive is introduced. All state belongs to the
calling context; these sequential gates do not qualify concurrent execution.

Run:

```powershell
rtk proxy powershell -NoProfile -File bootstrap/tests/path-primitives/check.ps1 -BootstrapExe <binary>
rtk proxy powershell -NoProfile -File bootstrap/tests/path-primitives/fault-check.ps1 -BootstrapExe <binary>
rtk proxy powershell -NoProfile -File bootstrap/tests/semantic-storage/check.ps1 -BootstrapExe <binary>
rtk proxy powershell -NoProfile -File bootstrap/tests/llvm-format/check.ps1 -BootstrapExe <binary>
```

The source gate executes O0/O2 and compares exact Unicode full-path output with
an independent host expectation. It checks nonzero lower bounds, Unicode
ordinal case equivalence, empty comparisons, malformed UTF-8, capacity/alias
preservation, physical path spelling from an open owner, and a later read/close
on that same owner without position changes.

The 58 fault cases run 29 scenarios at both optimization levels. They check
exact 4,096 input/output limits, rejection of oversized UTF-8 expansion, invalid
encoding/NUL, empty/short output capacity, scalar and array aliases, failed OS
and second-conversion results, surrogate output, allocation/retry and quota,
same-handle identity, stale/busy file owners, and comparison failure/invalid
result. Each case asserts status, preserved source/destination/count, Failure,
Err, allocation count and owner/busy state, then repairs the injected condition
and requires successful independent recovery preserving the prior Err. Final
cleanup must dispose successfully and leave zero live allocation blocks.

The native-lowering gate separately executes the same source probe through
the UBE emitter and checks changed-file input rejects exact assertion 32.
Semantic-storage checks all sixteen exact role identities and rejected result,
mode and element shapes, including its unchanged metadata negative control.
The formatter gate checks all 119 exact templates and generated parity.

Reviewed imports gain GetFullPathNameW, GetFinalPathNameByHandleW and
CompareStringOrdinal. The emitted runtime asset remains derived from reviewed
VB6 source and checked by bootstrap/tools/runtime-text.ps1.

Recorded evidence, 2026-11-13 (directories under the user's Local Temp):

- Source gate and bootstrap build: `ube path primitives 0d868d63-27a3-45a4-9e74-2f8aa888b7cd`; binary `build/UBE-Bootstrap.exe`.
- All 58 fault/recovery cases: `ube path primitives 37a15f4d-a9ed-4699-be28-a8b63abf383f`.
- Semantic gate: `ube semantic storage 0648921c-27e1-4117-9d4d-a9390e62d072`; 60 cases and 19,315 assertions at each level, exact negative control 432.
- Formatter gate: `ube llvm format 31281b53-d73d-40e4-a53e-28c8343ecddb`.
- Broader UBE native-lowering evidence is recorded in compiler/Progress.md.
