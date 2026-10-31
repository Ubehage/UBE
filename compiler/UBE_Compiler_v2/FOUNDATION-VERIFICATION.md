# Source-built v2 foundation verification

Current combined qualification: **501 grouped assertions** via `bootstrap/build-v2.ps1`,
including the earlier 296-check ByteBuffer/decoder foundation, direct source
Library references, native envelopes, recoverable file/Unicode argument input,
entry admission, source ingestion and the fresh v3 scanner/Unicode consumer.
Exact current identities, the recoverable tracing/first-error runtime correction
and fresh qualification are in
[PARSER-PROBE-EVIDENCE.md](../UBE_Compiler_v3/PARSER-PROBE-EVIDENCE.md).
The prior scanner snapshot and its detailed recognition limits remain in
[SCANNER-EVIDENCE.md](../UBE_Compiler_v3/SCANNER-EVIDENCE.md).
The earlier 470-check source-input snapshot is preserved in
[SOURCE-INPUT-EVIDENCE.md](../UBE_Compiler_v3/SOURCE-INPUT-EVIDENCE.md).
The immutable earlier body snapshot remains in
[BYTE-BUFFER-EVIDENCE.md](../../std-lib/BYTE-BUFFER-EVIDENCE.md).

The original repair snapshot below passed 130 assertions; the later native
scalar snapshot passed 204. The earlier owner-approved managed foundation has a
recorded **276-assertion** source gate: 136 core, 66 native scalar, eight
ordinary-record, six managed-substrate, 52 compiled managed-value and eight
decoder checks. Three earlier copy rejections became positive native oracles,
accounting for the core count change. Exact snapshot identities and limits are
in [managed evidence](../../std-lib/MANAGED-STORAGE-EVIDENCE.md);
[native evidence](../../std-lib/tests/native-type/NATIVE-EVIDENCE.md) retains
the earlier scalar proof.

The owner requested a usable v2 bootstrap tool on 2026-10-30. Its bounded
acceptance contract is [FOUNDATION-PLAN.md](FOUNDATION-PLAN.md). Run:

```powershell
rtk proxy powershell -NoProfile -File bootstrap/build-v2.ps1
```

The current gate builds the small C++ seed and both runtime objects, then v2
stages one/two, entirely from checked-in source. It compares exact stage-two/
stage-three LLVM bytes for the same current manifest. No restored executable,
archived v3/v4 code, download or new dependency participates. Each subprocess
is bounded; every build gets a fresh output directory. Only a complete passing
gate selects `bootstrap/out/v2/current.json`.

## Acceptance coverage

- Four inherited C++ lexer/parser/semantic/codegen suites.
- Runtime assertions for thread-local Err, checked integer failures, narrowing
  boundaries, stale-Err preservation, actual byte-array stride and Preserve.
- Both v2 stages independently execute exact expected native output/exit for
  the existing showcases, backend program, cross-module project, shared
  foundation cases and new byte/scalar programs. LLVM width assertions inspect
  storage and signatures. Every positive pair requires byte-identical LLVM.
- All 56 inherited file-based v2 rejection cases retain expected diagnostic
  text/status. New rejections cover invalid constants at assignment/call/result
  boundaries, arithmetic, exact ByRef width, inline record cycles, invalid
  storage-binding metadata/signatures and an array-valued Main.
  Both stages must agree on diagnostics and publish no new LLVM artifact.
- Generated missing-file, embedded-NUL, invalid UTF-8 and lone-CR inputs,
  invalid argument count and output-write failure remain controlled errors.
- A 5,000-term expression, 5,000 nested parentheses and 5,000 unary operators
  get a depth-limit diagnostic before recursive processing; a 64-term sum
  executes and prints 64 through both stages. The initial flat-expression
  reproducer returned abnormal exit -1073741571 with no diagnostic. Its before
  evidence is `bootstrap/out/deep-expression-before.json`. The repaired compiler
  uses iterative graph checking plus token-nesting preflight, with the single
  limit defined by `ExpressionDepthLimit()` (128), before semantic recursion.
- The source-built v1 still passes two exact native showcases and four
  rejection cases.

The integer runtime regression was run against the prior runtime object before
the fix: it exited 65 on `ube_checked_div_i32(1, 0)`. The repaired probe must
complete every overflow/division/normal-result assertion, return zero and print
`integer failure probe passed`. This establishes the repaired failure paths;
ordinary successful compilation alone does not.

Initial baseline evidence is retained under
`bootstrap/out/v2-diagnostic/69859130ce264a579409c9e4feb17227/commands.json`.
Current-source v2 already reached a fixed point before repairs. Native byte
fixtures then reproduced unsupported Byte declarations, and the earlier shared
width probe isolated i32 Integer storage. Repairs stayed within those concrete
storage/conversion failures and the diagnosed arithmetic termination path.

## Supported use and remaining limits

Use Byte/Integer/Long scalar storage and the tested integer operations,
Long/Boolean/bootstrap-String compiler code, finite ordinary records,
one-dimensional arrays and ordered multi-module executable manifests.
Independent Byte-array/array-containing record copies, ByVal and results,
nested roots, borrowed element lifetimes and normal/early-return collection
now pass exact native oracles through both stages. Byte arrays preserve every
byte including zero; they are not decoded text. Narrowing is checked.

This is a working bootstrap subset, not full UBE conformance or a public
compiler release. Array indices/counts are bounded to signed Long and rank one.
General managed families, builtin String lifecycle, complete user concurrency,
full numeric conversions and complete structured errors remain outside this
gate. The substrate has separate concurrent independent-worker assertions;
these do not qualify unsynchronized shared user mutation. Ordinary managed
payload allocation failure returns Err 7 after collection/retry and preserves
the destination. Minimum safety-bookkeeping exhaustion retains an exact bounded
fatal-path test. Legacy String and file-input process exits remain documented
bootstrap boundaries. The compiler source must stay inside its validated
preflight/ownership constraints.
Expression nesting/graph depth is bounded at 128 for this bootstrap tool;
exceeding its resource limit is an error, not permission to overflow the native
stack. This does not claim a complete adversarial-input or recovery audit.

`StringFromByte` still accepts 1..255; the earlier zero suitability probe is
not turned into a conformance pass. Native scalar syntax/ABI was subsequently
adopted and proved under delegated owner authority. Fresh UBECore's decoder
retains eight assertions and measured zero allocations; ByteBuffer source-body
functional checks are separate, with its cost/failure/concurrency qualification
still pending at that earlier snapshot; those component checks now pass as
part of the linked 296-assertion record. This does not establish a full Library
build, released library binary or builtin String replacement.

The generated manifest contains exact source/header/fixture/script/tool/object/
executable hashes, full commands and outputs, timing, assertions and limits.
Installed GCC/G++ 16.2.0 and Clang 23.1.3 remain temporary prerequisites; no
missing toolchain-lock document is treated as evidence. Process working-set
sampling and elapsed time are diagnostic measurements, not allocation, scaling
or multithreading proof. Generated outputs are ignored by Git.

## Recorded initial repair run

The complete source gate passed all 130 acceptance assertions. The generated
manifest records 158 input identities and the exact accepted executable and
LLVM fixed point. Earlier exploratory runs and their failures remain under
`bootstrap/out/`; they are not the selected tool.

The separate maintained helper acceptance command is:

```powershell
rtk proxy powershell -NoProfile -File bootstrap/tests/v2_usage_tests.ps1
```

It asserts exact byte-array native output, invalid-constant rejection with the
existing executable's hash unchanged, then successful replacement and execution.
The helper uses the accepted compiler/runtime identities and publishes only after
successful emission/linking; a source/tool mismatch requires rebuilding v2.

Accepted source gate:
`bootstrap/out/v2/4f668451c73e4db9a25f4799070a1adf/manifest.json`.
Manifest SHA-256:
`6E53635AC2B1DE3376BB2216B9783AF1B0AC0DA651E94A87F165BA069B4D3CD1`.

| Recorded result | Value |
|---|---|
| Acceptance assertions | 130 passed |
| Input identities | 158 source/header/fixture/script/data files |
| Full build/test duration | 61,615 ms |
| Stage-one / stage-two self-compilation | 11,282 / 11,268 ms |
| Sampled compiler process peak working set | 25,325,568 / 27,484,160 bytes |
| Accepted stage-two executable size | 248,832 bytes |
| Accepted executable SHA-256 | `CDC9DF7153E015BBAD958DE60E5C2B6B55F4EC382CF8588DACBA557435494E77` |
| Identical stage-two/stage-three LLVM SHA-256 | `A0F8C8F7438F0AE51440F5285A85037EA32E18EE7ADD9637CE96A2F0FE213628` |

The maintained helper acceptance command also passed. Its generated report is
`bootstrap/out/v2-usage/40aca7400f2c413e85b80a1b36ede054/report.json`.
It verified the new executable's exact output, controlled rejection with the
prior executable unchanged, and successful atomic replacement. A PowerShell
null-string interop error found by that final test was corrected before the
accepted run; diagnostics now print plainly to stderr without host wrapping.

Supporting checks passed:

- `rtk proxy powershell -NoProfile -File compiler/archived/verify.ps1`:
  all 367 archived/original compiler files, 28 prior library files, previews,
  manifests and script paths remain intact.
- `rtk proxy powershell -NoProfile -File std-lib/tools/check-inventory.ps1`:
  175 reference names, 73 historical hooks and 52 inventory links.
- `rtk proxy powershell -NoProfile -File bootstrap/out/check-v2-handoff.ps1`:
  current gate/tool/input hashes, LLVM fixed point, helper acceptance, six
  changed/new PowerShell parses, both stages' Integer-array i16 loads/stores
  and 2-byte element-size IR, local document links, JSON and whitespace.
- The refactored `std-lib/tools/check-foundation.ps1` comparison runner also
  completed through the shared process helper. Its old backup/seed limitations
  remain explicitly separate from the repaired v2 gate.

The historical full archived-compiler build was not run. Archives were preserved;
these repairs do not transfer verification to an old v3/v4 or a fresh UBECore API.
