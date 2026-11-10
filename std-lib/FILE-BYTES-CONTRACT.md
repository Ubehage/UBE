# Counted byte-file contract

This contract covers the current bootstrap file-I/O increment. Its scoped native
acceptance is recorded in compiler/Progress.md. It replaces the removed historical
adapter description without restoring its code or verification claims.

Paths are counted strict UTF-8 Byte arrays, with no embedded zero, normalization
or case folding. The Windows target uses wide file APIs and admits regular
disk files. Paths have a separate admission limit of 4,096 bytes. This is an
implementation admission bound, not a replacement for the full language's
String or path contracts. File contents are uninterpreted bytes.

## Primitive ownership and status

The exact File.TryOpen, File.TryRead, File.TryClose and Error.Set signatures
are in language-spec.md section 6.2. Role identity comes from UBE_Primitive,
not procedure spelling. All file primitives return fresh usable Boolean
status. False is not language FAIL and does not enter an On Error handler.
Success sets Failure to zero and preserves incoming Err.

TryOpen requires Token zero and a nonnegative MaximumBytes. It checks the
64-bit file size against that limit before publishing a positive token and
Long Length. Failure sets Length zero and ordinarily preserves Token. Reserve
resource metadata before acquiring the OS handle. If cleanup after a rejected
open cannot close the handle, return False with Failure 7 and publish its live
token so the caller can retry close. Never lose a handle on a rejected open.

Tokens are opaque, positive, monotonic identities, never native addresses and
never reused or wrapped. A token is valid only in its owning execution context.
Copying the integer does not duplicate ownership. The bounded registry admits
at most 64 simultaneous owners per context. Exhaustion must fail before opening
another file. Concurrent use of one owner rejects as Busy; independent owners
must not hold a shared registry lock across OS I/O. Native concurrency remains
a separate acceptance obligation from the sequential bootstrap tests.

TryRead borrows the token and destination for the call. Start is a zero-based
offset from the first payload byte, independent of array lower bounds. Count
must be 0..65,536 and fit the complete destination span; current arrays admit
at most 1,048,576 elements. Validate before I/O. Success publishes exactly ReadCount
bytes, 0..Count; a positive short read is progress and zero is EOF. Remaining
destination bytes stay unchanged. Failure preserves the entire destination and
returns ReadCount zero. Zero count validates the token and span without an OS
read. Caller code must not concurrently mutate the destination.

TryClose zero is a successful no-op. A stale or foreign token fails safely.
Successful close zeroes Token and releases its adapter storage. A failed OS
close preserves the token and all ownership for retry. External resources are
explicitly owned: runtime context disposal must report live files, not silently
close them. Ordinary UBE code must finish its cleanup before Err.Raise.

Scalar output addresses must be distinct. They must not overlap the array
storage used by an operation. Check aliases before changing any output; an
invalid alias must not overwrite a live token while trying to report failure.

## Failure codes

| Failure | Meaning | Err |
|---:|---|---:|
| 0 | Success | Preserve incoming value |
| 1 | Invalid request or output alias | 5 |
| 2 | Invalid path | 5 |
| 3 | Open or size-query failure | 57 |
| 4 | Size exceeds admitted limit | 6 |
| 5 | Read failure | 57 |
| 6 | Premature EOF, reported by ordinary whole-input policy | 57 |
| 7 | Close failure | 57 |
| 8 | Allocation or owner-capacity failure | 7 |
| 9 | Invalid, stale or foreign token | 5 |
| 10 | Cancellation policy, reserved | 5 |
| 11 | Input grew, reported by ordinary whole-input policy | 57 |
| 12 | Missing argument, reserved for Process.TryArgument | 5 |
| 13 | Owner busy | 5 |
| 15 | Write failure | 57 |
| 16 | Flush failure | 57 |

Error.Set records a positive error number and returns False without language
control transfer. A nonpositive number records Err 5. This lets ordinary UBE
restore a primary error after explicit cleanup instead of deriving fresh status
from an old Err value. Process.TryArgument is not part of this increment.

## Representation and ordinary policy

The owner approved bounded byte packing on 2026-11-10. Current Byte elements
occupy private i64 cells; OS calls require packed bytes. The adapter uses bounded
temporary storage and copies confirmed read bytes into caller cells only after
success. Allocation requests use the existing recovery/retry boundary. Tests
must measure actual allocations, copied bytes, OS calls and released owners.
This does not claim the historical adapter's zero-copy writer cost.

Ordinary UBECore code performs progress loops, rejects premature EOF, probes an
extra byte for growth and closes before publishing an independent result. A
failure keeps the caller's previous result. Preserve the primary failure through
cleanup, while exposing any still-live token for retry. This is not an atomic
filesystem snapshot: same-length edits during reading remain possible.

FileBytes.TryReadAllBytes clamps MaximumBytes to 1,048,576 bytes. Read and write
progress loops request at most 65,536 bytes at a time. Per-owner packing storage
is 65,536 bytes, charged as 69,632 bytes with header/page rounding; it is reused
across chunks. This transfer bound is independent of the path and whole-input
bounds. The 16-check source-storage gate qualifies these capacities at O0/O2,
including short progress and independent native-byte comparisons.

See [FILE-OUTPUT-CONTRACT.md](FILE-OUTPUT-CONTRACT.md) for exclusive creation,
write and flush, and [bootstrap/FILE-IO.md](../bootstrap/FILE-IO.md) for scope
and acceptance. No C runtime adapter or new third-party package is introduced.
