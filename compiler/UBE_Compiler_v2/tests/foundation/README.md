# v2 byte/scalar acceptance cases

`cases.json` specifies exact native output/exit and LLVM storage assertions
before the repaired compiler runs. Both source-built v2 stages must satisfy
them, with byte-identical LLVM and matching rejection diagnostics. Test sources
use the documented bare-source bootstrap envelope; they are not UBECore APIs.

Positive cases cover unsigned Byte and signed Integer storage, record layout,
field/call/result/assignment conversions, exact ByRef storage, scalar record
copying, promotion, arithmetic, comparisons through the shared subset cases,
neutral overflow/division failures, Boolean printing, signed minimum values,
compact Byte/Integer arrays, embedded zero and Preserve growth. The C storage
probe separately checks actual byte stride and Err preservation/failure.

Negative cases cover invalid constants and constant arithmetic at storage,
call and result boundaries, exact ByRef width and unsupported inline recursive
records. The earlier whole-array, ByVal-array and array-containing record
rejections now have independent positive mutation/zero oracles. The separate
`std-lib/tools/check-managed-values.ps1` gate must additionally qualify managed
roots, result boundaries, allocation failures and collection before selection.

Run `rtk proxy powershell -NoProfile -File bootstrap/build-v2.ps1` from the
repository root. It also retains all 56 file-based inherited v2 rejection cases
in `bootstrap/tests/v2-negative-cases.json`, generated malformed-input cases,
existing native programs, C++ seed suites, runtime probes and v1 preservation
cases. A matching old compiler output is not the independent native oracle.
