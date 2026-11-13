# Windows executable framing gate

Run `rtk proxy powershell -NoProfile -File bootstrap/tests/windows-images/check.ps1 -BootstrapExe <bootstrap-executable>`.

WindowsImages.TryCheckAMD64Executable(PathUtf8, MaximumBytes, Token, Failure)
is ordinary Windows-library UBE used by native output validation. It checks
bounded DOS/PE signatures, the AMD64 machine, PE32+ optional-header magic,
the executable characteristic and absence of the DLL characteristic. It does
not establish the validity of every PE field, executable trust, or successful
program execution. These are the existing VB6 backend's framing requirements.

The caller supplies a maximum byte length and an empty resource token. Reads
use one bounded 65,536-byte buffer and handle partial progress; locating the
PE header consumes the intervening bytes without a new seek primitive.
Unsigned DOS offsets are decoded in LongLong before bounds checking, so a
malformed high-bit offset cannot wrap. Success closes the owner. Failure keeps
the primary error and retains the token when closing fails, allowing explicit
caller retry. A nonempty input token is rejected without taking ownership.
Failure 16 denotes invalid image framing; other status values follow FileBytes
and FilePrimitives. Success preserves sticky Err.

The O0/O2 gate executes 24 cases: exact minimal framing, a header beyond two
transfer buffers, an actual LLVM-built executable, caller size bounds, wrong
signatures/machine/magic/characteristics, truncated headers, four invalid
offsets, short/zero/failed reads, close failure with retained ownership,
preservation of an earlier image error during failed close, both measured
allocation sites and failed retries, and successful recovery. Disposal must
leave zero observed blocks and file handles. Changing the first file's DOS
signature must fail the unchanged oracle with exact exit 1. All artifacts are
retained in the printed evidence directory.
