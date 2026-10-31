# Opaque native scalar acceptance evidence

Recorded 2026-10-30 for the native-datatype item in
[the library workplan](../../ROADMAP.md) and
[the fresh compiler workplan](../../../compiler/UBE_Compiler_v3/Roadmap.md).
The owner explicitly delegated syntax/ABI decisions, preferring VB6 conventions
where compatible with agreed definitions. The adopted mechanism is in
[NATIVE-TYPE-PROPOSAL.md](../../NATIVE-TYPE-PROPOSAL.md).

## Result and reproduction

From the repository root:

```powershell
rtk proxy powershell -NoProfile -File bootstrap/build-v2.ps1
```

Result: **204 acceptance assertions passed**, comprising the existing 130 core
assertions, 66 native-value assertions and eight ordinary-record assertions.
The command builds the current C++ seed, bootstrap runtimes and both v2 stages
from source, compares the exact self-compilation LLVM fixed point, then runs
both additional proof suites before publishing `bootstrap/out/v2/current.json`.
No restored compiler executable or archived compiler implementation is used.

The immutable core-build snapshot binds the child proofs to the exact candidate
compiler and all 173 input identities. The final manifest incorporates child
report hashes and every passing assertion. Input identities are checked again
before publication. Failure leaves the previously selected compiler in place.

| Selected artifact | SHA-256 |
|---|---|
| Final manifest | `006D6EC71EF0423E8B70A57B7293B611E452C709867FE74AFEA901B880F99CDC` |
| Immutable core manifest | `56E00BD37A4DAE652B65A3E9C82B41AD63691CFA49C28BBDFF8344617198A313` |
| Stage-two executable | `9C6B666F858B451D8E8D96E2595FF4AFCB8B7298ABC3499DA14A8DE0BBA28866` |
| Stage-zero executable | `C85D0CB4C21A757D40BB44E34C7741621969D55FF69BCD6713D2B63110EF8290` |
| Bootstrap runtime object | `2FF8E861816356DD64E803B07B3CE8E615F74B18A0571A530000E561B807D3E0` |
| Unicode runtime object | `AB41E49C6E1375AC878F588FF88DC7DB43A7018CAD8F3F811DE811F7C245EDFD` |
| Exact stage-two/stage-three LLVM | `078C05C5D098640BE283A348AA38170CF89552565E632EDEA848BEC2B02B6960` |

The manifest and executable are under
`bootstrap/out/v2/6df71ef3a52749ac9bd6c965e086022f/`.
The executable is 256,512 bytes. Full gate elapsed time was 77,018 ms;
stage-one and stage-two self-compilations took 12,798 and 12,802 ms. Sampled
peak working sets were 30,085,120 and 26,587,136 bytes respectively. These are
single-run observations, not allocation, performance-scaling or concurrency
acceptance results. Tool versions, paths, hashes, invocations, bounded process
results and source identities are retained in the generated manifest.

## Independent obligations checked

The expected cases are in `proposed/cases.json`; that directory retains its
original name but its corpus status is adopted acceptance. Ten native variants
run through both accepted stages with exact stdout, exit and empty-stderr
oracles; each pair must also produce byte-identical raw LLVM. Thirty-six
rejection variants require the expected diagnostic code, controlled exit 1,
matching diagnostics between stages and no newly created LLVM artifact.
That gives 30 positive assertions and 36 rejection assertions.

| Obligation | Acceptance coverage |
|---|---|
| Representation | Byte, Integer and Long payloads have measured target size/alignment 1/1, 2/2 and 4/4; signed extrema round-trip. |
| Ordinary names | Renamed types/procedures behave identically; a legacy intrinsic spelling works only with its explicit valid native binding. |
| Nominal opacity | No payload field access, implicit storage/native conversion, cross-native assignment, equality or ByRef alias. |
| Neutral/copy semantics | Zero initialization, assignment, independent ByVal mutation, exact ByRef mutation and returned values. Native arrays retain tested value behavior. |
| Equality | Same-declaration `=` and `<>` compare representation; ordering, arithmetic, implicit Print and Boolean conditions reject. |
| Explicit binding | Exact ByVal signatures, enclosing attribute target, known single role, one Pack/Unpack per type, case-insensitive language identifiers, inert unrelated metadata. |
| Ownership | Bindings must be in the declaring source module; native declaration/binding endpoints cannot cross source modules. |
| Evaluation | Pack arguments with observable side effects execute once. Types can be zero-initialized/copied without bindings. |
| Failures | Invalid constant narrowing rejects; runtime narrowing returns neutral zero with Err 6. Infallible Pack/Unpack preserve existing Err. |
| Fresh status | An ordinary test-only TrySet procedure returns fresh Boolean status; invalid updates preserve destination and stale Err 77. |
| Lowering | One-component native aggregate, insertvalue/extractvalue conversion and scalar equality; no runtime pack/unpack or heap-allocation call in the checked proof IR. |
| Malformed declarations | Unsupported/managed/self/nested representation, fields, unknown/missing/duplicate/conflicting metadata and invalid signatures reject before output. |

The eight-assertion ordinary-record suite independently reruns original and
renamed field-only record programs and nominal assignment/ByRef rejection.
It checks actual layout, copies/calls/results, explicit fresh status, preserved
Err and raw LLVM agreement. [BASELINE-EVIDENCE.md](BASELINE-EVIDENCE.md) retains
the initial pre-mechanism snapshot; the current baseline report is below.

The shared `value-probes.ps1` adapter first preserves raw compiler IR, then
appends target GEP layout queries to a separate test copy. It renames only the
generated entry wrapper so the C test entry can seed/check Err around the full
wrapper. It replaces no UBE procedure, native type definition or runtime
operation. C is test infrastructure, not the library implementation.

| Proof report under `bootstrap/out/` | Assertions | SHA-256 |
|---|---:|---|
| `native-type/0521222224c7451d8ac673428d78257a/report.json` | 66 | `545FE99DECF0A6067C1512F0C0B1BF84AAEFD9299A738030BC003AF9A4B5FE99` |
| `value-record/a943ffe45e90447796ee0ab0bbddee2c/report.json` | 8 | `9F4E8A148D49CCAA36E5858F378C3E8FE79B6F55AC081E73ECE6EBA9C9D408D1` |

The checkers can also be rerun separately against the accepted selection:

```powershell
rtk proxy powershell -NoProfile -File std-lib/tools/check-native-type.ps1
rtk proxy powershell -NoProfile -File std-lib/tools/check-value-record.ps1
```

## Focused defects diagnosed and corrected

A missing native binding using a registered bootstrap intrinsic name initially
escaped declaration validation and emitted IR. The minimal reproduction is
recorded in `bootstrap/out/native-type/c27f4bc969db497a8d729bfee24b4e25/report.json`.
Legacy bootstrap resolution now requires its full registered signature; name
alone cannot bypass native binding. Acceptance checks both the missing-binding
rejection and the same spelling with a valid explicit native binding.

`Print NativeValue` initially emitted invalid aggregate-print IR with compiler
exit 0. The focused before-fix evidence is
`bootstrap/out/native-print-before/104f99cbd3e14fb2b5fa840d6074ee58/report.json`.
The maintained corpus now requires UBE3233, exit 1 and no new LLVM artifact.
These fixes stay within the adopted scalar mechanism.

## Language and documentation checks

- `rtk proxy powershell -NoProfile -File lang-doc/tools/validate-grammar.ps1`:
  passed, 202 core and 19 conditional rules.
- `rtk proxy powershell -NoProfile -File lang-doc/grammar/fixtures/validate-fixtures.ps1`:
  passed, 12 indexed fixtures in four categories, including the new native example.
- `rtk proxy powershell -NoProfile -File docs/assets/tools/validate-docs.ps1`:
  passed, 265 HTML files with predefined local link/asset/structure checks.
- `rtk proxy powershell -NoProfile -File std-lib/tools/check-native-example.ps1`:
  four assertions passed against the selected compiler. The HTML example equals
  its normative fixture; the documented bare bootstrap body runs through both
  stages with exact output 255 and exit 0, and raw LLVM agrees. Report:
  `bootstrap/out/native-example/9d6b6ba9d775423dbad59576c68492ff/report.json`.
  This does not claim execution of the full native-source envelope.
- `rtk proxy powershell -NoProfile -File bootstrap/tests/v2_usage_tests.ps1`:
  passed exact byte-array output, invalid-constant rejection, preservation of
  the prior executable on failure and successful replacement. Report:
  `bootstrap/out/v2-usage/aa10c3b987674b29a25714ec5837506d/report.json`.
- `rtk proxy powershell -NoProfile -File compiler/archived/verify.ps1`:
  passed 367 original/archive checks, 13 recorded relocations, nine previews,
  28 library files, six manifests/132 inputs and 21 script syntax/root checks.
- `rtk proxy powershell -NoProfile -File std-lib/tools/check-inventory.ps1`:
  passed 175 reference names, 73 historical hooks and 52 local links.

The grammar, normative semantics, bootstrap profile and public Type/Intrinsic/
Attribute reference document the adopted addition. The public browser,
keyboard, accessibility and release matrices remain unverified.

The final local completion procedure,
`rtk proxy powershell -NoProfile -File bootstrap/out/audit-native-completion.ps1`,
passed: 262 selected/tool/input/artifact identities, successful 204/130 final/
core manifests and 66/8 nested reports, corpus counts 10/36, 11 PowerShell
syntax parses, five JSON parses, 26 Markdown link checks and diff/whitespace
hygiene. The procedure is a generated local audit, not a maintained build gate.

## Boundaries and handoff

This qualifies unmanaged scalar representations on the initial Windows x64 GNU
target. It does not qualify managed representations, lifecycle/GC, deep-copy
ownership, foreign ABI, full module privacy/namespaces, complete language
coverage, a general fallible primitive ABI or concurrent execution. Full value
copying of arrays containing managed storage retains existing bootstrap limits.

The small C++ seed and archived compiler/library implementation are unchanged
by this goal. Fresh v3 remains documentation only. `std-lib/UBECore.UBE` still
contains its empty identity module; no public Octet or byte/text API is shipped.

Next: define the first byte/text storage and construction contract around a
concrete compiler consumer, including Unicode boundaries, ownership, mutation/
sharing, fresh failure status and failed-update guarantees. Prove managed
lifecycle/cleanup separately before production String implementation; measure
allocation/copy costs and independent-instance concurrency before compiler use.
