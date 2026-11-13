# LLVM staging writer acceptance

Run the real UBE writer against ordinary caller-owned file tokens:

```powershell
rtk proxy powershell -NoProfile -File bootstrap/tests/llvm-writing/check.ps1 -BootstrapExe <bootstrap-executable>
```

The gate copies LLVMWriter, ByteText, FileBytes and their primitive declarations,
emits that actual source once, then compiles native drivers at O0 and O2.
Driver input is volatile; paths are supplied through ordinary source calls.
Every native child is hidden, bounded and recorded in the printed evidence
directory. Host reads independently compare exact expected byte lengths and
SHA-256 digests; assertions inside Probe check writer state and caller close.

All 14 native scenarios and the changed-payload control passed using the host
in `ube project loading dbd30a59-26f6-43b5-a9d9-e3b4c6143261/build`.
Evidence: `ube llvm writing dcdc8295-5ef7-44c9-965b-39676cf224c4` under the
system temporary directory.

Seven scenarios at each optimization level cover cross-64-KiB fragments,
nonzero span starts, signed 64-bit decimal extrema, zero and negative values,
CRLF, final partial-buffer writes, sticky Err, exact 16-MiB output and 500,000-LF
limits with rejected excess, whole-fragment ASCII/range validation, latched
failure and explicit reset. Zero-length spans at the source endpoint succeed.
Invalid-token write failure preserves occupied staging bytes and counters.
Named target wrappers inject native write failure and flush failure separately;
the source procedures are not replaced. Flush failure occurs after all accepted
bytes were written and must retain its FileFailure/Err while refusing reuse.
All scenarios explicitly close their token and require context disposal success.

The O2 negative control changes only the volatile payload seed: the source-state
checks still succeed, but the unchanged byte oracle rejects the exact changed
first byte (`B` instead of `A`). This distinguishes an effective content check
from an unrelated process failure.

The writer operates on private staging files only. These checks do not claim
atomic final publication, recovery of partially written failed stages, concurrent
token access or a complete UBE native emitter. Allocation-fault coverage for
the writer itself is not provided by this gate.

The full compiler required 269,156 IR lines and 9,810,828 bytes, exceeding only
the former 250,000-line bound. Both bootstrap SourceEmitter and UBE LLVMWriter
now admit 500,000 lines; their 16-MiB byte bound is unchanged. The updated gate
passed all 14 scenarios and the changed-payload control with evidence
`ube llvm writing e261ff6b-d0f4-42c6-a1cd-dc387eeb1d17`. A diagnostic copied
bootstrap with higher bounds and the final bounded bootstrap emitted identical
full compiler bytes (`ube IR capacity 1794537082044`).
