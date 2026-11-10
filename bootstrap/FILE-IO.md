# Counted file input/output dependency

Status: implemented; scoped native acceptance is recorded in compiler/Progress.md.
This work belongs to the existing Extend bootstrap dependencies item in
project-docs/Development-Plan.md. It extends the same multi-module pipeline.

## Evidence and scope

HostFiles.ReadUtf8File opens source files, checks their size, reads counted
bytes, then decodes UTF-8. NativeBackend writes counted output and publishes
only after successful validation. The next UBECore prerequisite is counted
byte I/O, without claiming String, source decoding, or executable publication.
Ordinary progress loops and publication policy belong in UBE source; OS calls
and resource admission belong behind the target boundary.

The normative language-spec.md section 6.2 retains File.TryOpen, TryRead,
TryClose, TryWrite and TryFlush signatures and Error.Set. It references
std-lib/FILE-BYTES-CONTRACT.md and FILE-OUTPUT-CONTRACT.md, both removed during
the restart. Their last pre-restart contents were inspected with:

```text
rtk proxy git show 1376e39f:std-lib/FILE-BYTES-CONTRACT.md
rtk proxy git show 1376e39f:std-lib/FILE-OUTPUT-CONTRACT.md
```

That history supplies contract evidence only, not restored implementation or
verification. In particular its C adapter, managed roots, compiler generations
and earlier conformance claims are not the current restart architecture.

## Owner-approved boundaries

The historical read opener does not create writable tokens. The output
contract deliberately delegates their acquisition to a separately reviewed
producer. Owner-approved addition, 2026-11-10: File.TryCreateNew for
exclusive creation from counted UTF-8 paths, failing when a file exists. This
would supply a basic output owner without changing NativeBackend publication.

Current Byte arrays use private i64 cells. They cannot be passed as packed
bytes to Windows ReadFile/WriteFile. Owner-approved adaptation, 2026-11-10:
a bounded temporary packed-byte buffer, with actual copy/allocation
costs measured. Historical zero-copy writer claims cannot carry forward with
this representation. A global Byte-layout change is not implied by this task.

## Required acceptance

The current implementation uses 64 file-owner slots per execution context,
with process-wide atomic monotonic token identities. Each owner reserves one
65,536-byte scratch payload through the existing allocation/retry machinery;
its block is charged 69,632 bytes including the header and page rounding.
Opening uses that payload for the bounded UTF-8/wide path conversion; transfers
reuse it for at most 65,536 packed bytes. Paths remain limited to 4,096 UTF-8
bytes. Transfers allocate no additional payload.
The file-I/O gate observes the actual allocations, native calls and executed
packing/unpacking stores rather than deriving costs solely from file lengths.

Whole-input policy admits at most 1,048,576 bytes. Ordinary FileBytes read/write
loops split progress into requests of at most 65,536 bytes, including retries
after short transfers. The separate 16-check source-storage gate passed O0/O2
round trips through 1 MiB, exact chunk boundaries, short progress, oversized
request rejection, quota rejection and balanced owners. See
[its README](tests/source-storage/README.md); the original file gate remains
the evidence for the unchanged primitive ownership and fault contracts.

Validate exact role signatures and passing modes. Preserve fresh usable
Boolean status, sticky Err on success, primary failure through cleanup and
explicit live ownership after failed close. Tokens must never expose native
addresses or allow stale owners to access new resources. Reject overlapping
scalar outputs before mutation. Retain bounded counts and full range checks.

Actual UBE fixtures must exercise empty and nonempty files, arbitrary bytes,
nonzero array bounds, partial reads/writes, EOF, zero write progress, invalid
paths and tokens, wrong access mode, allocation/I/O/flush/close failure,
unchanged destination on failed read, and explicit cleanup before raising.
Observe native calls, copy costs and resource balance. Existing output must
survive failed creation/publication. Repeat at O0/O2 with fault-injection
controls and relevant existing regressions on the final VB6 executable.

Windows API references for the target boundary:
[CreateFileW](https://learn.microsoft.com/en-us/windows/win32/api/fileapi/nf-fileapi-createfilew),
[ReadFile](https://learn.microsoft.com/en-us/windows/win32/api/fileapi/nf-fileapi-readfile),
[WriteFile](https://learn.microsoft.com/en-us/windows/win32/api/fileapi/nf-fileapi-writefile).
