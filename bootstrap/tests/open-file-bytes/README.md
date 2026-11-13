# Reads from an already-open file owner

FileBytes.TryReadOpenBytes(Token, Length, Result, Failure) reads exactly the
supplied Length from the owner's current position and probes for EOF. Length
must be between zero and 1,048,576 bytes. The caller normally supplies the size
from a fresh TryOpen and performs any handle-based containment check first.

The helper never opens, closes, rewinds or transfers ownership of Token.
Successful progress and the EOF probe consume the file position even when a
later publication allocation fails; callers must reopen to retry a whole read.
Result changes only after every read, EOF probe and output copy succeeds.
Success preserves prior Err. Failure reports fresh False plus the existing
file failure code and preserves the previous Result.

A shared private TryReadBuffer implements bounded 65,536-byte progress and EOF
policy. TryReadAllBytes reuses it directly, closes before copying its private
buffer into Result, and retains its established primary-error and failed-close
ownership rules. This avoids an extra allocation/copy in the existing API.

## Acceptance

Run with a qualified bootstrap:

```powershell
rtk proxy powershell -NoProfile -File bootstrap/tests/open-file-bytes/check.ps1 -BootstrapExe "<bootstrap executable>"
```

The gate executes actual UBE at O0 and O2 with the existing real-I/O and
allocation observers. It checks nine independent cases: exact and short
progress, zero progress, failed native read after scratch mutation, premature
EOF, growth detected by the probe, empty input, negative length and excessive
length. Every case asserts exact native read calls/bytes and allocation calls,
unchanged failed destinations, still-usable ownership after the helper, caller
close, and zero remaining owners/allocations. Both reader allocation sites
are failed along with their retry; preserved outputs and same-context recovery
are asserted. A changed expected-byte control returns exact exit 99.

On 2026-11-13 the gate passed using:
`C:\Users\Ubehage\AppData\Local\Temp\ube system primitives 74f4f9c9-eb02-4e20-a63e-871e3d04c435\build\UBE-Bootstrap.exe`.

Evidence directories under C:\Users\Ubehage\AppData\Local\Temp:

- open-file-bytes: `ube open file a47377a8-6df4-4d27-ab78-5f1dddea2af3`
- unchanged file-io/check.ps1: all 56 groups passed;
  `ube file io 34d64f2b-84cb-4b2b-b2d2-997c894b8ba9`
- unchanged source-storage/check.ps1: all 16 checks passed, including one-MiB
  input, chunk boundaries and quota failure;
  `ube source storage 7bac15d7-7be9-472e-be33-c14fd86a1b36`

These qualify byte-reading behavior and ownership, not path containment or
self-hosting. No production logic changed after the recorded runs.

