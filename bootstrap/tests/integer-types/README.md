# Integer storage and conversion gate

Run `rtk proxy powershell -NoProfile -File bootstrap/tests/integer-types/check.ps1`.
The runner accepts `-BootstrapExe` and `-Clang`, retains evidence, and bounds
hidden child execution. It checks typed binding evidence, negative diagnostics,
and actual compiler-generated code at O0 and O2 using volatile runtime input.

The admitted addition is Byte, Integer and LongLong storage/signatures and
integer suffixes. Tests use existing addition, unary signs, comparisons and
And only; no additional arithmetic operators are implied.

The gate passed 46 groups on 2026-11-10 using the updated bootstrap executable.
Evidence: `ube integer types 2b6a6699-d4f3-4371-ac71-cb638091da84` under the
printed temporary root. Parent regression gates separately cover prior features.

Binding assertions cover exact signed/unsigned boundaries, destination-context
constants, all 25 scalar conversion signatures, direct ByRef alias types,
grouped Byte temporaries, and Byte addition's Integer promotion. The generated
matrix observes assignment, ByVal argument and function-result conversion for
every pair of Byte, Integer, Long, LongLong and Boolean. Boolean True-to-Byte
uses mutable runtime input and must fail; False converts to zero.

Four independently reset runtime checks execute the same emitted LLVM at O0
and O2: arithmetic and suffix use, checked failures, exact/grouped ByRef, and
the conversion matrix. Volatile input prevents source constant substitution.
An O2 input-zero control must fail all four observations (mask 15).

A separate boundary harness runs 113 cases over all 25 conversion cells at
both O0 and O2. Each cell uses its source minimum, maximum and zero, plus
destination bounds and adjacent values wherever representable by the source.
Boolean source values are exactly False/True (0/-1); numeric-to-Boolean cases
include the zero transition. Each probe receives volatile runtime input and
checks canonical destination value and Err independently. Out-of-range values
must preserve a seeded destination and report Err 6. The retained
`integer-boundary-cases.json` maps any failing native exit to its precise case.

Failures exercise Integer/Long/LongLong selected-width overflow, LongLong minimum
negation, unsigned narrowing, failed-assignment preservation, Err 6 handler
transfer, argument-conversion suppression, and a callee consuming failed result
assignment before returning neutral success. Static negatives cover ranges,
authoritative suffixes, forbidden grouped signed magnitudes, conflicting type
characters, duplicate identity and every incompatible direct ByRef pair.
An invalid integer program must leave previously emitted LLVM unchanged.
