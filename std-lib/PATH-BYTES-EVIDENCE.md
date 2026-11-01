# Counted-byte path evidence

The owner adopted [PATH-BYTES-PROPOSAL.md](PATH-BYTES-PROPOSAL.md) on 2026-10-31.
The ordinary normalization/resolution algorithms are implemented in UBE in
`src/portable/PathBytes.bas`; directory observation and open-token identity are
the two minimal host operations. Compiler manifest and containment policy remain
outside UBECore. No collector, executor, syntax or value semantics changed.

## Focused native and UBE runs

`rtk proxy powershell -NoProfile -File std-lib/tools/check-file-bytes.ps1 -NativeOnly`
passed the earlier native file oracles and new directory/identity, hard-link,
distinct-file, allocation/root-capacity and independent-worker assertions, in
both ordinary and Unicode working directories. Report:
`bootstrap/out/file-bytes/8ad617362b694e259fc25b24d415b146/report.json`, SHA-256
`6BD31AF3970EE69E2696F34D76679B20CE8630367DBD03C4FD3772DF6688E337`.
This predates the ordinary PathBytes body and is native-layer evidence only.

A focused development compiler was built from the changed v2 source through
both previously accepted stages, comparing their complete raw LLVM before
linking against the changed runtime. It is not an accepted replacement cohort.
Its exact commands/input/artifact identities are in
`bootstrap/out/path-development/b997f3064a8344dda5222ef906f583f4/report.json`.
It does not update `bootstrap/out/v2/current.json`.

```powershell
rtk proxy powershell -NoProfile -File std-lib/tools/check-path-bytes.ps1 -DevelopmentDirectory bootstrap/out/path-development/b997f3064a8344dda5222ef906f583f4
```

This passed three grouped checks in report
`bootstrap/out/path-bytes/60957512d30d41f58ad1fd565cad70cb/report.json`, SHA-256
`2A03D864672F8DC5EF4DDB318A7DAE5309F20D2184D11B0CC054277D84FC496E`:

- 44 independent relative/drive/UNC/Unicode/malformed/unsupported vectors; exact
  failure and Err, immutable inputs and preservation of earlier output. Runtime
  generated cases additionally check exact/one-over ASCII, BMP and supplementary
  UTF-16 limits, byte limits and final combined absolute-path limits.
- Real allocator/copy observation on six sizes (1..16385 bytes), both operations;
  every reached payload-allocation position denied, nonzero input lower bound,
  actual full 1048576-root pressure, unchanged old output and retry, zero remaining
  roots/payload, and four native callers using the same immutable input.
- A deliberately corrupted normalized output byte is rejected by the exact
  native comparison, with the expected failing assertion.

The C harness supplies assertions, input construction, native concurrency and
observations; all path processing runs in the actual UBE body. The only Err
getter adapter connects a test stub to the existing runtime getter; it adds no
production language binding. Raw LLVM is retained separately from adapters.
Component/decoder counters increment at executed calls. Allocator measurements
include requested headers/workspace and exclude OS allocator overhead; they are
stronger than the prescribed payload-only ceiling, but are not process RSS.

At 16385 input bytes, relative normalization observed six allocation calls,
57348 copied bytes, 99042 additional requested peak bytes, 8193 component calls
and 32770 decoder calls. Resolution observed ten allocation calls, 73793 copied
bytes, 132494 additional requested peak bytes, 8197 component calls and 32793
decoder calls. Every measured row passes the previously specified budgets.

## Current source-built qualification

The earlier focused tool is explicitly `developmentOnly`. Subsequently,
`rtk proxy powershell -NoProfile -File bootstrap/build-v2.ps1` passed **619 grouped
assertions**, retaining the earlier 592, adding twenty invalid-signature checks
and seven two-stage path checks. Its 136 core assertions and all earlier twenty
child proofs remain; path-bytes is the additional twenty-first child. The build
pins the new path contract, fixture files and harness before execution. An
earlier run was deliberately stopped before qualification to correct omitted
fixture inputs; only the complete restarted run is accepted.

Accepted manifest:
`bootstrap/out/v2/05f431ea44e54439b9a19cc16687890b/manifest.json`, SHA-256
`9DBF48B6615159B87B9C49A69DBEEE09C68C78F046892666E94B2DE0B0EB5D6E`.
`bootstrap/out/v2/current.json` now selects this cohort.

| Artifact | SHA-256 |
| --- | --- |
| stage-two compiler | `914CCAB7816AAF02C82F9B54884E7D3CE65F01697E25A0D6F4C22A2082939E33` |
| runtime object | `F666C46DD7909CC2B7E4435177E9424B256C62B05A10B784D7E541BEE2808C87` |
| Unicode object | `AB41E49C6E1375AC878F588FF88DC7DB43A7018CAD8F3F811DE811F7C245EDFD` |
| Clang | `F3425B2BFF01BC401C84AF6E5E180629182FAFC2EB35CF971A3E50C9CF13F263` |

Two-stage path report:
`bootstrap/out/path-bytes/de2c73dcdd9c48d890142ef3944f3706/report.json`, SHA-256
`D550BFF7EBBAB9E7036655D7B2ED613A4EF9F18B6B47230288D46CD0261B1166`.
Both stages pass every independent vector/limit, 1090428 native cost/failure/
lifetime assertions each and the corrupted-output negative control. Raw LLVM
is byte-identical. These are actual UBE bodies with test-only observation/ABI
adapters, not a C normalizer. The parent's file gate also executes directory and
identity calls through both rebuilt stages and retains all old file checks.

Retained gates run separately against this exact cohort:

| Command/procedure | Result | Report SHA-256 |
| --- | --- | --- |
| `rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tools/check-parser.ps1` | 4049 checks, qualifiedParser true; all 188 cases and 10412 root capacities | `9835761B706846543C94CA80C0EFB9860D0C69C5465E4AEBFD6950D73035DBCA` |
| `rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tools/check-parser-cli.ps1` | 217 checks; 82 exact process cases, diagnosticOnly false | `E5905761F67DD001241C128576E71F7BB4F01054EFA95614C335728D3899873F` |
| `rtk proxy powershell -NoProfile -File bootstrap/out/publish-local-cli.ps1` | Byte-identical qualified stage-two program; all 41 local process cases | `33208ED6093835CA35952ECBE1F7FCC61D75E85F9EA7F35D2E3F05E8BFD66621` |
| `rtk proxy powershell -NoProfile -File bootstrap/out/check-added-cli.ps1` | Six additional exact cases through both executables: SourceParsing, Threads, PathBytes | `B8FAE550B41E652F8524C6A583CB199E7EC896C1B74B198085DCDE0FD23C0B4A` |

Reports, respectively:
`bootstrap/out/parser/e8c4ffa23d554b3d8545b977239c27ed/report.json`,
`bootstrap/out/parser-cli/f619aaca8fec42e8a952c4e005b995cb/report.json`,
`bootstrap/out/local-cli/7eeb16aceb1649ecbeb7e2919717c613/report.json`,
`bootstrap/out/added-cli/659bfb7fdf2f477c9baa255d5b184787/report.json`.
The original strict CLI corpus freezes sixteen real MODULEs; the additional
three cover the full current nineteen-MODULE inventory without removing any old
case. The separate unrestricted compiler-concurrency command
`rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tools/check-concurrency.ps1`
also passed: qualified true, both stage groups, **3004 native assertions per
stage / 6008 total**, complete old checks plus the expanded real source corpus.
Report `bootstrap/out/source-set-proof/6d962088d6464c2a9600ebc1f684eb84/report.json`,
SHA-256 `1AA455EB6895D2F537C18A512FA71D4467189700F60F9A246F674F7E6701407B`.
This retains the correctness proof; its instrumented timing remains slower
with four workers and does not establish the parallel performance gate.

## Additional native host edges

```powershell
rtk proxy powershell -NoProfile -File bootstrap/out/check-host-path-edges.ps1 -CaseSensitiveDirectory C:/Users/Ubehage/vscodium/UBE/bootstrap/out/host-path-edges/sensitive-check-20261031
```

The exact runtime source is included unchanged in a test-only translation unit.
No production source/binding changes. All **37 assertions** pass: actual native
directory-buffer malloc failure and retry; internal UTF-16 transport at 32767
ASCII and BMP units (98301 UTF-8 bytes), one-over and lone-surrogate rejection;
real invalid-native-handle identity query failure, Busy release, unchanged older
output and successful retry; and distinct opened identities for actual files
`Name.bin`/`name.bin` in a confirmed case-sensitive directory, with exact reopen
identity. All roots/payload/tokens drain.

Report `bootstrap/out/host-path-edges/cfc887e70ef04ab49c5b63c290677629/report.json`,
SHA-256 `374700DC3B4A256E715660F81A9FE47A8380E4F7744A6F63532CE65F2B2E0235`.
Sources/harness/executable and native commands are captured there. A targeted
escalated `fsutil file setCaseSensitiveInfo` enabled only that isolated test
directory; a subsequent query confirms the flag. No global setting changed.

Earlier failed probe runs are retained: one direct helper call failed to seed
the status that its public caller initializes; another treated fsutil's zero
exit as successful capability admission even though its text reported access
denied and the flag remained disabled. The corrected probe checks the actual
queried attribute and exercises distinct real files. Neither failed fixture
justifies changing production code. Microsoft's [CreateFileW documentation](https://learn.microsoft.com/en-us/windows/win32/api/fileapi/nf-fileapi-createfilew)
describes host path/flag behavior; assertions above come from the native run.

## Remaining limits

Project discovery/publication and the parallel performance gate remain open.
Explicit successful collection during ordinary path processing, directory-query
failure/races and unsupported identity-host behavior still need their focused
checks. Direct wide-helper tests prove transport bounds, not that Windows can
create a directory/file with every permitted transport length.
