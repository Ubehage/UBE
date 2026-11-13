# Checked integer operators

Run the same gate against the bootstrap and the actual UBE compiler:

```powershell
rtk proxy powershell -NoProfile -File bootstrap/tests/integer-operations/check.ps1 -CompilerExe <compiler-executable>
```

The gate uses the common CLI to emit and build executable source at O0/O2. Native exit codes check Byte promotion, Integer/Long/LongLong selected-width overflow, final narrowing, signed quotient and remainder, division by zero, minimum divided by -1 overflow, and minimum Mod -1 success. Explicit checks distinguish fresh FAIL from stale Err, preserve assignment destinations on failure, require exact-once left-to-right operand evaluation, skip later effects after an earlier failure, and preserve an earlier scalar read across a later mutation.

Both source and constant expressions follow the normative grammar: Mod binds more tightly than integer division, which binds more tightly than multiplication; all three associate left. Folded sign quadrants and extrema include LongLong maximum/minimum divided by three and products near the signed limits. Rejected constants include products too large even for the bootstrap's Decimal intermediate, division overflow, zero divisors and narrowing. Failed emission/build must preserve an existing valid IR/executable exactly. Mod additionally requires whitespace on both sides; parenthesized adjacency is rejected.

A changed expected Byte product must produce native exit 31. Restoring the source must restore the exact original IR hash and native success, so simply compiling without executing cannot pass the gate.

Baseline reproduction with `-BaselineRejection` against `%TEMP%\ube compiler rebuild 18c217dd-d417-4e79-b96a-198202d3613a\generation-2\UBE.exe` accepted the identical addition control, but rejected each of `*`, `\` and Mod with controlled E_LOAD operation/code/reason 8/2/3 and no output. Evidence: `%TEMP%\ube integer operations 4ff6605a-5478-4ea5-a785-78a161bb7b86`.

The numerical corpus and its 13 constant/known-zero negative cases passed both optimization levels with:

- Bootstrap `%TEMP%\ube source semantics 79867c1f-4695-4abf-a835-c5a4a6cf8bdf\build\UBE-Bootstrap.exe`: evidence `ube integer operations 71054f63-4160-4624-882c-a5cea06202b5`.
- Actual UBE compiler `%TEMP%\ube integer codec compiler\UBE.exe`: evidence `ube integer operations d4c2ee50-07c0-4548-9649-5dfbcf6192ae`.

The separate `-ModSpacingReproduction` mode established that the old arithmetic bootstrap incorrectly accepted `(5)Mod(2)`, `(5) Mod(2)` and `(5)Mod (2)` (evidence `ube integer operations fca7b2fa-9398-4953-9261-81ac0c0ed8ba`). Those three rejection cases were then added to the full gate. The complete corrected suite, including all 16 numerical/grammar negatives, passed:

- Bootstrap `%TEMP%\ube source semantics cf7c9be7-1c06-4b32-8910-5fb75d3b6825\build\UBE-Bootstrap.exe`: evidence `ube integer operations 645ccce3-c497-4764-8be9-bc1df83a562c`.
- Final actual UBE compiler `%TEMP%\ube integer codec compiler final\UBE.exe`: evidence `ube integer operations b5b11006-35b7-4caf-b0e3-17f5ffc660e8`.

Independent implementation review confirmed left-before-right operand emission, selected-width signed overflow intrinsics, zero guards before native division/remainder, and a safe divisor for minimum Mod -1. Constant multiplication checks its bounds before evaluating the product, including cases exceeding the bootstrap Decimal range. This review supplements the executed assertions; it is not a separate claim of exhaustive correctness.

The full `bootstrap/tests/concurrent-compilation/check.ps1 -BootstrapExe <79867c1f bootstrap>` regression also passed to exit zero in `ube concurrent compilation de75a800-9d45-40ce-bad1-fec58fc90ef0`, including deterministic artifacts, independent simultaneous requests, active cancellation, worker failure, retained cleanup, quota diagnostics, competing publication and native backend timeout followed by recovery. It used the arithmetic implementation before the isolated Mod-spacing parser correction, and was not an idle performance measurement.

This gate qualifies fixed-width integer arithmetic only. Floating division, powers, floating rounding, managed strings and garbage collection are outside its scope.
