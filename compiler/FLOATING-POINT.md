# Single and Double support

Status: implemented and qualified in the UBE-written Windows x64 compiler, 2026-11-27.

This is the completed numeric increment under [Roadmap.md](Roadmap.md)'s existing
complete-language item. It does not claim full language completion or floating
source support in the VB6 bootstrap.

## Language contract

The normative sources remain [language-spec.md](../lang-doc/language-spec.md),
[ube.ebnf](../lang-doc/grammar/ube.ebnf) and
[conversion-table.md](../lang-doc/conversion-table.md). Owner decisions applied
during this increment are:

- Single/Double values are finite. Reject Infinity/NaN inputs, spellings and
  results; retain finite IEEE nearest/even rounding, signed zero and subnormals.
- Classic real suffixes are `!` (Single), `#` (Double) and `@` (Currency).
  Integer-looking `1!` and `1#` are valid. Undefined F/R/D suffixes are rejected.
  Recognizing the Currency suffix does not implement Currency arithmetic.
- Floating operands of integer division and Mod round to LongLong, ties to
  even, before checked division. Both operands and the result use LongLong.
  Existing UBE precedence is unchanged: Mod binds tighter than integer
  division, which binds tighter than multiplication/division.
- Power returns Double. Zero to a negative power and a negative base to a
  fractional power fail with Err 5. Overflow/nonfinite values fail with Err 6;
  ordinary division by zero uses Err 11; malformed/special numeric text uses
  Err 13. Known invalid constants are rejected during compilation.
- Canonical text uses the fewest significant digits that round-trip to the
  same finite value; nearest candidate wins, ties to even. Choose the shorter
  fixed or normalized scientific spelling, fixed on a tie. Keep a leading
  fractional zero, uppercase E without redundant sign/zeroes, and negative zero
  as `-0`. Checked conversion and arithmetic overflow retain their distinct
  specified range rules.

`Exit Loop` was specified separately: leave the outermost enclosing lexical
loop of the current invocation, never a caller's loop. It remains unimplemented.

## Implemented scope and architecture

Literals, constants, scalar storage, arithmetic/comparisons, admitted
Boolean/integer/String conversions, parameters/results, grouped ByRef
temporaries, arrays, nested records and worker captures are qualified.
Fresh FAIL, evaluation order, unfinished destinations and sticky Err are
preserved. Numeric cells never become managed roots.

Single uses binary32 bits in an i64 cell; Double uses binary64 bits.
Native operations use typed LLVM arithmetic without fast-math or flush-to-zero.
Exact parsing, formatting, constant arithmetic, conversion and power algorithms
are ordinary UBE. The power evaluator accepts a result only when directed
interval endpoints round to the same bits, with separate exact dyadic handling.
It has no host math-library dependency.

The existing private source bundle contains 13 files and 11 validated support
roles. Generated runtime/template/source identities pass parity checks.
The final compiler and the power client import only KERNEL32.dll
(`llvm-readobj.exe --coff-imports <exe>`); no additional runtime installation
or math DLL was introduced.

## Resource changes and limits

Removed fixed runtime byte/block quotas and the fixed 4096-record collector
workspace. Accounting uses checked size arithmetic; metadata grows under the
existing synchronization/ownership protocol. Allocation failure remains
recoverable, with precise roots and destination preservation.

Source/project/token/node/symbol/output storage now grows beyond its former
quotas. Focused gates admit 129 modules, about 1.2 MiB source, 16,400 variables,
45,000 statements, and output of 33,619,968 bytes / 525,312 lines.
These measurements establish those boundaries, not unlimited project size.

Procedure storage uses a bounded stack fast path for at most 128 cells and
checked heap storage for larger frames; 128 is no longer an admission cap.
Tests execute 128-, 129- and 4105-cell frames and exercise allocation failure,
retry, recursive depth refusal, retained text, root restoration and balanced
frame ownership. Managed worker wrappers have their own fixed root frame.
Binary-expression emission was split after a focused O0 stack diagnostic:
the former 4408-byte compiler frame became 2344/2504-byte frames, eliminating
that reproduced missing-stack-helper link failure.

Remaining limits include Long-sized indexes/file lengths, existing parser,
layout and work guards, the 256-call depth guard and the 60-second native-tool
timeout (extended during class-member integration after a measured 37-second build). Large backend spill frames remain a separate limitation.
This increment does not claim that every artificial limit is gone.

## Qualification and reproducible commands

Run commands from the repository root with
`rtk proxy powershell -NoProfile -File <script> <arguments>`.
Every listed O0/O2 numerical gate includes a changed-expectation negative control.
Temporary evidence directories are local build artifacts, not repository inputs.

Qualified paths below are relative to `$env:TEMP`:

- Seed: `ube dynamic storage d99d4536-7646-4a54-8cce-0051e5d4b511/build/UBE-Bootstrap.exe`.
- Original seed for the constant gate: `ube native intrinsics f844bb77-293e-4c69-af9f-cdb03f67bbb6/build/UBE-Bootstrap.exe`.
- Final compiler: `ube compiler rebuild bd4240e3-5cdd-434a-81d9-a09803a0aedf/generation-2/UBE.exe`.
- Earlier qualified helper compiler: `ube compiler rebuild dcba0bf3-4932-44b3-b729-9755ba31c152/generation-2/UBE.exe`.

| Script and arguments | Assertions / result | Evidence directory under TEMP |
| --- | --- | --- |
| `runtime/tests/floating-point/frontend/check.ps1 -SeedExe <seed> -CompilerExe <final>` | Nine source fixtures at O0/O2, worker negative controls and eight rejected inputs preserving output; PASS | `ube floating frontend e2db1859-c6d1-435a-8fb1-2fe65b37bc29` |
| `bootstrap/tests/native-values/check.ps1 -BootstrapExe <seed>` | Actual LLVM emitter: 84 fragments, 1366 vectors, exact bits/FAIL/Err/destinations; O0/O2 PASS | `ube native values c2d56185-8fa1-4d21-80b7-e48c52249144` |
| `std-lib/tests/floating-point/check.ps1 -CompilerExe <helper compiler>` | 97 exact decimal parsing and failure cases; O0/O2 PASS | UUID `278b074f-b2c2-4d78-a18c-32cf9573f65c` |
| `std-lib/tests/floating-point/formatting.ps1 -CompilerExe <helper compiler>` | 86 exact shortest texts, independent interval oracle, round trips and atomic failures; O0/O2 PASS | UUID `da1bff56-0891-4cfb-9028-73b8d8362f03` |
| `std-lib/tests/floating-point/power.ps1 -CompilerExe <helper compiler>` | 180 exact/domain cases at O0/O2, forced refinement, deterministic allocation FAIL and retry; PASS | UUID `fd5448d3-c359-42e5-82b9-1fbd882da606` |
| `std-lib/tests/floating-point/integer-conversions.ps1 -CompilerExe <helper compiler>` | 320 independent exact-rational conversion cases; O0/O2 PASS | UUID `9d3a86ee-2c0f-4bd0-8fce-11afaea6d1da` |
| `std-lib/tests/floating-point/arithmetic.ps1 -CompilerExe <helper compiler>` | 608 arithmetic cases and 152 comparisons against exact rationals; O0/O2 PASS | UUID `87f5c9ab-a738-4a37-9a1c-6dc6b4e0b6c6` |
| `bootstrap/tests/constant-values/check.ps1 -BootstrapExe <original seed>` | 137 constant vectors, including powers and invalid domains; O0/O2 PASS | `ube constant values 3616c8ba-3f32-4232-9360-7e5f4df0d131` |
| `bootstrap/tests/self-hosting/check.ps1 -CompilerExe <final> -BootstrapExe <seed> -CompilerOnly` | 518 final-compiler CLI assertions, deterministic output and backend failure/timeout recovery; PASS | `ube compiler conformance ddcb028b-b437-4155-bc7b-759bed9c0a55` |
| `bootstrap/tests/concurrent-compilation/check.ps1 -BootstrapExe <seed>` | Current-source single/two-worker determinism, simultaneous requests, cancellation, fresh FAIL, cleanup, overflow and publication/backend recovery; PASS | `ube concurrent compilation 81ba7175-7992-461a-b6fc-6f17b208fd86` |

The separate common seed/compiler run passed 1004 assertions in
`ube compiler conformance 68a6dc56-d041-4648-a0f7-364193102e2f`.
The final compiler-only run reuses that seed evidence explicitly.
The helper compiler precedes the later compiler frame/worker-wrapper and
expression-emission fixes; it qualifies the unchanged numerical library
algorithms. The final source and concurrency gates qualify their integration.
Oracle coverage is not exhaustive enumeration of all floating operand pairs.

### Final self-host fixed point

Command: `bootstrap/tests/self-hosting/rebuild-check.ps1
-InitialCompilerExe <afb4bdc8 generation-2/UBE.exe>
-FirstGenerationDirectory <b1909b95 generation-1>`.

The first generation was built from current sources in
`ube compiler rebuild b1909b95-2f5c-4da8-84fb-e39ea2c215b3` (30,935 ms).
The final comparison explicitly reused that successful package and built
generation 2 in `ube compiler rebuild bd4240e3-5cdd-434a-81d9-a09803a0aedf`
(29,216 ms). Both source ledgers and all native assets matched current files.
LLVM matched byte for byte, SHA256
`BED973DBF3A0E12AE5BAE2A608AD78EA6D7C11BEC3484D7AAB2FD348BF06B8AA`.
Native executables differed only in the PE COFF timestamp.
These are acceptance-run timings on the development machine, not isolated
performance benchmarks. An earlier concurrent-load run hit the existing
30-second backend timeout; retained LLVM compiled successfully directly and
the idle retry passed without a compiler change.

### Managed ownership and regression evidence

`runtime/tests/frame-storage/boundary-check.ps1 -CompilerExe <795b2d3a compiler>`
passes first/last-cell execution at O0/O2 (UUID `bdd6750e-7e11-47b6-afa4-4e01a37c4928`).
`lifetime-check.ps1` in that directory passes injected allocation failure,
Err 7/retry, depth Err 28/recovery, preserved String roots, zero live owned
frames and restoration of the pre-Main root head before disposal, plus its
negative control (UUID `d7b2f350-ef8c-486d-a7fa-dc39d895620e`).

`runtime/tests/managed-text/text-check.ps1` passes full text/5000 retained
strings (UUID `dbd8a0ae-04e2-4a2d-9bbe-71bb050f85df`), and
`-AllocationFailure` asserts two refused allocation attempts, preserved
destination/roots and recovery (`a14d0c11-631f-43c9-bc12-dd95f7c106de`).
The `-Threads` gate passes retained payloads and concurrent collectors
(`18f3dfd7-1803-46fe-956c-84d70f6d662a`, afb4bdc8 generation 2).
These are O0/O2 gates with negative controls.
`fault-check.ps1 -ProgramIR <CollectorFast.ll>` in the same directory passes
ordinary faults, `-Growth`, `-Graph` (5000 records) and `-Rendezvous`;
their evidence is recorded in the managed-text test README.

## Documentation verification

On 2026-11-27 the restored manual received only scoped numerical/Exit Loop
content updates; its navigation, CSS and JavaScript were preserved. The exact
Single, Double and Mod HTML examples were decoded and built with the final
compiler at O0/O2: six positive executions returned zero and six changed-result
controls returned one. Evidence: `%TEMP%/ube numeric manual examples
4cf3c351-b49d-4905-868d-6094f3b21860`.

The unchanged HTML validator passed 274 public pages in a temporary copy
excluding the old `.work` test copies, evidence `%TEMP%/ube numeric documentation
0170d7eb-8a8c-40b8-9cef-823034108c2b`. Browser interaction/rendering remains
unverified because the browser-control host and its URL-policy enforcement
were unavailable. This static check does not qualify the manual's browser or
accessibility release matrix.

## Remaining language scope

Currency, Decimal, Date/Variant families, broad-input VB compatibility
functions, objects/events/finalizers, broader foreign ABI, debugger and IDE
remain outside this increment. The earlier rejection baseline is retained in
`runtime/tests/floating-point/rejection-baseline.ps1`; the old compiler rejected
Single/Double declarations while preserving sentinel output.
