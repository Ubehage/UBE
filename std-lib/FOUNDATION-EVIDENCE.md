# Foundation contract and bounded bootstrap evidence

Initial investigation recorded 2026-10-30, before the subsequent v2 repairs.
The hashes and failures below describe that earlier working-tree snapshot.
For the current usable tool, see
[source-built v2 verification](../compiler/UBE_Compiler_v2/FOUNDATION-VERIFICATION.md).
This is evidence for the
[foundation contract](FOUNDATION.md), not a new compiler/library release.
No archived implementation, current bootstrap production source or library
manifest was changed by this investigation.

## Procedure and assertions

Command from the repository root:

```powershell
rtk proxy powershell -NoProfile -File std-lib/tools/check-foundation.ps1
```

The maintained runner builds the six current stage-zero C++ source files and
the current C/Unicode runtime separately, with warnings treated as errors. It
does not run `bootstrap/build.ps1` or rebuild an archived compiler. It tests
the rebuilt seed and, when available, both restored v2 binaries. Each process
has a timeout; outputs go to a new child of `bootstrap/out/foundation/`.

For each positive case it asserts LLVM emission, repeat byte identity, native
link success, exact native stdout/exit and empty stderr. Storage probes also
assert the expected LLVM allocation width. Negative cases assert controlled
nonzero exit, diagnostic text and no LLVM artifact; the unknown-intrinsic case
also checks the diagnostic identifies an unsupported intrinsic. These are
small independent oracles, not comparisons to an old compiler's expected output.

The recorded run completed 33 case/tool checks: all 18 narrow-subset checks
passed; six target probes passed and nine failed. The runner exits successfully
because its gate is the current-source seed's bounded subset. The probe
failures remain unmet obligations, not waived implementation acceptance tests.

Detailed generated report:
`bootstrap/out/foundation/fe87944edc3b4060b294b8d4a32a25a3/report.json`.
SHA-256: `3F81D860CECB418F8C374B1A5FDDC799B77D34C220331988ECAAF2F1A1DA29F6`.
It includes every command, process output, elapsed time, source/header/fixture/
runner identity, executable/object identity and provenance comparison. Generated
reports are ignored by Git; the checked-in cases and runner reproduce the seed
procedure without needing restored executables. Their absence is an explicit
skip, not a substituted tool or a v2 pass.

## Results

| Independently specified check | Current-source seed | Restored v2 stage 1 | Restored v2 stage 2 |
|---|---|---|---|
| Long control flow, ByVal isolation, ByRef mutation and function result | Pass: `41,7,9` | Pass | Pass |
| Neutral record fields and record ByRef mutation | Pass: `0,0,12,34` | Pass | Pass |
| Long array initialization and Preserve growth | Pass: `0,17,29,0` | Pass | Pass |
| Unknown type, non-addressable ByRef and truncated procedure rejection | All three pass | All three pass | All three pass |
| Integer local has i16 storage | Pass | Fail: i32 local | Fail: i32 local |
| Byte local has i8 storage | Fail: unsupported type | Fail: unknown local type | Fail: unknown local type |
| Scalar-only record assignment and ByVal copy isolation | Fail: ByVal record lowering unsupported | Pass: `7,9` | Pass: `7,9` |
| Bootstrap String operations can construct embedded zero | Fail: runtime exit 65 | Fail: runtime exit 65 | Fail: runtime exit 65 |
| Unknown intrinsic rejected before linking | Pass | Pass | Pass |

Comma-separated values in this table stand for separate output lines; the
actual oracle checks exact newline-terminated text. Seventeen successful LLVM
emissions were repeated with identical bytes. The two restored stages emitted
identical LLVM for all six cases where both emitted output, including cases
with incorrect/unsuitable target behavior. Agreement alone is not correctness.

The zero probe receives `UBE runtime: byte value is outside 1..255: 0` and no
stdout. The private bootstrap `StringFromByte` contract excludes zero; this
demonstrates an unsuitable operation for general byte storage, not a violation
of that intrinsic's own declared input domain. No new String API was specified
by the probe. Runtime exit 65 also does not establish the finished language's
recoverable neutral-result/Err behavior.

## Exact tools and provenance limits

Host: Windows x86-64, PowerShell `5.1.26100.9711`. Target:
`x86_64-w64-windows-gnu`, native linking with Clang `-O2`.
GCC/G++: MinGW-W64 x86_64-ucrt-posix-seh 16.2.0, WinLibs r2.
Clang: 23.1.3, LLVM revision `0d261d1ca552c95a8f007e061c787ac7132fbcbc`.
The report records absolute tool paths, version output and SHA-256 values.

| Tested artifact/input | SHA-256 |
|---|---|
| Rebuilt current seed | `B9729F6D7515C854B6B002EE0889BF8E566A84B5847A32DA758DC32ED37CDCC6` |
| Rebuilt C runtime object | `92F4C555279A370E5025ED4833EE3ED3AB99695B8AD8D4A07C587ACD18E21355` |
| Rebuilt Unicode runtime object | `AB41E49C6E1375AC878F588FF88DC7DB43A7018CAD8F3F811DE811F7C245EDFD` |
| Restored v2 stage 1 | `4CB321695E2948D2E79D27E1690CE650D02506D41AF2C614D5A7CD4F8627A165` |
| Restored v2 stage 2 | `A917D67B0F6AA206579EAB689632C99CAA385548D0BCBEB19B1682F1C9536837` |
| Current v2 Main.bas | `7E440A6941F89F99841D83EF858FD9AFE982809E196FBC4EF59573149841643D` |
| Current C runtime source | `8575B9E8293B0A5C191C12ABE5E5D3D0B104ECD128C8C990D71622104F0A2802` |
| Case expectations | `9ADF6897D0611160D786B0F5A0999D17A428BA712C96D26BD8416C493E6D01E5` |

Both restored v2 executables match the copied `v2-bootstrap-manifest.json`.
Current v2 source and C runtime source differ from its recorded input hashes;
the project manifest and Unicode runtime source match. Native fixtures were
linked with the rebuilt current runtime objects, while the restored compiler
executables retain whatever runtime was linked into them. No source-to-binary
reproduction or v2 fixed point was performed. Executable timestamps can change
seed hashes between builds; no deterministic seed-binary claim is made.

The navigation/dependency documents refer to `project-docs/toolchain.md` and
`project-docs/toolchain.lock.json`, but neither file exists in this local tree.
Installed-tool identities are evidence for this run, not proof of a missing
toolchain lock or cross-platform qualification. No dependency was downloaded.

## Bounded selection and next action

Select the source-built stage-zero seed only for the demonstrated diagnostic
subset: small single-source programs using Long, basic calls/control flow,
field-only Long records through ByRef, and zero-based one-dimensional Long
arrays. This is not selection of a ready production-library compiler.
Treat the restored v2 executables as comparison artifacts. Do not depend on
their Integer lowering or infer that today's v2 source reproduces them.

Neither route currently proves the proposed native datatype mechanism or the
required byte/text foundation. First review the finite Octet mechanism proposal
in `FOUNDATION.md`, including representation binding/access and fresh internal
failure status. Then write the approved syntax/ABI contract and its smallest
positive/rejection fixtures. Make only the seed changes required to compile
that proof, preserving these focused regressions. Byte lowering is already
isolated by a single-local-declaration fixture; no old compiler restoration
is justified by this evidence.

Still unverified: general native-type extensions, managed deep copies and GC,
recoverable failures/Err, allocation failure, arbitrary array bounds/rank,
multi-module/library compilation, threading/cancellation, actual allocation/
copy/memory cost and the fresh UBECore project itself. Process timings are
diagnostic elapsed times, not scaling or resource-cost measurements.

Supporting handoff checks also passed:

- `rtk proxy powershell -NoProfile -File compiler/archived/verify.ps1`:
  367 original/archived files, 13 relocation-only edits, nine preview hashes,
  28 prior library files, six manifests/132 inputs and 21 scripts.
- `rtk proxy powershell -NoProfile -File std-lib/tools/check-inventory.ps1`:
  175 reference names, 73 historical hooks and 52 inventory links.
- `rtk proxy powershell -NoProfile -File bootstrap/out/check-foundation-handoff.ps1`:
  30 local document links, changed/new file whitespace, PowerShell parsing,
  11 unique fixture paths, 33 result counts and exact report/input/tool hashes.
  This generated handoff assertion script checks the recorded run; the
  maintained bootstrap procedure remains `std-lib/tools/check-foundation.ps1`.
- `rtk proxy git -c core.safecrlf=false -c core.whitespace=blank-at-eol,blank-at-eof,space-before-tab,cr-at-eol diff --check`:
  no tracked-change whitespace errors. The handoff script covers new files too.
